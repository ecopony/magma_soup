# Architecture Changes

## Goals

**Primary objectives:**
1. **Security**: Remove API keys from Flutter client (Anthropic API key specifically)
2. **Scalability**: Enable robust server-side functionality and multi-client support
3. **Architecture**: Clean separation - Flutter (UI) → API Server (orchestration) → MCP Server (tools) → PostGIS (data)

**Secondary objectives:**
1. Conversation persistence in PostGIS database
2. Containerized deployment with docker-compose
3. Streaming responses via SSE for responsive UX

---

## Plan

### 1. Create API Server (TypeScript)
- **Location**: `api_server/` directory
- **Framework**: Express (consistent with MCP server)
- **Responsibilities**:
  - Accept POST `/messages` with user commands
  - Execute agentic loop (currently in `chat_bloc.dart:86-179`)
  - Call Anthropic API with tools
  - Call MCP server HTTP endpoints (`/tools/call`) for tool execution
  - Stream responses back via SSE
  - Extract and return geographic features from tool results
- **Endpoints**:
  - `POST /conversations` - Create new conversation
  - `POST /conversations/:id/messages` - Send message, returns SSE stream
  - `GET /conversations/:id` - Get conversation history

### 2. Add PostGIS Database
- **Container**: PostgreSQL with PostGIS extension
- **Schema** (initial):
  - `conversations` table (id, created_at, updated_at)
  - `messages` table (id, conversation_id, role, content, timestamp)
  - Future: spatial data from tool results
- **Access**: API server connects via connection string

### 3. Docker Compose Setup
- **Services**:
  - `postgis` - PostgreSQL 15+ with PostGIS extension
  - `mcp_server` - Existing GIS tools server (port 3000)
  - `api_server` - New orchestration layer (port 3001)
- **Networking**: Internal docker network, only API server exposed externally
- **Volumes**: Database persistence

### 4. Update Flutter Client
- **Remove**:
  - `AnthropicService`
  - Agentic loop from `ChatBloc._onSendCommand`
  - API key configuration
- **Add**:
  - SSE client (using `flutter_client_sse` or similar)
  - API client service to call API server endpoints
- **Change**: `ChatBloc` sends command to API server, consumes SSE stream for responses

---

## Implementation Order

**Phase 1: API Server + MCP Integration**
- Set up api_server directory structure
- Implement agentic loop (port from chat_bloc.dart)
- Integrate with MCP server HTTP endpoints
- Implement SSE streaming

**Phase 2: Database Layer**
- Create PostGIS Docker container
- Design schema for conversations/messages
- Implement database models and queries in API server
- Add conversation persistence

**Phase 3: Docker Compose**
- Create docker-compose.yml
- Dockerfiles for api_server and mcp_server
- Environment variable configuration
- Test full stack locally

**Phase 4: Flutter Client Updates**
- Add SSE client dependency
- Replace ChatBloc implementation
- Remove Anthropic service and keys
- Test end-to-end flow
