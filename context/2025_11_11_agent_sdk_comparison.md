# Agent SDK Implementation Plan

**Date:** 2025-11-11
**Purpose:** Exploration and teaching - compare custom agentic loop vs Anthropic's Agent SDK

## Overview

Create a parallel implementation of the Magma Soup API server using Anthropic's Claude Agent SDK (`@anthropic-ai/claude-agent-sdk`) to compare approaches for building agentic systems. The goal is educational: understand tradeoffs between building custom vs using a framework.

## Current State Analysis

### Custom Implementation (api_server/)

- **Total size:** 405 lines in agent.ts
- **Core features:**
  - Agentic loop with tool execution (115 lines, agent.ts:100-277)
  - MCP tool integration via custom client
  - Local tool registry (Map-based, agent.ts:32-34)
  - SSE streaming to Flutter client
  - PostgreSQL persistence (conversations, messages, geo_features)
  - GIS-specific features:
    - GeoFeatureExtractor: extracts features from tool results
    - GisPromptBuilder: builds prompts with map context
    - Remove feature tool with SSE events
  - Conversation history management
  - Error handling and max iteration protection

### Dependencies

- `@anthropic-ai/sdk`: ^0.68.0 (base SDK)
- Express, CORS, PostgreSQL
- Custom MCP client over HTTP

## Architecture Decision: Side-by-Side Comparison

```
magma_soup/
├── api_server/              # Existing custom implementation
│   ├── src/
│   │   ├── services/
│   │   │   ├── agent.ts     # Custom agentic loop
│   │   │   ├── anthropic.ts # Direct SDK usage
│   │   │   └── mcp-client.ts # HTTP client to mcp_server
│   │   └── ...
│   └── package.json
│
├── agent_sdk_server/        # NEW: Agent SDK implementation
│   ├── src/
│   │   ├── services/
│   │   │   └── gis-tools.ts # In-process GIS tools (replaces mcp_server)
│   │   └── index.ts         # Agent SDK query() + Express
│   ├── package.json
│   └── README.md            # Comparison notes
│
├── flutter_client/          # Existing Flutter client
├── mcp_server/              # HTTP MCP server (used by api_server only)
└── docker-compose.yml       # Both servers on different ports
```

## Implementation Strategy: Progressive Phases

### Phase 1: Minimal Agentic Loop (Baseline)

**Goal:** Isolate core Agent SDK behavior vs custom implementation

**Scope:**

- ✅ Install and configure Agent SDK
- ✅ Basic query() usage with MCP tools
- ✅ Tool execution (no custom tools yet)
- ✅ Console logging (no SSE, no persistence)
- ✅ Single endpoint: POST /query

**Out of scope:**

- ❌ Persistence
- ❌ SSE streaming
- ❌ GIS-specific features
- ❌ Conversation history
- ❌ Flutter client integration

**Note:** The POST /query endpoint does NOT exist in the original api_server. It's a testing/exploration endpoint added to demonstrate minimal Agent SDK usage. The original api_server only has conversation-based endpoints. This endpoint is kept for developer convenience and debugging, but is not used by the Flutter client.

**Deliverable:** Simple Express server that accepts a prompt, executes agentic loop via SDK, returns final response

**Comparison metrics:**

- Lines of code
- Setup complexity
- MCP tool integration approach
- Error messages and debugging experience

### Phase 2: SSE Streaming

**Goal:** Demonstrate Agent SDK SSE streaming capabilities

**Scope:**

- ✅ Convert query() AsyncGenerator to SSE stream
- ✅ Map SDKMessage types to existing SSE event format
- ✅ Handle tool_call, tool_result, llm_response events
- ✅ Single endpoint: POST /query/stream

**Challenges to explore:**

- Does Agent SDK streaming map cleanly to our SSE format?
- Can we maintain the same event structure?
- What's lost/gained in translation?

**Note:** The POST /query/stream endpoint does NOT exist in the original api_server. Like POST /query, it's a testing/exploration endpoint. The original api_server only streams via POST /conversations/:id/messages. This endpoint demonstrates SSE streaming with the Agent SDK but is not used by the Flutter client.

**Deliverable:** SSE streaming endpoint for testing and exploration

### Phase 3: Persistence

**Goal:** Add PostgreSQL conversation storage

**Scope:**

- ✅ Reuse existing database schema
- ✅ Store conversations, messages, llm_history
- ✅ Load conversation history for context
- ✅ Use standard UUIDs for conversation IDs (no prefix needed)

**Comparison metrics:**

- How hard is it to extract conversation data from Agent SDK?
- Does SDK provide hooks for persistence?
- Can we reuse existing models?

**Known Issues:**

- ✅ FIXED: Agent SDK doesn't support `conversationHistory` parameter - worked around by including history in `systemPrompt`

### Phase 3.5: Flutter Client API Compatibility

**Goal:** Add missing conversation management endpoints for Flutter client integration

**Scope:**

- ✅ Add POST /conversations endpoint (create new conversation)
- ✅ Add GET /conversations endpoint (list recent conversations)
- ✅ Add GET /conversations/:id endpoint (get conversation with full history)
- ✅ POST /conversations/:id/messages already implemented in Phase 3

**Current State:**

The Flutter client (`flutter_client/lib/services/api_client.dart`) uses conversation-based endpoints only:

- POST /conversations (line 24) - Create conversation - **MISSING**
- GET /conversations (line 42) - List conversations - **MISSING**
- GET /conversations/:id (line 56) - Get conversation detail - **MISSING**
- POST /conversations/:id/messages (line 78) - Send message with SSE - ✅ **IMPLEMENTED**

The `/query` and `/query/stream` endpoints (Phase 1 & 2) are not used by Flutter - they exist for testing/debugging only.

**Implementation Notes:**

- Reuse existing database models (conversation.ts, message.ts)
- Match API contract from original api_server
- No Agent SDK involvement - these are simple CRUD operations
- Enables Flutter client to switch between servers via .env configuration

**Deliverable:** Full API compatibility with Flutter client, enabling server toggle

### Phase 4: GIS Features

**Goal:** Add domain-specific GIS functionality

**Scope:**

- ✅ Integrate GeoFeatureExtractor
- ✅ Integrate GisPromptBuilder
- ✅ Add remove_map_feature local tool
- ✅ Stream geo_feature events
- ✅ Store geo_features in database

**This is the critical test:**

- How does Agent SDK handle domain-specific customization?
- Can we inject custom logic into tool result processing?
- Is there a clean extension point?
- Or do we fight the framework?

**Deliverable:** Full feature parity with custom implementation

### Phase 5: Documentation & Analysis

**Goal:** Capture learnings for teaching

**Scope:**

- ✅ Document line-by-line comparison
- ✅ Identify strengths/weaknesses of each approach
- ✅ Performance comparison (if measurable)
- ✅ Developer experience notes
- ✅ When to use custom vs SDK

**Deliverable:** agent_sdk_server/COMPARISON.md

## Technical Specifications

### Port Assignment

- mcp_server: 3000 (existing GIS tools)
- api_server: 3001 (existing custom implementation)
- agent_sdk_server: 3002 (new Agent SDK implementation)

### Package.json for agent_sdk_server

```json
{
  "name": "agent_sdk_server",
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "latest",
    "express": "^5.1.0",
    "cors": "^2.8.5",
    "dotenv": "^17.2.3",
    "pg": "^8.16.3"
  },
  "type": "module"
}
```

### Environment Variables

Reuse existing `.env`:

- `ANTHROPIC_API_KEY`
- `DATABASE_URL`
- `MCP_SERVER_URL`
- Add: `AGENT_SDK_SERVER_PORT=3002`

### Database Strategy

**Option A: Shared database**

- Use standard UUIDs for conversation IDs
- Reuse existing schema
- Easier comparison of stored data
- No namespace needed - conversations are independent

**Option B: Separate database**

- Clone schema
- Complete isolation
- Cleaner but more setup

**Decision:** Use Option A (shared database) for easier comparison

## Agent SDK Integration Points

### 1. In-Process Tool Integration

**Decision: Port MCP tools to in-process format**

The Agent SDK uses in-process tools via `createSdkMcpServer()`, not external HTTP MCP servers. This is a fundamental architectural difference:

- **Custom implementation**: External HTTP MCP server, tools called over network
- **Agent SDK implementation**: In-process tools, direct function calls

```typescript
// Agent SDK approach - in-process GIS tools
import { query, createSdkMcpServer, tool } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const gisTools = createSdkMcpServer({
  name: "gis-tools",
  version: "1.0.0",
  tools: [
    tool("calculate_distance", "Calculate distance between points", {...}, async (args) => {...}),
    tool("geocode_address", "Convert address to coordinates", {...}, async (args) => {...}),
    // ... other GIS tools
  ]
});

const result = query({
  prompt: userMessage,
  options: {
    workingDirectory: process.cwd(),
    mcpServers: { "gis-tools": gisTools }
  }
});
```

This means the Agent SDK server **replaces** the external mcp_server for its own operation, while the custom api_server continues to use the HTTP-based mcp_server.

### 2. Custom Local Tools

```typescript
// Our custom tool: remove_map_feature
const removeFeatureTool = tool(
  "remove_map_feature",
  "Remove a geographic feature from the map",
  {
    feature_id: z.string(),
  },
  async (args) => {
    // How to access conversation context here?
    // Need conversationId to query database
    // Agent SDK might not pass this context
    return { success: true, removed_feature_id: args.feature_id };
  }
);
```

**Investigation needed:**

- How to pass conversation context to tool handlers?
- Can we access request scope from tool functions?

### 3. Streaming Message Types

```typescript
// Map SDK messages to our SSE format
for await (const message of result) {
  switch (message.type) {
    case "assistant":
      // Extract tool calls -> map to our tool_call events
      // Extract text -> map to our llm_response events
      break;
    case "result":
      // Final completion
      break;
    case "partial":
      // Streaming tokens (if enabled)
      break;
  }
}
```

**Investigation needed:**

- Does SDK expose tool_call and tool_result as separate events?
- Or are they bundled in assistant messages?
- Can we get the same granularity as our custom implementation?

### 4. GIS Feature Extraction

```typescript
// After tool execution, extract geo features
// Custom implementation: agent.ts:192-207

// Agent SDK: where does this hook in?
// - In tool handler? (coupling)
// - After receiving tool_result message? (inspect message content)
// - Custom middleware? (if SDK supports it)
```

**Investigation needed:**

- Extension points for post-tool-execution logic
- Access to raw tool results
- Clean separation of concerns

## Key Questions to Answer

### Architecture

1. Does Agent SDK force an execution model that conflicts with our HTTP API approach?
2. Can we maintain the same request/response contract with Flutter?
3. How does SDK handle concurrent requests?

### MCP Integration

4. ✅ ANSWERED: SDK only supports in-process via createSdkMcpServer(), not external HTTP
5. ✅ ANSWERED: Yes - porting provides valuable comparison of architectures
6. ✅ ANSWERED: Yes - tool schemas are identical, just execution model differs

### Customization

7. Where do we inject GIS-specific logic?
8. Can we extract and store conversation state for persistence?
9. How much SDK internals do we need to fight/work around?

### Streaming

10. Does SDK streaming match our SSE granularity?
11. Can we maintain exact SSE event format for Flutter?
12. What's the latency difference?

### Developer Experience

13. Is SDK debugging easier or harder than custom code?
14. How's the documentation for edge cases?
15. What's the learning curve for new developers?

## Success Criteria

### Technical

- ✅ Feature parity with custom implementation
- ✅ Flutter client works with both servers (config switch)
- ✅ Same database schema works for both
- ✅ Performance is comparable (within 20%)

### Educational

- ✅ Clear documentation of tradeoffs
- ✅ Code examples highlighting key differences
- ✅ Decision framework: when to use custom vs SDK
- ✅ Gotchas and workarounds documented

### Code Quality

- ✅ Agent SDK implementation is clean and idiomatic
- ✅ Not fighting the framework with hacks
- ✅ Maintainable by future developers

## Risk Assessment

### High Risk

- **MCP Integration:** SDK might not support external HTTP MCP servers

  - Mitigation: Port mcp_server tools to in-process format
  - Impact: High effort, defeats purpose of modular MCP server

- **Custom Tool Context:** Tool handlers might not have access to request scope
  - Mitigation: Use global state, thread-local storage, or workarounds
  - Impact: Ugly code, not idiomatic

### Medium Risk

- **SSE Mapping:** SDK message format might not map cleanly to our SSE events

  - Mitigation: Translation layer, but might lose fidelity
  - Impact: Flutter client might need changes

- **GIS Customization:** No clean extension points for domain logic
  - Mitigation: Monkey-patch, wrapper classes
  - Impact: Defeats purpose of using framework

### Low Risk

- **Persistence:** Can likely intercept messages and store

  - Mitigation: Standard DB operations
  - Impact: Just more code

- **Performance:** SDK might add overhead
  - Mitigation: Acceptable for teaching purposes
  - Impact: Document differences

## Timeline Estimate

- **Phase 1:** 4-6 hours (setup, basic loop)
- **Phase 2:** 3-4 hours (SSE streaming)
- **Phase 3:** 2-3 hours (persistence)
- **Phase 4:** 4-6 hours (GIS features)
- **Phase 5:** 3-4 hours (documentation)

**Total:** 16-23 hours

**Reality check:** Double for unexpected issues = 32-46 hours

## Alternative Approaches Considered

### Option A: Fork Flutter Client

**Pros:** Freedom to change API contract
**Cons:** Harder to compare, more code to maintain
**Decision:** Not needed for Phase 1, revisit if SSE mapping is painful

### Option B: Minimal POC (no full parity)

**Pros:** Faster, proves basic concepts
**Cons:** Doesn't answer hard questions about GIS customization
**Decision:** Use progressive phases instead

### Option C: Pure CLI agent (no HTTP server)

**Pros:** Simplest use of SDK
**Cons:** Can't compare to existing architecture
**Decision:** Not valuable for teaching purposes

## Next Steps

1. Create `agent_sdk_server/` directory
2. Set up package.json and tsconfig
3. Start Phase 1: minimal implementation
4. Document findings as we go
5. Adjust plan based on discoveries

## Open Questions for Ed

1. **MCP Server:** If SDK requires in-process tools, should we port mcp_server code or skip MCP integration initially?
   Ed's Answer --> Port it. Consider which execution model would be best (Skills?)

2. **Flutter Client:** Should we modify it to connect to both servers, or test agent_sdk_server independently?
   Ed's Answer --> Test independently. Start with a .env variable, but later we can add a settings area on the client to toggle.

3. **Documentation Style:** Inline code comments vs separate comparison doc? Or both?
   Ed's Answer --> Separate comparison. Readme?

4. **Scope Priority:** If we hit roadblocks, which features are must-have vs nice-to-have?
   Ed's Answer --> Decide as we go.

5. **Success Definition:** Is "proves it's possible" enough, or does it need to be production-ready?
   Ed's Answer --> Start with possible. None of this is production ready yet.
