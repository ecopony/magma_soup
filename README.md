# Magma Soup

A GIS-enabled conversational application with Flutter desktop client, agentic API server, and PostgreSQL/PostGIS persistence.

## Overview

Magma Soup combines natural language interaction with geographic information system (GIS) capabilities. Users can ask questions about locations, distances, and geographic data through a conversational interface.

## Architecture

```
┌─────────────────┐
│ Flutter Client  │ Desktop UI with map visualization
│   (macOS)       │
└────────┬────────┘
         │ HTTP/SSE
         ▼
┌─────────────────┐
│   API Server    │ Agentic loop orchestration
│   (Node.js)     │ Claude API integration
└────┬───────┬────┘
     │       │
     │       └──────┐
     │              │ HTTP
     ▼              ▼
┌─────────┐   ┌──────────┐
│PostgreSQL│   │   MCP    │ GIS tools
│ PostGIS  │   │  Server  │ (geocoding, distance, etc.)
└──────────┘   └──────────┘
```

### Components

1. **Flutter Client** (`flutter_client/`)
   - Desktop application (macOS)
   - Two-pane UI: chat + results/map
   - BLoC state management
   - Solarized Light theme

2. **API Server** (`api_server/`)
   - Node.js + Express + TypeScript
   - Agentic loop with tool use
   - Claude Sonnet 4.5 integration
   - PostgreSQL persistence
   - SSE streaming for real-time updates

3. **MCP Server** (`mcp_server/`)
   - Model Context Protocol server
   - GIS tool implementations
   - TypeScript SDK

4. **Database** (PostgreSQL + PostGIS)
   - Conversation history
   - Message storage
   - LLM interaction tracking
   - Geographic feature persistence

## Quick Start

### Docker Compose (Recommended)

Run the entire stack with one command:

```bash
# Copy and configure environment variables
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY

# Start all services
docker-compose up --build

# Services will be available at:
# - API Server: http://localhost:3001
# - MCP Server: http://localhost:3000
# - PostgreSQL: localhost:5432
```

The first time you run this, Docker will:
- Pull the PostGIS image
- Build the MCP and API server images
- Run database migrations automatically
- Start all services with health checks

### Development Setup

#### Prerequisites

- Node.js 20+
- Flutter SDK (for client development)
- Docker (for PostgreSQL)
- Anthropic API key

#### 1. Start PostgreSQL with PostGIS

```bash
docker run -d \
  --name magma-postgis \
  -e POSTGRES_DB=magma_soup \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgis/postgis:15-3.4
```

#### 2. Start MCP Server

```bash
cd mcp_server
npm install
npm run dev
# Server runs on http://localhost:3000
```

#### 3. Start API Server

```bash
cd api_server
npm install

# Configure environment
cp .env.example .env
# Edit .env and set ANTHROPIC_API_KEY

# Run database migrations
npm run migrate

# Start development server
npm run dev
# Server runs on http://localhost:3001
```

#### 4. Start Flutter Client (Optional)

```bash
cd flutter_client
flutter pub get
flutter run
```

## Features

### Conversational GIS Queries

Ask natural language questions about geographic data:
- "What are the coordinates of San Francisco?"
- "What's the distance between NYC and LA?"
- "Find the address for these coordinates: 37.7749, -122.4194"

### Real-Time Streaming

Server-Sent Events (SSE) provide live updates:
- Tool execution progress
- LLM responses
- Geographic features extracted
- Error notifications

### Persistent History

All conversations are stored in PostgreSQL:
- Message history
- LLM interaction traces
- Tool calls and results
- Geographic features with PostGIS

### Map Visualization

Geographic features are automatically extracted and displayed on an interactive map.

## API Endpoints

### Conversations

```bash
# Create new conversation
POST /conversations
{
  "title": "My Conversation"
}

# List all conversations
GET /conversations?limit=50&offset=0

# Get conversation with full history
GET /conversations/:id

# Send message (SSE stream)
POST /conversations/:id/messages
{
  "message": "What is the distance between SF and LA?"
}
```

### Health Check

```bash
GET /health
```

## Environment Variables

Create `.env` in the root directory:

```bash
# Required
ANTHROPIC_API_KEY=sk-ant-...

# Database (defaults shown)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=magma_soup
DB_USER=postgres
DB_PASSWORD=postgres

# Servers (defaults shown)
MCP_SERVER_URL=http://localhost:3000
API_SERVER_PORT=3001
```

## Database

### Schema

**conversations**
- Stores conversation metadata
- UUID primary key
- Created/updated timestamps
- Optional title and metadata JSON

**messages**
- User and assistant messages
- References conversation
- Sequential ordering
- Content stored as JSONB

**llm_history**
- Detailed LLM interaction traces
- Tool calls, results, errors
- Sequential ordering per message
- Debugging and analysis

**geo_features**
- PostGIS geometry storage
- Extracted from tool results
- Point, Line, Polygon support
- WGS84 coordinate system (SRID 4326)

### Migrations

Migrations run automatically on startup. To run manually:

```bash
cd api_server
npm run migrate
```

Migration files are in `api_server/migrations/`:
- `001_initial_schema.sql` - Core tables
- `002_geo_features.sql` - PostGIS and spatial features

### Database Access

```bash
# Connect to database
docker exec -it magma-soup-postgis psql -U postgres -d magma_soup

# View tables
\dt

# Query conversations
SELECT * FROM conversations;

# Query with spatial data
SELECT id, feature_type, ST_AsText(geometry)
FROM geo_features;
```

## Testing

### API Server

```bash
# Create conversation
curl -X POST http://localhost:3001/conversations \
  -H "Content-Type: application/json" \
  -d '{"title": "Test"}'

# Send message (save conversation ID from above)
curl -N -X POST http://localhost:3001/conversations/<UUID>/messages \
  -H "Content-Type: application/json" \
  -d '{"message": "What are the coordinates of Tokyo?"}'

# Get conversation history
curl http://localhost:3001/conversations/<UUID>

# List all conversations
curl http://localhost:3001/conversations
```

### MCP Server

```bash
# Health check
curl http://localhost:3000/health

# List available tools
curl http://localhost:3000/tools
```

## Docker

### Individual Services

```bash
# Build specific service
docker-compose build api_server

# Rebuild without cache
docker-compose build --no-cache api_server

# View logs
docker-compose logs -f api_server

# Stop all services
docker-compose down

# Stop and remove volumes (deletes database!)
docker-compose down -v
```

### Volumes

PostgreSQL data is persisted in a Docker volume:

```bash
# List volumes
docker volume ls | grep magma

# Inspect volume
docker volume inspect magma_soup_postgis_data

# Remove volume (deletes all data!)
docker volume rm magma_soup_postgis_data
```

## Development

### Project Structure

```
magma_soup/
├── api_server/           # Node.js API server
│   ├── src/
│   │   ├── config/       # Database configuration
│   │   ├── models/       # Database models
│   │   ├── routes/       # Express routes
│   │   ├── services/     # Business logic
│   │   ├── types/        # TypeScript types
│   │   └── utils/        # Utilities
│   ├── migrations/       # SQL migrations
│   └── Dockerfile
├── mcp_server/           # MCP tool server
│   ├── src/
│   └── Dockerfile
├── flutter_client/       # Flutter desktop app
│   ├── lib/
│   └── README.md
├── context/              # Architecture docs
├── docker-compose.yml    # Full stack orchestration
├── .env.example          # Environment template
└── README.md
```

### Adding New GIS Tools

1. Implement tool in `mcp_server/src/tools/`
2. Register in `mcp_server/src/index.ts`
3. Update prompt in `api_server/src/services/gis-prompt-builder.ts`
4. Add feature extraction in `api_server/src/services/geo-feature-extractor.ts`

### Database Migrations

Create new migration:

```bash
cd api_server/migrations
touch 003_my_feature.sql
```

Write SQL schema changes, then run:

```bash
npm run migrate
```

Migrations are tracked in the `migrations` table and only run once.

## Troubleshooting

### Docker Build Issues

If you see esbuild platform errors:

```bash
# Force rebuild without cache
docker-compose build --no-cache
docker-compose up --force-recreate
```

### Database Connection Failed

```bash
# Check PostgreSQL is running
docker ps | grep postgis

# Check logs
docker logs magma-soup-postgis

# Wait for database to be ready
docker exec magma-soup-postgis pg_isready -U postgres
```

### Port Already in Use

```bash
# Check what's using the port
lsof -i :3001

# Stop the process or change PORT in .env
```

### Migration Errors

```bash
# Connect to database
docker exec -it magma-soup-postgis psql -U postgres -d magma_soup

# Check migration status
SELECT * FROM migrations;

# Manual rollback (if needed)
# DROP TABLE tablename CASCADE;
# DELETE FROM migrations WHERE filename = '001_initial_schema.sql';
```

## Contributing

See individual component READMEs for detailed development instructions:
- [API Server](api_server/README.md)
- [MCP Server](mcp_server/README.md)
- [Flutter Client](flutter_client/README.md)

## License

[Your License Here]
