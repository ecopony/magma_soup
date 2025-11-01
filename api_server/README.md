# API Server

Orchestration layer for the Magma Soup GIS application. Implements the agentic loop with Claude API and MCP tool integration.

## Architecture

The API server acts as the bridge between the Flutter UI client and the MCP server:

- **Flutter Client** → sends user commands
- **API Server** → executes agentic loop, calls Claude API with tools
- **MCP Server** → provides GIS tools (geocoding, distance calculation, etc.)

## Features

- Agentic loop implementation with tool use
- Server-Sent Events (SSE) streaming for real-time progress updates
- Geographic feature extraction from tool results
- Integration with Anthropic Claude API
- HTTP client for MCP server communication

## Setup

### Prerequisites

- Node.js 18+
- Running MCP server on port 3000
- Anthropic API key

### Installation

```bash
npm install
```

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
ANTHROPIC_API_KEY=sk-ant-...
MCP_SERVER_URL=http://localhost:3000
PORT=3001
NODE_ENV=development
```

## Running

### Development Mode

```bash
npm run dev
```

The server will start on `http://localhost:3001` with hot reload enabled.

### Production Mode

```bash
npm run build
npm start
```

## API Endpoints

### Health Check

```bash
GET /health
```

Response:
```json
{
  "status": "ok",
  "service": "api-server"
}
```

### Send Message

```bash
POST /conversations/:id/messages
Content-Type: application/json

{
  "message": "What is the distance between San Francisco and Los Angeles?"
}
```

Response: Server-Sent Events (SSE) stream

## SSE Event Types

The `/conversations/:id/messages` endpoint streams the following events:

### `llm_response`

LLM response from Claude API.

```json
{
  "stop_reason": "tool_use",
  "content": [...]
}
```

### `tool_call`

Tool execution started.

```json
{
  "tool_name": "geocode_address",
  "arguments": { "address": "San Francisco" }
}
```

### `tool_result`

Tool execution completed.

```json
{
  "tool_name": "geocode_address",
  "result": "{\"lat\": 37.7749, \"lon\": -122.4194}"
}
```

### `tool_error`

Tool execution failed.

```json
{
  "tool_name": "geocode_address",
  "error": "Address not found"
}
```

### `geo_feature`

Geographic feature extracted from tool result.

```json
{
  "type": "marker",
  "lat": 37.7749295,
  "lon": -122.4194155,
  "label": "San Francisco"
}
```

### `done`

Conversation complete.

```json
{
  "final_response": "The distance is 559 km",
  "llm_history": [...],
  "geo_features": [...]
}
```

### `error`

Error occurred during processing.

```json
{
  "error": "Maximum tool call limit reached"
}
```

## Testing

### Manual Testing with curl

Test health check:
```bash
curl http://localhost:3001/health
```

Test simple message:
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"Hello, how are you?"}' \
  http://localhost:3001/conversations/test-123/messages
```

Test geocoding:
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"What are the coordinates of San Francisco?"}' \
  http://localhost:3001/conversations/test-456/messages
```

Test multi-tool scenario:
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"What is the distance between San Francisco and Los Angeles?"}' \
  http://localhost:3001/conversations/test-789/messages
```

## Project Structure

```
api_server/
├── src/
│   ├── index.ts              # Main entry point
│   ├── services/
│   │   ├── anthropic.ts      # Claude API client
│   │   ├── mcp-client.ts     # MCP server HTTP client
│   │   ├── agent.ts          # Agentic loop implementation
│   │   ├── gis-prompt-builder.ts     # GIS prompt construction
│   │   └── geo-feature-extractor.ts  # Geographic feature extraction
│   ├── routes/
│   │   └── conversations.ts  # API routes
│   ├── types/
│   │   └── index.ts          # TypeScript interfaces
│   └── utils/
│       └── sse.ts            # SSE streaming utility
├── package.json
├── tsconfig.json
├── .env                      # Environment variables (not in git)
├── .env.example              # Example environment variables
└── README.md
```

## Configuration

### Max Tool Calls

The agentic loop has a safety limit of 10 tool calls per conversation. This prevents infinite loops. The limit can be adjusted in `src/services/agent.ts`:

```typescript
private maxToolCalls = 10;
```

### Claude Model

The default model is `claude-sonnet-4-5-20250929`. This can be changed in `src/services/anthropic.ts`:

```typescript
private model = 'claude-sonnet-4-5-20250929';
```

## Dependencies

### Production
- `express` - Web framework
- `@anthropic-ai/sdk` - Anthropic API client
- `cors` - CORS middleware
- `dotenv` - Environment variables

### Development
- `typescript` - TypeScript compiler
- `tsx` - TypeScript execution
- `@types/express` - Express types
- `@types/node` - Node types
- `@types/cors` - CORS types
