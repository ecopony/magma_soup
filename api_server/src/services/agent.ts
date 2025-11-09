// ABOUTME: Agent service implementing the agentic loop with tool use
// ABOUTME: Orchestrates Claude API calls, tool execution, and result streaming

import { AnthropicService } from "./anthropic.js";
import { McpClient } from "./mcp-client.js";
import { GisPromptBuilder } from "./gis-prompt-builder.js";
import { GeoFeatureExtractor } from "./geo-feature-extractor.js";
import { createMessage, getConversationHistory } from "../models/message.js";
import { createGeoFeature } from "../models/geo-feature.js";
import { updateConversationTimestamp } from "../models/conversation.js";
import type {
  AgenticLoopResult,
  LLMHistoryEntry,
  GeoFeature,
  StreamUpdate,
  ContentBlock,
  Message,
} from "../types/index.js";

export class AgentService {
  private anthropicService: AnthropicService;
  private mcpClient: McpClient;
  private geoFeatureExtractor: GeoFeatureExtractor;
  private maxToolCalls = 10;

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
    // Build prompt with GIS context
    const prompt = GisPromptBuilder.buildPrompt(userMessage);

    // Get MCP tools
    const tools = await this.mcpClient.getToolsForAnthropic();

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
          const result = await this.mcpClient.callTool(toolName, toolInput);

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

    return {
      finalResponse,
      llmHistory,
      geoFeatures,
    };
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

      // Store user message
      await createMessage(conversationId, "user", { text: userMessage });

      // Execute agentic loop with previous context
      const result = await this.executeAgenticLoop(
        userMessage,
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
