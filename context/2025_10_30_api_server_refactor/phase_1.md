# Phase 1: API Server + MCP Integration

## Overview
Create TypeScript API server that handles the agentic loop, integrates with Anthropic API and MCP server, and streams responses via SSE.

---

## Step 1: Project Setup

### 1.1 Create Directory Structure
```
api_server/
├── src/
│   ├── index.ts              # Main entry point
│   ├── services/
│   │   ├── anthropic.ts      # Anthropic API client
│   │   ├── mcp-client.ts     # MCP server HTTP client
│   │   └── agent.ts          # Agentic loop implementation
│   ├── routes/
│   │   └── conversations.ts  # API routes
│   ├── types/
│   │   └── index.ts          # TypeScript interfaces
│   └── utils/
│       └── logger.ts         # Logging utility
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

### 1.2 Initialize NPM Project
```bash
cd api_server
npm init -y
```

### 1.3 Install Dependencies
**Production:**
- `express` - Web framework
- `@anthropic-ai/sdk` - Anthropic API client
- `cors` - CORS middleware
- `dotenv` - Environment variables
- `express` - Web server

**Development:**
- `typescript` - TypeScript compiler
- `tsx` - TypeScript execution
- `@types/express` - Express types
- `@types/node` - Node types
- `@types/cors` - CORS types

```bash
npm install express @anthropic-ai/sdk cors dotenv
npm install -D typescript tsx @types/express @types/node @types/cors
```

### 1.4 TypeScript Configuration
Create `tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
```

### 1.5 Package Scripts
Update `package.json` scripts:
```json
{
  "scripts": {
    "build": "tsc",
    "dev": "tsx watch src/index.ts",
    "start": "node dist/index.js"
  }
}
```

### 1.6 Environment Configuration
Create `.env.example`:
```
ANTHROPIC_API_KEY=sk-ant-...
MCP_SERVER_URL=http://localhost:3000
PORT=3001
NODE_ENV=development
```

---

## Step 2: Core Services Implementation

### 2.1 TypeScript Type Definitions (`src/types/index.ts`)
```typescript
export interface Message {
  role: 'user' | 'assistant';
  content: string | ContentBlock[];
}

export interface ContentBlock {
  type: 'text' | 'tool_use' | 'tool_result';
  text?: string;
  id?: string;
  name?: string;
  input?: Record<string, any>;
  tool_use_id?: string;
  content?: string;
  is_error?: boolean;
}

export interface ToolUse {
  id: string;
  name: string;
  input: Record<string, any>;
}

export interface Tool {
  name: string;
  description: string;
  input_schema: Record<string, any>;
}

export interface LLMHistoryEntry {
  type: 'user_prompt' | 'llm_response' | 'tool_call' | 'tool_result' | 'tool_error';
  timestamp: string;
  content?: any;
  stop_reason?: string;
  tool_name?: string;
  arguments?: Record<string, any>;
  result?: string;
  error?: string;
}

export interface AgenticLoopResult {
  finalResponse: string;
  llmHistory: LLMHistoryEntry[];
  geoFeatures: GeoFeature[];
}

export interface GeoFeature {
  type: 'marker';
  lat: number;
  lon: number;
  label?: string;
}
```

### 2.2 Anthropic Service (`src/services/anthropic.ts`)
Port from `flutter_client/lib/services/anthropic_service.dart`

**Key methods:**
- `sendMessage(options)` - Call Anthropic API (lines 25-80)
- `extractTextResponse(response)` - Extract text from response (lines 82-89)
- `extractToolUses(response)` - Extract tool use blocks (lines 91-100)

**Implementation notes:**
- Use `@anthropic-ai/sdk` package
- Model: `claude-sonnet-4-5-20250929`
- Max tokens: 4096
- API version: `2023-06-01`

### 2.3 MCP Client Service (`src/services/mcp-client.ts`)
Port from `flutter_client/lib/services/mcp_service.dart`

**Key methods:**
- `listTools()` - GET tools from MCP server (lines 19-35)
- `callTool(name, arguments)` - Execute tool on MCP server (lines 38-66)
- `getToolsForAnthropic()` - Transform to Anthropic format (lines 69-78)

**Implementation notes:**
- Default MCP URL: `http://localhost:3000`
- Endpoints: `/tools/list` and `/tools/call`
- Handle MCP response format: `{ content: [{ type: 'text', text: '...' }] }`

### 2.4 Agent Service (`src/services/agent.ts`)
Port agentic loop from `flutter_client/lib/bloc/chat_bloc.dart:34-231`

**Key functionality:**
- Execute agentic loop with tool use (lines 86-179)
- Safety limit: max 10 tool calls
- Build conversation history
- Track LLM interaction history
- Extract geographic features from tool results

**Pseudocode:**
```typescript
async function executeAgenticLoop(
  userMessage: string,
  onProgress?: (update: StreamUpdate) => void
): Promise<AgenticLoopResult> {
  // 1. Get MCP tools
  // 2. Build initial prompt with GIS context
  // 3. Call Anthropic with tools
  // 4. While stop_reason === 'tool_use' and toolCallCount < 10:
  //    a. Extract tool uses
  //    b. Execute each tool via MCP client
  //    c. Stream progress updates
  //    d. Collect tool results
  //    e. Continue conversation with tool results
  // 5. Extract final text response
  // 6. Return result with llmHistory and geoFeatures
}
```

### 2.5 GIS Prompt Builder
Port from `flutter_client/lib/services/gis_prompt_builder.dart`

**Purpose:** Add GIS context to user prompts

### 2.6 Geo Feature Extractor
Port from `flutter_client/lib/services/geo_feature_extractor.dart`

**Purpose:** Extract markers/geographic features from tool results

---

## Step 3: SSE Streaming Implementation

### 3.1 SSE Response Handler
Create utility for SSE responses:

```typescript
// src/utils/sse.ts
export class SSEStream {
  constructor(private res: Response) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
  }

  send(event: string, data: any) {
    this.res.write(`event: ${event}\n`);
    this.res.write(`data: ${JSON.stringify(data)}\n\n`);
  }

  end() {
    this.res.end();
  }
}
```

### 3.2 Stream Event Types
- `tool_call` - Tool execution started
- `tool_result` - Tool execution completed
- `llm_response` - LLM response chunk
- `geo_feature` - Geographic feature extracted
- `done` - Conversation complete
- `error` - Error occurred

---

## Step 4: API Endpoints

### 4.1 Routes (`src/routes/conversations.ts`)

**POST `/conversations/:id/messages`**
- Accept: `{ message: string }`
- Returns: SSE stream
- Process:
  1. Validate conversation ID (for now, any ID works)
  2. Execute agentic loop with streaming callbacks
  3. Stream progress events
  4. Send final response
  5. Close stream

**GET `/health`**
- Returns: `{ status: 'ok', service: 'api-server' }`

### 4.2 Main Server (`src/index.ts`)
```typescript
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import conversationRoutes from './routes/conversations';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/conversations', conversationRoutes);
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'api-server' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`API Server running on http://localhost:${PORT}`);
});
```

---

## Step 5: Testing

### 5.1 Manual Testing with curl

**Health check:**
```bash
curl http://localhost:3001/health
```

**Send message (SSE stream):**
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"What is the distance between San Francisco and Los Angeles?"}' \
  http://localhost:3001/conversations/test-123/messages
```

### 5.2 Test Scenarios
1. Simple message without tool use
2. Message requiring single tool call (geocode_address)
3. Message requiring multiple tool calls (geocode + calculate_distance)
4. Message hitting tool call limit
5. Error handling (invalid tool arguments)

### 5.3 Validation Checklist
- [ ] SSE stream sends events in real-time
- [ ] Tool calls execute correctly via MCP server
- [ ] Agentic loop handles multiple tool calls
- [ ] Max tool call limit prevents infinite loops
- [ ] Geographic features extracted from tool results
- [ ] Error handling returns proper error events
- [ ] CORS allows Flutter client connections

---

## Step 6: Documentation

### 6.1 README.md
Create `api_server/README.md` with:
- Project description
- Setup instructions
- Environment variables
- API endpoints documentation
- Development workflow

### 6.2 API Documentation
Document SSE event schema and endpoint contracts

---

## Files to Port

**From Flutter client:**
1. `lib/services/anthropic_service.dart` → `src/services/anthropic.ts`
2. `lib/services/mcp_service.dart` → `src/services/mcp-client.ts`
3. `lib/services/gis_prompt_builder.dart` → `src/services/gis-prompt-builder.ts`
4. `lib/services/geo_feature_extractor.dart` → `src/services/geo-feature-extractor.ts`
5. `lib/bloc/chat_bloc.dart` (lines 34-231) → `src/services/agent.ts`

---

## Success Criteria

Phase 1 is complete when:
1. ✅ API server accepts POST requests with user messages
2. ✅ Server executes agentic loop with Anthropic API
3. ✅ Server calls MCP server tools via HTTP
4. ✅ Server streams progress via SSE
5. ✅ Geographic features extracted from tool results
6. ✅ Error handling works correctly
7. ✅ Manual testing with curl succeeds for all scenarios
8. ✅ Server runs independently without Flutter client

---

## Next Steps
After Phase 1 completion, proceed to Phase 2: Database Layer (PostGIS integration and conversation persistence).
