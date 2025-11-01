// ABOUTME: Agent service implementing the agentic loop with tool use
// ABOUTME: Orchestrates Claude API calls, tool execution, and result streaming

import { AnthropicService } from './anthropic.js';
import { McpClient } from './mcp-client.js';
import { GisPromptBuilder } from './gis-prompt-builder.js';
import { GeoFeatureExtractor } from './geo-feature-extractor.js';
import type {
  AgenticLoopResult,
  LLMHistoryEntry,
  GeoFeature,
  StreamUpdate,
  ContentBlock,
  Message,
} from '../types/index.js';

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
    onProgress?: (update: StreamUpdate) => void
  ): Promise<AgenticLoopResult> {
    // Build prompt with GIS context
    const prompt = GisPromptBuilder.buildPrompt(userMessage);

    // Get MCP tools
    const tools = await this.mcpClient.getToolsForAnthropic();

    // Call Anthropic with MCP tools
    let response = await this.anthropicService.sendMessage({
      prompt,
      tools,
    });

    // Handle tool use loop with safety limit
    const conversationHistory: Message[] = [
      { role: 'user', content: prompt },
    ];

    // Track full LLM interaction for debugging/display
    const llmHistory: LLMHistoryEntry[] = [
      {
        type: 'user_prompt',
        timestamp: new Date().toISOString(),
        content: prompt,
      },
      {
        type: 'llm_response',
        timestamp: new Date().toISOString(),
        stop_reason: response.stop_reason,
        content: response.content,
      },
    ];

    // Stream initial LLM response
    if (onProgress) {
      onProgress({
        type: 'llm_response',
        data: { stop_reason: response.stop_reason, content: response.content },
      });
    }

    let toolCallCount = 0;
    const geoFeatures: GeoFeature[] = [];

    while (response.stop_reason === 'tool_use' && toolCallCount < this.maxToolCalls) {
      toolCallCount++;

      conversationHistory.push({
        role: 'assistant',
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
            type: 'tool_call',
            data: { tool_name: toolName, arguments: toolInput },
          });
        }

        try {
          const result = await this.mcpClient.callTool(toolName, toolInput);

          toolResults.push({
            type: 'tool_result',
            tool_use_id: toolUseId,
            content: result,
          });

          // Track tool call and result in history
          llmHistory.push({
            type: 'tool_call',
            timestamp: new Date().toISOString(),
            tool_name: toolName,
            arguments: toolInput,
          });
          llmHistory.push({
            type: 'tool_result',
            timestamp: new Date().toISOString(),
            tool_name: toolName,
            result,
          });

          // Stream tool result event
          if (onProgress) {
            onProgress({
              type: 'tool_result',
              data: { tool_name: toolName, result },
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
                type: 'geo_feature',
                data: feature,
              });
            }
          }
        } catch (e) {
          const errorMessage = e instanceof Error ? e.message : String(e);

          toolResults.push({
            type: 'tool_result',
            tool_use_id: toolUseId,
            content: `Error: ${errorMessage}`,
            is_error: true,
          });

          // Track tool error in history
          llmHistory.push({
            type: 'tool_call',
            timestamp: new Date().toISOString(),
            tool_name: toolName,
            arguments: toolInput,
          });
          llmHistory.push({
            type: 'tool_error',
            timestamp: new Date().toISOString(),
            tool_name: toolName,
            error: errorMessage,
          });

          // Stream tool error event
          if (onProgress) {
            onProgress({
              type: 'tool_error',
              data: { tool_name: toolName, error: errorMessage },
            });
          }
        }
      }

      conversationHistory.push({
        role: 'user',
        content: toolResults,
      });

      // Continue conversation with tool results
      response = await this.anthropicService.sendMessage({
        tools,
        conversationHistory,
      });

      // Track subsequent LLM response
      llmHistory.push({
        type: 'llm_response',
        timestamp: new Date().toISOString(),
        stop_reason: response.stop_reason,
        content: response.content,
      });

      // Stream subsequent LLM response
      if (onProgress) {
        onProgress({
          type: 'llm_response',
          data: { stop_reason: response.stop_reason, content: response.content },
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
}
