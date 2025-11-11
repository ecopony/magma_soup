// ABOUTME: Agent SDK server entry point
// ABOUTME: Express server using Anthropic's Agent SDK for comparison with custom implementation

import { query } from "@anthropic-ai/claude-agent-sdk";
import cors from "cors";
import "dotenv/config";
import express from "express";
import {
  createConversation,
  getConversation,
  listConversations,
  updateConversationSessionId,
  updateConversationTimestamp,
} from "./models/conversation.js";
import {
  createGeoFeature,
  getConversationGeoFeatures,
  getMessageGeoFeatures,
} from "./models/geo-feature.js";
import {
  createMessage,
  getConversationMessages,
  type MessageType,
} from "./models/message.js";
import { GeoFeatureExtractor } from "./services/geo-feature-extractor.js";
import { GisPromptBuilder } from "./services/gis-prompt-builder.js";
import { gisTools } from "./services/gis-tools.js";
import { SSEStream } from "./utils/sse.js";

// Enable verbose logging for debugging
// process.env.DEBUG = "anthropic:*";

const app = express();
app.use(cors());
app.use(express.json());

// POST /conversations - Create new conversation (Phase 3.5)
app.post("/conversations", async (req, res) => {
  try {
    const { title } = req.body;
    const conversation = await createConversation(undefined, title);
    res.json(conversation);
  } catch (error: any) {
    console.error("Error creating conversation:", error);
    res.status(500).json({ error: "Failed to create conversation" });
  }
});

// GET /conversations - List recent conversations (Phase 3.5)
app.get("/conversations", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;
    const conversations = await listConversations(limit, offset);
    res.json(conversations);
  } catch (error: any) {
    console.error("Error listing conversations:", error);
    res.status(500).json({ error: "Failed to list conversations" });
  }
});

// GET /conversations/:id - Get conversation with full history (Phase 3.5)
app.get("/conversations/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const conversation = await getConversation(id);

    if (!conversation) {
      res.status(404).json({ error: "Conversation not found" });
      return;
    }

    const messages = await getConversationMessages(id);

    const messagesWithDetails = await Promise.all(
      messages.map(async (msg) => ({
        id: msg.id,
        role:
          msg.type === "user" || msg.type === "assistant" ? msg.type : "system",
        content: msg.content,
        created_at: msg.timestamp,
        sequence_number: msg.sequence_number,
        geo_features:
          msg.type === "assistant" ? await getMessageGeoFeatures(msg.id) : [],
      }))
    );

    res.json({
      ...conversation,
      messages: messagesWithDetails,
    });
  } catch (error: any) {
    console.error("Error getting conversation:", error);
    res.status(500).json({ error: "Failed to get conversation" });
  }
});

// POST /conversations/:id/messages - Conversation endpoint with persistence (Phase 3)
app.post("/conversations/:id/messages", async (req, res) => {
  const stream = new SSEStream(res);

  try {
    const conversationId = req.params.id;
    const { message } = req.body;

    if (!message || typeof message !== "string") {
      stream.send("error", {
        error: "Message is required and must be a string",
      });
      stream.end();
      return;
    }

    console.log("\n=== New Conversation Query ===");
    console.log("Conversation ID:", conversationId);
    console.log("User message:", message);

    // Check if conversation exists, create if not
    let conversation = await getConversation(conversationId);
    if (!conversation) {
      console.log("Creating new conversation with id:", conversationId);
      conversation = await createConversation(conversationId);
    }

    // Load existing geo features for map context
    const existingGeoFeatures = await getConversationGeoFeatures(
      conversationId
    );
    console.log(`Loaded ${existingGeoFeatures.length} existing geo features`);

    // Build GIS-aware system prompt with map context
    const systemPrompt = GisPromptBuilder.buildPromptWithMapContext(
      conversationId,
      message,
      existingGeoFeatures
    );

    console.log("System prompt:");
    console.log(systemPrompt);

    // Store user message
    await createMessage(conversationId, "user", { text: message });

    // Send user prompt event
    stream.send("user_prompt", { prompt: message });

    console.log("Starting Agent SDK query...");

    // Build query options
    const queryOptions: any = {
      model: "claude-sonnet-4-5",
      mcpServers: {
        "gis-tools": gisTools,
      },
      permissionMode: "bypassPermissions",
      systemPrompt: systemPrompt, // GIS context only - session handles conversation history
      disallowedTools: [
        "Task", "Bash", "Glob", "Grep", "ExitPlanMode", "Read", "Edit", "Write",
        "NotebookEdit", "WebFetch", "TodoWrite", "WebSearch", "BashOutput",
        "KillShell", "Skill", "SlashCommand"
      ],
    };

    // Use session resumption if session ID exists
    if (conversation.session_id) {
      console.log("Resuming existing session:", conversation.session_id);
      queryOptions.resume = conversation.session_id;
    } else {
      console.log("Starting new session");
    }

    // Execute query
    const response = query({
      prompt: message,
      options: queryOptions,
    });

    console.log("Query initiated, starting to process messages...");

    let finalResponse = "";
    const geoFeatures: any[] = [];
    const llmHistory: Array<{
      type: MessageType;
      timestamp: string;
      content: any;
    }> = [];
    const featureExtractor = new GeoFeatureExtractor();
    const toolUseIdToName = new Map<string, string>();
    const toolUseIdToArgs = new Map<string, Record<string, any>>();
    let capturedSessionId: string | null = null;

    // Track token usage
    let totalInputTokens = 0;
    let totalOutputTokens = 0;
    let apiCallCount = 0;
    let totalCostUsd = 0;

    // Track user prompt
    llmHistory.push({
      type: "user_prompt",
      timestamp: new Date().toISOString(),
      content: { prompt: message },
    });

    for await (const sdkMessage of response) {
      console.log("\n=== SDK Message ===");
      console.log("Type:", sdkMessage.type);
      console.log("Full message:", JSON.stringify(sdkMessage, null, 2));

      switch (sdkMessage.type) {
        case "system":
          if (sdkMessage.subtype === "init" && (sdkMessage as any).session_id) {
            capturedSessionId = (sdkMessage as any).session_id;
            console.log("Session initialized:", capturedSessionId);
          }
          break;

        case "assistant": {
          const apiMessage = (sdkMessage as any).message;

          // Track token usage from this API call
          apiCallCount++;
          if (apiMessage.usage) {
            // Count all input token types (regular, cache creation, cache read)
            const inputTokens = (apiMessage.usage.input_tokens || 0);
            const cacheCreationTokens = (apiMessage.usage.cache_creation_input_tokens || 0);
            const cacheReadTokens = (apiMessage.usage.cache_read_input_tokens || 0);

            totalInputTokens += inputTokens + cacheCreationTokens + cacheReadTokens;
            totalOutputTokens += apiMessage.usage.output_tokens || 0;

            console.log(`[Token Debug] Input: ${inputTokens}, Cache Creation: ${cacheCreationTokens}, Cache Read: ${cacheReadTokens}, Output: ${apiMessage.usage.output_tokens}`);
          }

          // Track LLM response
          llmHistory.push({
            type: "llm_response",
            timestamp: new Date().toISOString(),
            content: {
              content: apiMessage.content,
              stop_reason: apiMessage.stop_reason,
            },
          });

          // Send LLM response event
          stream.send("llm_response", {
            stop_reason: apiMessage.stop_reason,
            content: apiMessage.content,
          });

          // Parse content blocks
          for (const block of apiMessage.content) {
            if (block.type === "tool_use") {
              // Track tool name and args for later use
              toolUseIdToName.set(block.id, block.name);
              toolUseIdToArgs.set(block.id, block.input);

              // Track and stream tool call
              llmHistory.push({
                type: "tool_call",
                timestamp: new Date().toISOString(),
                content: {
                  tool_use_id: block.id,
                  tool_name: block.name,
                  arguments: block.input,
                },
              });

              stream.send("tool_call", {
                tool_use_id: block.id,
                tool_name: block.name,
                arguments: block.input,
              });
            } else if (block.type === "text") {
              finalResponse += block.text;
            }
          }
          break;
        }

        case "result":
          // Capture total cost from SDK
          if ((sdkMessage as any).total_cost_usd !== undefined) {
            totalCostUsd = (sdkMessage as any).total_cost_usd;
          }

          console.log("Query completed:", {
            duration_ms: (sdkMessage as any).duration_ms,
            num_turns: (sdkMessage as any).num_turns,
            total_cost_usd: totalCostUsd,
          });
          if ((sdkMessage as any).result) {
            finalResponse = (sdkMessage as any).result;
          }
          break;

        case "user": {
          const userMessage = (sdkMessage as any).message;

          if (userMessage.content && Array.isArray(userMessage.content)) {
            for (const block of userMessage.content) {
              if (block.type === "tool_result") {
                let resultText = "";
                if (typeof block.content === "string") {
                  resultText = block.content;
                } else if (Array.isArray(block.content)) {
                  resultText = block.content
                    .filter((c: any) => c.type === "text")
                    .map((c: any) => c.text)
                    .join("");
                }

                // Get tool name from tracking map
                const toolName =
                  toolUseIdToName.get(block.tool_use_id) || "unknown";
                const toolArgs = toolUseIdToArgs.get(block.tool_use_id) || {};

                // Track tool result
                if (block.is_error) {
                  llmHistory.push({
                    type: "tool_error",
                    timestamp: new Date().toISOString(),
                    content: {
                      tool_use_id: block.tool_use_id,
                      tool_name: toolName,
                      error: resultText,
                    },
                  });
                } else {
                  llmHistory.push({
                    type: "tool_result",
                    timestamp: new Date().toISOString(),
                    content: {
                      tool_use_id: block.tool_use_id,
                      tool_name: toolName,
                      result: resultText,
                    },
                  });
                }

                // Stream tool result
                stream.send("tool_result", {
                  tool_use_id: block.tool_use_id,
                  tool_name: toolName,
                  result: resultText,
                });

                if (block.is_error) {
                  stream.send("tool_error", {
                    tool_use_id: block.tool_use_id,
                    tool_name: toolName,
                    error: resultText,
                  });
                }

                // Extract geo features from successful tool results
                if (!block.is_error) {
                  console.log(
                    `Attempting to extract features from tool: ${toolName}`
                  );
                  console.log(`Tool result: ${resultText}`);
                  console.log(`Tool args:`, toolArgs);

                  const extractedFeatures = featureExtractor.extractFeatures(
                    toolName,
                    resultText,
                    toolArgs
                  );

                  console.log(`Extracted ${extractedFeatures.length} features`);
                  if (extractedFeatures.length > 0) {
                    console.log(`Features:`, extractedFeatures);
                    geoFeatures.push(...extractedFeatures);

                    // Stream geo_feature events for each extracted feature
                    for (const feature of extractedFeatures) {
                      console.log(`Streaming geo_feature event:`, feature);
                      stream.send("geo_feature", feature);
                    }
                  }
                }

                // Check if this was a successful removal
                const baseName = toolName.replace(/^mcp__[^_]+__/, "");
                if (baseName === "remove_map_feature") {
                  try {
                    const parsed = JSON.parse(resultText);
                    if (parsed.success && parsed.removed_feature_id) {
                      stream.send("remove_geo_feature", {
                        feature_id: parsed.removed_feature_id,
                      });
                    }
                  } catch (e) {
                    // Not valid JSON or missing fields, ignore
                  }
                }
              }
            }
          }
          break;
        }

        case "stream_event": {
          const event = (sdkMessage as any).event;
          if (
            event.type === "content_block_delta" &&
            event.delta?.type === "text_delta"
          ) {
            // Streaming text - collected in finalResponse
          }
          break;
        }

        default:
          console.log("Unhandled message type:", sdkMessage.type);
      }
    }

    // Store all LLM history entries as messages
    for (const entry of llmHistory) {
      await createMessage(conversationId, entry.type, entry.content);
    }

    // Store assistant response
    const assistantMessageRecord = await createMessage(
      conversationId,
      "assistant",
      { text: finalResponse }
    );

    // Store geographic features
    for (const feature of geoFeatures) {
      await createGeoFeature(assistantMessageRecord.id, feature);
    }

    // Store session ID if this is a new session
    if (capturedSessionId && !conversation.session_id) {
      await updateConversationSessionId(conversationId, capturedSessionId);
      console.log("Stored session ID:", capturedSessionId);
    }

    // Update conversation timestamp
    await updateConversationTimestamp(conversationId);

    console.log("\n=== Conversation Query Complete ===");
    console.log("Stored", llmHistory.length, "LLM history entries");

    // Log token usage summary (matching format from original API server)
    const totalTokens = totalInputTokens + totalOutputTokens;

    console.log('\n=== Token Usage Summary ===');
    console.log(`API calls: ${apiCallCount}`);
    console.log(`Input tokens: ${totalInputTokens.toLocaleString()}`);
    console.log(`Output tokens: ${totalOutputTokens.toLocaleString()}`);
    console.log(`Total tokens: ${totalTokens.toLocaleString()}`);
    console.log(`Estimated cost: $${totalCostUsd.toFixed(4)}`);
    console.log('===========================\n');

    // Send final done event
    stream.send("done", {
      final_response: finalResponse,
      geo_features: geoFeatures,
    });

    stream.end();
  } catch (error: any) {
    console.error("Fatal error:", error);
    stream.send("error", {
      error: error.message || String(error),
    });
    stream.end();
  }
});

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", server: "agent-sdk-server" });
});

const PORT = process.env.AGENT_SDK_SERVER_PORT || 3002;

app.listen(PORT, () => {
  console.log(`Agent SDK Server running on http://localhost:${PORT}`);
  console.log(`\nEndpoints:`);
  console.log(
    `  Create conversation: POST http://localhost:${PORT}/conversations`
  );
  console.log(
    `  List conversations: GET http://localhost:${PORT}/conversations`
  );
  console.log(
    `  Get conversation: GET http://localhost:${PORT}/conversations/:id`
  );
  console.log(
    `  Send message: POST http://localhost:${PORT}/conversations/:id/messages`
  );
  console.log(`  Query (test): POST http://localhost:${PORT}/query`);
  console.log(`  Stream (test): POST http://localhost:${PORT}/query/stream`);
  console.log(`  Health: GET http://localhost:${PORT}/health\n`);
});
