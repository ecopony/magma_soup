// ABOUTME: Agent service implementing the agentic loop with tool use
// ABOUTME: Orchestrates Claude API calls, tool execution, and result streaming

import { updateConversationTimestamp } from "../models/conversation.js";
import {
  createGeoFeature,
  getConversationGeoFeatures,
} from "../models/geo-feature.js";
import { createMessage, getConversationHistory } from "../models/message.js";
import type {
  AgenticLoopResult,
  ContentBlock,
  GeoFeature,
  LLMHistoryEntry,
  Message,
  StreamUpdate,
} from "../types/index.js";
import { AnthropicService } from "./anthropic.js";
import { GeoFeatureExtractor } from "./geo-feature-extractor.js";
import { GisPromptBuilder } from "./gis-prompt-builder.js";
import { McpClient } from "./mcp-client.js";
import {
  removeFeatureTool,
  handleRemoveFeature,
} from "../tools/remove-feature.js";

export class AgentService {
  private anthropicService: AnthropicService;
  private mcpClient: McpClient;
  private geoFeatureExtractor: GeoFeatureExtractor;
  private maxToolCalls = 10;
  private localTools = new Map<string, any>([
    [removeFeatureTool.name, { definition: removeFeatureTool, handler: handleRemoveFeature }],
  ]);

  constructor(anthropicApiKey: string, mcpServerUrl: string) {
    this.anthropicService = new AnthropicService(anthropicApiKey);
    this.mcpClient = new McpClient(mcpServerUrl);
    this.geoFeatureExtractor = new GeoFeatureExtractor();
  }

  async executeAgenticLoop(
    userMessage: string,
    onProgress?: (update: StreamUpdate) => void,
    previousConversationHistory?: Message[]
  ): Promise<AgenticLoopResult> {
    // userMessage may already be a full prompt (from executeAgenticLoopWithPersistence)
    // or just a plain user message. Use as-is since it's already formatted.
    const prompt = userMessage;

    // Get MCP tools and merge with local tools
    const mcpTools = await this.mcpClient.getToolsForAnthropic();
    const localToolDefinitions = Array.from(this.localTools.values()).map(
      (t) => t.definition
    );
    const tools = [...mcpTools, ...localToolDefinitions];

    // Build conversation history, including previous messages if provided
    const conversationHistory: Message[] = [
      ...(previousConversationHistory || []),
      { role: "user", content: prompt },
    ];

    // Call Anthropic with MCP tools and full conversation history
    let response = await this.anthropicService.sendMessage({
      tools,
      conversationHistory,
    });

    // Track token usage across all API calls
    let totalInputTokens = 0;
    let totalOutputTokens = 0;
    let apiCallCount = 1;

    // Extract usage from initial response
    const initialUsage = this.anthropicService.extractUsage(response);
    totalInputTokens += initialUsage.input_tokens;
    totalOutputTokens += initialUsage.output_tokens;

    // Track full LLM interaction for debugging/display
    const llmHistory: LLMHistoryEntry[] = [
      {
        type: "user_prompt",
        timestamp: new Date().toISOString(),
        content: prompt,
      },
      {
        type: "llm_response",
        timestamp: new Date().toISOString(),
        stop_reason: response.stop_reason,
        content: response.content,
      },
    ];

    // Stream user prompt and initial LLM response
    if (onProgress) {
      onProgress({
        type: "user_prompt",
        data: { prompt },
      });
      onProgress({
        type: "llm_response",
        data: { stop_reason: response.stop_reason, content: response.content },
      });
    }

    let toolCallCount = 0;
    const geoFeatures: GeoFeature[] = [];

    while (
      response.stop_reason === "tool_use" &&
      toolCallCount < this.maxToolCalls
    ) {
      toolCallCount++;

      conversationHistory.push({
        role: "assistant",
        content: response.content,
      });

      // Execute all tool uses
      const toolUses = this.anthropicService.extractToolUses(response);
      const toolResults: ContentBlock[] = [];

      for (const toolUse of toolUses) {
        const toolName = toolUse.name;
        const toolInput = toolUse.input;
        const toolUseId = toolUse.id;

        // Stream tool call event
        if (onProgress) {
          onProgress({
            type: "tool_call",
            data: {
              tool_use_id: toolUseId,
              tool_name: toolName,
              arguments: toolInput,
            },
          });
        }

        try {
          let result: string;

          // Check if this is a local tool
          if (this.localTools.has(toolName)) {
            const localTool = this.localTools.get(toolName);
            result = await localTool.handler(toolInput);
          } else {
            // Call MCP tool
            result = await this.mcpClient.callTool(toolName, toolInput);
          }

          toolResults.push({
            type: "tool_result",
            tool_use_id: toolUseId,
            content: result,
          });

          // Track tool call and result in history
          llmHistory.push({
            type: "tool_call",
            timestamp: new Date().toISOString(),
            tool_use_id: toolUseId,
            tool_name: toolName,
            arguments: toolInput,
          });
          llmHistory.push({
            type: "tool_result",
            timestamp: new Date().toISOString(),
            tool_use_id: toolUseId,
            tool_name: toolName,
            result,
          });

          // Stream tool result event
          if (onProgress) {
            onProgress({
              type: "tool_result",
              data: { tool_use_id: toolUseId, tool_name: toolName, result },
            });
          }

          // Check if this was a successful removal
          if (toolName === "remove_map_feature") {
            try {
              const parsed = JSON.parse(result);
              if (parsed.success && parsed.removed_feature_id) {
                if (onProgress) {
                  onProgress({
                    type: "remove_geo_feature",
                    data: { feature_id: parsed.removed_feature_id },
                  });
                }
              }
            } catch (e) {
              // Malformed JSON response, ignore
            }
          }

          // Extract geographic features from tool results
          const features = this.geoFeatureExtractor.extractFeatures(
            toolName,
            result,
            toolInput
          );
          geoFeatures.push(...features);

          // Stream geo features
          if (onProgress && features.length > 0) {
            for (const feature of features) {
              onProgress({
                type: "geo_feature",
                data: feature,
              });
            }
          }
        } catch (e) {
          const errorMessage = e instanceof Error ? e.message : String(e);

          toolResults.push({
            type: "tool_result",
            tool_use_id: toolUseId,
            content: `Error: ${errorMessage}`,
            is_error: true,
          });

          // Track tool error in history
          llmHistory.push({
            type: "tool_call",
            timestamp: new Date().toISOString(),
            tool_use_id: toolUseId,
            tool_name: toolName,
            arguments: toolInput,
          });
          llmHistory.push({
            type: "tool_error",
            timestamp: new Date().toISOString(),
            tool_use_id: toolUseId,
            tool_name: toolName,
            error: errorMessage,
          });

          // Stream tool error event
          if (onProgress) {
            onProgress({
              type: "tool_error",
              data: {
                tool_use_id: toolUseId,
                tool_name: toolName,
                error: errorMessage,
              },
            });
          }
        }
      }

      conversationHistory.push({
        role: "user",
        content: toolResults,
      });

      // Continue conversation with tool results
      response = await this.anthropicService.sendMessage({
        tools,
        conversationHistory,
      });

      // Track token usage from this API call
      apiCallCount++;
      const usage = this.anthropicService.extractUsage(response);
      totalInputTokens += usage.input_tokens;
      totalOutputTokens += usage.output_tokens;

      // Track subsequent LLM response
      llmHistory.push({
        type: "llm_response",
        timestamp: new Date().toISOString(),
        stop_reason: response.stop_reason,
        content: response.content,
      });

      // Stream subsequent LLM response
      if (onProgress) {
        onProgress({
          type: "llm_response",
          data: {
            stop_reason: response.stop_reason,
            content: response.content,
          },
        });
      }
    }

    // Check if we hit the tool call limit
    if (toolCallCount >= this.maxToolCalls) {
      throw new Error(
        `Maximum tool call limit (${this.maxToolCalls}) reached. Please try rephrasing your request.`
      );
    }

    // Extract final text response
    const finalResponse = this.anthropicService.extractTextResponse(response);

    // Log token usage summary
    const totalTokens = totalInputTokens + totalOutputTokens;
    const estimatedCost = this.calculateCost(totalInputTokens, totalOutputTokens);

    console.log('\n=== Token Usage Summary ===');
    console.log(`API calls: ${apiCallCount}`);
    console.log(`Input tokens: ${totalInputTokens.toLocaleString()}`);
    console.log(`Output tokens: ${totalOutputTokens.toLocaleString()}`);
    console.log(`Total tokens: ${totalTokens.toLocaleString()}`);
    console.log(`Estimated cost: $${estimatedCost.toFixed(4)}`);
    console.log('===========================\n');

    return {
      finalResponse,
      llmHistory,
      geoFeatures,
      tokenUsage: {
        apiCalls: apiCallCount,
        inputTokens: totalInputTokens,
        outputTokens: totalOutputTokens,
        totalTokens,
        estimatedCost,
      },
    };
  }

  private calculateCost(inputTokens: number, outputTokens: number): number {
    // Claude Sonnet 4.5 pricing (as of the model we're using)
    // $3 per million input tokens, $15 per million output tokens
    const inputCost = (inputTokens / 1_000_000) * 3;
    const outputCost = (outputTokens / 1_000_000) * 15;
    return inputCost + outputCost;
  }

  async executeAgenticLoopWithPersistence(
    conversationId: string,
    userMessage: string,
    onProgress?: (update: StreamUpdate) => void
  ): Promise<AgenticLoopResult> {
    try {
      // Load previous conversation history (user/assistant messages only)
      const previousMessages = await getConversationHistory(conversationId);
      const previousConversationHistory: Message[] = previousMessages.map(
        (msg) => {
          if (!msg.content?.text) {
            throw new Error(
              `Message ${msg.id} has invalid content structure - expected { text: string }`
            );
          }
          return {
            role: msg.type as "user" | "assistant",
            content: msg.content.text,
          };
        }
      );

      // Load existing features for context
      const existingFeatures = await getConversationGeoFeatures(conversationId);

      // Store user message
      await createMessage(conversationId, "user", { text: userMessage });

      // Build prompt with map context
      const prompt = GisPromptBuilder.buildPromptWithMapContext(
        conversationId,
        userMessage,
        existingFeatures
      );

      // Execute agentic loop with previous context
      const result = await this.executeAgenticLoop(
        prompt,
        onProgress,
        previousConversationHistory
      );

      // Store all LLM history entries as messages
      for (const entry of result.llmHistory) {
        const messageType = entry.type;
        let content: Record<string, unknown>;

        switch (entry.type) {
          case "user_prompt":
            content = { prompt: entry.content };
            break;
          case "llm_response":
            content = {
              content: entry.content,
              stop_reason: entry.stop_reason,
            };
            break;
          case "tool_call":
            content = {
              tool_use_id: entry.tool_use_id,
              tool_name: entry.tool_name,
              arguments: entry.arguments,
            };
            break;
          case "tool_result":
            content = {
              tool_use_id: entry.tool_use_id,
              tool_name: entry.tool_name,
              result: entry.result,
            };
            break;
          case "tool_error":
            content = {
              tool_use_id: entry.tool_use_id,
              tool_name: entry.tool_name,
              error: entry.error,
            };
            break;
          default:
            throw new Error(
              `Unknown LLM history entry type: ${(entry as any).type}`
            );
        }

        await createMessage(conversationId, messageType, content);
      }

      // Store assistant response
      const assistantMessageRecord = await createMessage(
        conversationId,
        "assistant",
        { text: result.finalResponse }
      );

      // Store geographic features
      for (const feature of result.geoFeatures) {
        await createGeoFeature(assistantMessageRecord.id, feature);
      }

      // Update conversation timestamp
      await updateConversationTimestamp(conversationId);

      return result;
    } catch (error) {
      console.error("Error in executeAgenticLoopWithPersistence:", error);
      throw error;
    }
  }
}
