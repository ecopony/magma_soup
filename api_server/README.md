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
- Integration with Anthropic Claude API with full conversation context
- HTTP client for MCP server communication
- PostgreSQL persistence with PostGIS spatial data support
- Unified message storage (conversation and LLM trace in single table)

## Setup

### Prerequisites

- Node.js 20+
- PostgreSQL with PostGIS extension
- Running MCP server on port 3000
- Anthropic API key

### Installation

```bash
npm install
```

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Required
ANTHROPIC_API_KEY=sk-ant-...

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=magma_soup
DB_USER=postgres
DB_PASSWORD=postgres

# Servers
MCP_SERVER_URL=http://localhost:3000
PORT=3001
NODE_ENV=development
```

### Database Setup

#### Option 1: Docker (Recommended)

```bash
docker run -d \
  --name magma-postgis \
  -e POSTGRES_DB=magma_soup \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgis/postgis:15-3.4
```

#### Option 2: Local PostgreSQL

Install PostgreSQL and PostGIS extension locally, then create the database:

```bash
createdb magma_soup
psql magma_soup -c "CREATE EXTENSION postgis;"
```

### Database Migrations

Run migrations to create the schema:

```bash
npm run migrate
```

This creates:
- `conversations` - Conversation metadata
- `messages` - All message types (user, assistant, user_prompt, llm_response, tool_call, tool_result, tool_error)
- `geo_features` - Geographic features with PostGIS geometry

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

### Create Conversation

```bash
POST /conversations
Content-Type: application/json

{
  "title": "My GIS Conversation"
}
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2024-11-02T10:00:00Z",
  "updated_at": "2024-11-02T10:00:00Z",
  "title": "My GIS Conversation",
  "metadata": null
}
```

### List Conversations

```bash
GET /conversations?limit=50&offset=0
```

Response:
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "created_at": "2024-11-02T10:00:00Z",
    "updated_at": "2024-11-02T10:05:00Z",
    "title": "My GIS Conversation",
    "metadata": null
  }
]
```

### Get Conversation with History

```bash
GET /conversations/:id
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2024-11-02T10:00:00Z",
  "updated_at": "2024-11-02T10:05:00Z",
  "title": "My GIS Conversation",
  "messages": [
    {
      "id": "...",
      "type": "user",
      "content": {"text": "What is the distance between SF and LA?"},
      "timestamp": "2024-11-02T10:01:00Z",
      "sequence_number": 1,
      "geo_features": []
    },
    {
      "id": "...",
      "type": "assistant",
      "content": {"text": "The distance is approximately 559 km."},
      "timestamp": "2024-11-02T10:01:30Z",
      "sequence_number": 2,
      "geo_features": [...]
    }
  ]
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

Note: If the conversation ID doesn't exist, it will be auto-created.

## SSE Event Types

The `/conversations/:id/messages` endpoint streams the following events:

### `user_prompt`

The enhanced prompt sent to Claude (includes GIS system prompt).

```json
{
  "prompt": "You are a GIS assistant...\n\nUser request: What is the distance between SF and LA?"
}
```

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
  "tool_use_id": "toolu_123",
  "tool_name": "geocode_address",
  "arguments": { "address": "San Francisco" }
}
```

### `tool_result`

Tool execution completed.

```json
{
  "tool_use_id": "toolu_123",
  "tool_name": "geocode_address",
  "result": "{\"lat\": 37.7749, \"lon\": -122.4194}"
}
```

### `tool_error`

Tool execution failed.

```json
{
  "tool_use_id": "toolu_123",
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
  "geo_features": [...]
}
```

Note: LLM history is no longer sent in the `done` event as all interactions are streamed in real-time via the event types above.

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

Create a conversation:
```bash
CONV_ID=$(curl -s -X POST http://localhost:3001/conversations \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Conversation"}' | jq -r '.id')
echo "Conversation ID: $CONV_ID"
```

Test simple message:
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"Hello, how are you?"}' \
  http://localhost:3001/conversations/$CONV_ID/messages
```

Test geocoding:
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"What are the coordinates of San Francisco?"}' \
  http://localhost:3001/conversations/$CONV_ID/messages
```

Test multi-tool scenario:
```bash
curl -N -H "Content-Type: application/json" \
  -d '{"message":"What is the distance between San Francisco and Los Angeles?"}' \
  http://localhost:3001/conversations/$CONV_ID/messages
```

Get conversation history:
```bash
curl http://localhost:3001/conversations/$CONV_ID | jq
```

List all conversations:
```bash
curl http://localhost:3001/conversations | jq
```

### Database Verification

Connect to the database and inspect data:

```bash
# Using Docker
docker exec -it magma-postgis psql -U postgres -d magma_soup

# Check conversations
SELECT id, title, created_at FROM conversations;

# Check messages for a conversation (all types)
SELECT type, timestamp, sequence_number
FROM messages
WHERE conversation_id = 'YOUR-CONVERSATION-ID'
ORDER BY sequence_number;

# Check only user/assistant conversation
SELECT type, content, timestamp
FROM messages
WHERE conversation_id = 'YOUR-CONVERSATION-ID'
  AND type IN ('user', 'assistant')
ORDER BY sequence_number;

# Check geographic features
SELECT id, feature_type, ST_AsText(geometry) as location, properties
FROM geo_features;
```

## Project Structure

```
api_server/
├── src/
│   ├── index.ts              # Main entry point
│   ├── config/
│   │   └── database.ts       # Database connection pool
│   ├── models/
│   │   ├── conversation.ts   # Conversation model
│   │   ├── message.ts        # Unified message model (all types)
│   │   └── geo-feature.ts    # Geographic feature model
│   ├── services/
│   │   ├── anthropic.ts      # Claude API client
│   │   ├── mcp-client.ts     # MCP server HTTP client
│   │   ├── agent.ts          # Agentic loop with persistence
│   │   ├── gis-prompt-builder.ts     # GIS prompt construction
│   │   └── geo-feature-extractor.ts  # Geographic feature extraction
│   ├── routes/
│   │   └── conversations.ts  # API routes (CRUD + SSE)
│   ├── types/
│   │   └── index.ts          # TypeScript interfaces
│   └── utils/
│       ├── sse.ts            # SSE streaming utility
│       └── migrate.ts        # Database migration runner
├── migrations/
│   ├── 001_initial_schema.sql    # Core tables
│   ├── 002_geo_features.sql      # PostGIS tables
│   └── 003_unify_messages.sql    # Unified message table
├── dist/                     # Compiled JavaScript (generated)
├── package.json
├── tsconfig.json
├── Dockerfile
├── .dockerignore
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
- `pg` - PostgreSQL client

### Development
- `typescript` - TypeScript compiler
- `tsx` - TypeScript execution
- `@types/express` - Express types
- `@types/node` - Node types
- `@types/cors` - CORS types
- `@types/pg` - PostgreSQL types

## Docker

### Building

```bash
# Build image
docker build -t magma-soup-api-server .

# Build without cache
docker build --no-cache -t magma-soup-api-server .
```

### Running with Docker Compose

See the root `docker-compose.yml` for the full stack configuration. The API server:
- Depends on PostgreSQL and MCP server being healthy
- Runs migrations automatically on startup
- Connects to services via Docker network

```bash
# Start all services
docker-compose up

# Rebuild and start
docker-compose up --build

# View logs
docker-compose logs -f api_server

# Stop services
docker-compose down
```

### Troubleshooting Docker

**esbuild platform errors:**
The `.dockerignore` file prevents copying host `node_modules` to avoid platform-specific binary issues. If you still see errors:

```bash
docker-compose build --no-cache api_server
docker-compose up --force-recreate
```

**Database connection errors:**
Ensure PostgreSQL is healthy before the API server starts. The `depends_on` with `condition: service_healthy` in docker-compose handles this, but you can verify:

```bash
docker-compose ps
docker logs magma-soup-postgis
```

## Database Schema

### conversations
| Column     | Type                        | Description |
|------------|-----------------------------|-------------|
| id         | UUID                        | Primary key |
| created_at | TIMESTAMP WITH TIME ZONE    | Creation time |
| updated_at | TIMESTAMP WITH TIME ZONE    | Last update |
| title      | TEXT                        | Optional title |
| metadata   | JSONB                       | Optional metadata |

### messages
| Column          | Type                     | Description |
|-----------------|--------------------------|-------------|
| id              | UUID                     | Primary key |
| conversation_id | UUID                     | Foreign key to conversations |
| type            | TEXT                     | Message type: 'user', 'assistant', 'user_prompt', 'llm_response', 'tool_call', 'tool_result', 'tool_error' |
| sequence_number | INTEGER                  | Order in conversation (across all types) |
| timestamp       | TIMESTAMP WITH TIME ZONE | Creation time |
| content         | JSONB                    | Type-specific content |

Content structure by type:
- `user`: `{"text": "user message"}`
- `assistant`: `{"text": "assistant response"}`
- `user_prompt`: `{"prompt": "enhanced prompt with GIS context"}`
- `llm_response`: `{"content": [...], "stop_reason": "end_turn"}`
- `tool_call`: `{"tool_use_id": "toolu_123", "tool_name": "geocode", "arguments": {...}}`
- `tool_result`: `{"tool_use_id": "toolu_123", "tool_name": "geocode", "result": "..."}`
- `tool_error`: `{"tool_use_id": "toolu_123", "tool_name": "geocode", "error": "..."}`

### geo_features
| Column       | Type                     | Description |
|--------------|--------------------------|-------------|
| id           | UUID                     | Primary key |
| message_id   | UUID                     | Foreign key to messages |
| feature_type | TEXT                     | 'marker', 'line', or 'polygon' |
| geometry     | GEOMETRY(Geometry, 4326) | PostGIS geometry (WGS84) |
| properties   | JSONB                    | Feature properties |
| created_at   | TIMESTAMP WITH TIME ZONE | Creation time |

## Migration Management

Migrations are stored in `migrations/` and tracked in the `migrations` table.

### Creating Migrations

```bash
cd migrations
touch 003_my_feature.sql
```

Write your SQL:
```sql
-- Add new column
ALTER TABLE conversations ADD COLUMN user_id UUID;

-- Create index
CREATE INDEX idx_conversations_user ON conversations(user_id);
```

Run migrations:
```bash
npm run migrate
```

### Migration Scripts

- `npm run migrate` - Development (uses tsx to run TypeScript)
- `npm run migrate:prod` - Production (uses compiled JavaScript)

### Checking Migration Status

```bash
docker exec -it magma-postgis psql -U postgres -d magma_soup

SELECT * FROM migrations ORDER BY id;
```

## Performance Considerations

### Database Connection Pooling

The `pg` connection pool is configured with defaults. For production, tune in `src/config/database.ts`:

```typescript
const pool = new Pool({
  max: 20,           // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### Indexes

Key indexes are created by migrations:
- `conversations(created_at DESC)` - Fast recent conversations
- `messages(conversation_id, sequence_number)` - Fast message retrieval
- `llm_history(message_id, sequence_number)` - Fast history lookup
- `geo_features(geometry) GIST` - Spatial queries

### Query Optimization

Use EXPLAIN ANALYZE for slow queries:

```sql
EXPLAIN ANALYZE
SELECT * FROM messages
WHERE conversation_id = 'some-uuid'
ORDER BY sequence_number;
```
