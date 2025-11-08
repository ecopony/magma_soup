# Phase 2: Database Layer - PostGIS Integration

## Overview
Add conversation persistence using PostgreSQL with PostGIS extension. Store conversation history, messages, and optionally geographic features extracted from tool results.

---

## Step 1: Database Schema Design

### 1.1 Core Tables

**conversations**
```sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  title TEXT,  -- Optional: first message or summary
  metadata JSONB  -- Optional: user preferences, settings, etc.
);

CREATE INDEX idx_conversations_created ON conversations(created_at DESC);
```

**messages**
```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content JSONB NOT NULL,  -- Store structured content blocks
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  sequence_number INTEGER NOT NULL,  -- Order within conversation
  metadata JSONB  -- Optional: token count, model version, etc.
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, sequence_number);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
```

**llm_history**
```sql
CREATE TABLE llm_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL CHECK (entry_type IN (
    'user_prompt', 'llm_response', 'tool_call', 'tool_result', 'tool_error'
  )),
  sequence_number INTEGER NOT NULL,  -- Order within message
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  content JSONB NOT NULL,  -- Structured content (tool name, args, result, etc.)
  stop_reason TEXT,  -- For llm_response entries
  tool_name TEXT,  -- For tool_call/tool_result/tool_error entries
  UNIQUE(message_id, sequence_number)
);

CREATE INDEX idx_llm_history_message ON llm_history(message_id, sequence_number);
```

### 1.2 Geographic Features Table (Optional Enhancement)

**geo_features**
```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE geo_features (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  feature_type TEXT NOT NULL CHECK (feature_type IN ('marker', 'line', 'polygon')),
  geometry GEOMETRY(Geometry, 4326),  -- WGS84, accepts Point, LineString, Polygon
  properties JSONB,  -- label, color, description, etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_geo_features_message ON geo_features(message_id);
CREATE INDEX idx_geo_features_geometry ON geo_features USING GIST(geometry);
```

### 1.3 Migration Files

Create `api_server/migrations/` directory with versioned SQL files:
- `001_initial_schema.sql` - conversations, messages, llm_history tables
- `002_geo_features.sql` - PostGIS extension and geo_features table

---

## Step 2: Database Connection & Models

### 2.1 Install Database Dependencies

```bash
cd api_server
npm install pg
npm install -D @types/pg
```

**Optional**: Consider using a query builder or ORM:
- `kysely` - Type-safe SQL query builder (lightweight, recommended)
- `drizzle-orm` - Type-safe ORM (more features)
- Or stay with raw `pg` for simplicity

### 2.2 Database Configuration (`src/config/database.ts`)

```typescript
import pg from 'pg';

const { Pool } = pg;

export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

export function getDatabaseConfig(): DatabaseConfig {
  return {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'magma_soup',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres'
  };
}

let pool: pg.Pool | null = null;

export function getPool(): pg.Pool {
  if (!pool) {
    pool = new Pool(getDatabaseConfig());

    pool.on('error', (err) => {
      console.error('Unexpected database error:', err);
    });
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
```

### 2.3 Database Models (`src/models/`)

Create TypeScript interfaces and database access functions:

**`src/models/conversation.ts`**
```typescript
import { getPool } from '../config/database.js';

export interface Conversation {
  id: string;
  created_at: Date;
  updated_at: Date;
  title?: string;
  metadata?: Record<string, any>;
}

export async function createConversation(
  title?: string,
  metadata?: Record<string, any>
): Promise<Conversation> {
  const pool = getPool();
  const result = await pool.query(
    `INSERT INTO conversations (title, metadata)
     VALUES ($1, $2)
     RETURNING *`,
    [title, metadata ? JSON.stringify(metadata) : null]
  );
  return result.rows[0];
}

export async function getConversation(id: string): Promise<Conversation | null> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM conversations WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}

export async function updateConversationTimestamp(id: string): Promise<void> {
  const pool = getPool();
  await pool.query(
    'UPDATE conversations SET updated_at = NOW() WHERE id = $1',
    [id]
  );
}

export async function listConversations(
  limit: number = 50,
  offset: number = 0
): Promise<Conversation[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM conversations ORDER BY updated_at DESC LIMIT $1 OFFSET $2',
    [limit, offset]
  );
  return result.rows;
}
```

**`src/models/message.ts`**
```typescript
import { getPool } from '../config/database.js';
import type { Message as MessageContent } from '../types/index.js';

export interface StoredMessage {
  id: string;
  conversation_id: string;
  role: 'user' | 'assistant';
  content: MessageContent['content'];
  created_at: Date;
  sequence_number: number;
  metadata?: Record<string, any>;
}

export async function createMessage(
  conversationId: string,
  role: 'user' | 'assistant',
  content: MessageContent['content'],
  metadata?: Record<string, any>
): Promise<StoredMessage> {
  const pool = getPool();

  // Get next sequence number
  const seqResult = await pool.query(
    'SELECT COALESCE(MAX(sequence_number), 0) + 1 as next_seq FROM messages WHERE conversation_id = $1',
    [conversationId]
  );
  const sequenceNumber = seqResult.rows[0].next_seq;

  const result = await pool.query(
    `INSERT INTO messages (conversation_id, role, content, sequence_number, metadata)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [conversationId, role, JSON.stringify(content), sequenceNumber, metadata ? JSON.stringify(metadata) : null]
  );

  return result.rows[0];
}

export async function getConversationMessages(
  conversationId: string
): Promise<StoredMessage[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM messages WHERE conversation_id = $1 ORDER BY sequence_number ASC',
    [conversationId]
  );
  return result.rows;
}

export async function getMessage(id: string): Promise<StoredMessage | null> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM messages WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}
```

**`src/models/llm-history.ts`**
```typescript
import { getPool } from '../config/database.js';
import type { LLMHistoryEntry } from '../types/index.js';

export interface StoredLLMHistoryEntry {
  id: string;
  message_id: string;
  entry_type: LLMHistoryEntry['type'];
  sequence_number: number;
  timestamp: Date;
  content: Record<string, any>;
  stop_reason?: string;
  tool_name?: string;
}

export async function createLLMHistoryEntry(
  messageId: string,
  entry: LLMHistoryEntry,
  sequenceNumber: number
): Promise<StoredLLMHistoryEntry> {
  const pool = getPool();
  const result = await pool.query(
    `INSERT INTO llm_history (
      message_id, entry_type, sequence_number, timestamp, content, stop_reason, tool_name
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *`,
    [
      messageId,
      entry.type,
      sequenceNumber,
      entry.timestamp,
      JSON.stringify(entry.content || {}),
      entry.stop_reason || null,
      entry.tool_name || null
    ]
  );
  return result.rows[0];
}

export async function getMessageLLMHistory(
  messageId: string
): Promise<StoredLLMHistoryEntry[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM llm_history WHERE message_id = $1 ORDER BY sequence_number ASC',
    [messageId]
  );
  return result.rows;
}
```

**`src/models/geo-feature.ts`** (Optional)
```typescript
import { getPool } from '../config/database.js';
import type { GeoFeature } from '../types/index.js';

export interface StoredGeoFeature {
  id: string;
  message_id: string;
  feature_type: string;
  geometry: any;  // PostGIS geometry object
  properties: Record<string, any>;
  created_at: Date;
}

export async function createGeoFeature(
  messageId: string,
  feature: GeoFeature
): Promise<StoredGeoFeature> {
  const pool = getPool();

  // Convert lat/lon to PostGIS Point geometry
  const result = await pool.query(
    `INSERT INTO geo_features (message_id, feature_type, geometry, properties)
     VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326), $5)
     RETURNING id, message_id, feature_type,
               ST_AsGeoJSON(geometry)::json as geometry,
               properties, created_at`,
    [messageId, feature.type, feature.lon, feature.lat, JSON.stringify({ label: feature.label })]
  );

  return result.rows[0];
}

export async function getMessageGeoFeatures(
  messageId: string
): Promise<StoredGeoFeature[]> {
  const pool = getPool();
  const result = await pool.query(
    `SELECT id, message_id, feature_type,
            ST_AsGeoJSON(geometry)::json as geometry,
            properties, created_at
     FROM geo_features
     WHERE message_id = $1`,
    [messageId]
  );
  return result.rows;
}
```

---

## Step 3: Update Agent Service to Persist Data

### 3.1 Modify `src/services/agent.ts`

Add database persistence to the agentic loop:

```typescript
import { createMessage, createLLMHistoryEntry } from '../models/message.js';
import { createGeoFeature } from '../models/geo-feature.js';
import { updateConversationTimestamp } from '../models/conversation.js';

// In executeAgenticLoop function, add these calls:

async function executeAgenticLoop(
  conversationId: string,
  userMessage: string,
  onProgress?: (update: StreamUpdate) => void
): Promise<AgenticLoopResult> {

  // 1. Store user message
  const userMessageRecord = await createMessage(
    conversationId,
    'user',
    userMessage
  );

  // ... existing agentic loop logic ...

  // 2. Store each LLM history entry as it happens
  for (let i = 0; i < llmHistory.length; i++) {
    await createLLMHistoryEntry(userMessageRecord.id, llmHistory[i], i);
  }

  // 3. Store assistant response
  const assistantMessageRecord = await createMessage(
    conversationId,
    'assistant',
    finalResponse
  );

  // 4. Store geographic features
  for (const feature of geoFeatures) {
    await createGeoFeature(assistantMessageRecord.id, feature);
  }

  // 5. Update conversation timestamp
  await updateConversationTimestamp(conversationId);

  return {
    finalResponse,
    llmHistory,
    geoFeatures
  };
}
```

---

## Step 4: Update API Routes

### 4.1 Add Conversation Management Endpoints

**`src/routes/conversations.ts`**

Add these endpoints:

```typescript
// POST /conversations - Create new conversation
router.post('/', async (req, res) => {
  try {
    const { title } = req.body;
    const conversation = await createConversation(title);
    res.json(conversation);
  } catch (error) {
    console.error('Error creating conversation:', error);
    res.status(500).json({ error: 'Failed to create conversation' });
  }
});

// GET /conversations - List conversations
router.get('/', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;
    const conversations = await listConversations(limit, offset);
    res.json(conversations);
  } catch (error) {
    console.error('Error listing conversations:', error);
    res.status(500).json({ error: 'Failed to list conversations' });
  }
});

// GET /conversations/:id - Get conversation with messages
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const conversation = await getConversation(id);

    if (!conversation) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    const messages = await getConversationMessages(id);

    // Optionally fetch LLM history and geo features for each message
    const messagesWithDetails = await Promise.all(
      messages.map(async (msg) => ({
        ...msg,
        llm_history: await getMessageLLMHistory(msg.id),
        geo_features: await getMessageGeoFeatures(msg.id)
      }))
    );

    res.json({
      ...conversation,
      messages: messagesWithDetails
    });
  } catch (error) {
    console.error('Error getting conversation:', error);
    res.status(500).json({ error: 'Failed to get conversation' });
  }
});

// POST /conversations/:id/messages - Send message (existing SSE endpoint)
// Update to validate conversation exists before processing
router.post('/:id/messages', async (req, res) => {
  const { id } = req.params;

  // Validate conversation exists (or create if needed)
  let conversation = await getConversation(id);
  if (!conversation) {
    // Auto-create conversation if it doesn't exist
    conversation = await createConversation();
    // OR return 404 if strict validation preferred
    // return res.status(404).json({ error: 'Conversation not found' });
  }

  // ... existing SSE streaming logic ...
});
```

---

## Step 5: Database Migration System

### 5.1 Migration Runner (`src/utils/migrate.ts`)

```typescript
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { getPool } from '../config/database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function runMigrations() {
  const pool = getPool();

  // Create migrations tracking table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  `);

  // Get applied migrations
  const appliedResult = await pool.query(
    'SELECT filename FROM migrations ORDER BY id'
  );
  const applied = new Set(appliedResult.rows.map(r => r.filename));

  // Read migration files
  const migrationsDir = path.join(__dirname, '../../migrations');
  const files = await fs.readdir(migrationsDir);
  const sqlFiles = files.filter(f => f.endsWith('.sql')).sort();

  // Apply pending migrations
  for (const filename of sqlFiles) {
    if (applied.has(filename)) {
      console.log(`✓ ${filename} (already applied)`);
      continue;
    }

    console.log(`Applying ${filename}...`);
    const sql = await fs.readFile(path.join(migrationsDir, filename), 'utf-8');

    try {
      await pool.query('BEGIN');
      await pool.query(sql);
      await pool.query('INSERT INTO migrations (filename) VALUES ($1)', [filename]);
      await pool.query('COMMIT');
      console.log(`✓ ${filename} applied`);
    } catch (error) {
      await pool.query('ROLLBACK');
      console.error(`✗ ${filename} failed:`, error);
      throw error;
    }
  }

  console.log('All migrations completed');
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Migration failed:', err);
      process.exit(1);
    });
}

export { runMigrations };
```

### 5.2 Migration Files

**`api_server/migrations/001_initial_schema.sql`**
```sql
-- Conversations table
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  title TEXT,
  metadata JSONB
);

CREATE INDEX idx_conversations_created ON conversations(created_at DESC);

-- Messages table
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  sequence_number INTEGER NOT NULL,
  metadata JSONB
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, sequence_number);
CREATE INDEX idx_messages_created ON messages(created_at DESC);

-- LLM history table
CREATE TABLE llm_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL CHECK (entry_type IN (
    'user_prompt', 'llm_response', 'tool_call', 'tool_result', 'tool_error'
  )),
  sequence_number INTEGER NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  content JSONB NOT NULL,
  stop_reason TEXT,
  tool_name TEXT,
  UNIQUE(message_id, sequence_number)
);

CREATE INDEX idx_llm_history_message ON llm_history(message_id, sequence_number);
```

**`api_server/migrations/002_geo_features.sql`**
```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Geographic features table
CREATE TABLE geo_features (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  feature_type TEXT NOT NULL CHECK (feature_type IN ('marker', 'line', 'polygon')),
  geometry GEOMETRY(Geometry, 4326),
  properties JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_geo_features_message ON geo_features(message_id);
CREATE INDEX idx_geo_features_geometry ON geo_features USING GIST(geometry);
```

### 5.3 Add Migration Script to package.json

```json
{
  "scripts": {
    "migrate": "tsx src/utils/migrate.ts"
  }
}
```

---

## Step 6: PostgreSQL Docker Setup

### 6.1 Create PostGIS Service

Add to project root `docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgis:
    image: postgis/postgis:15-3.4
    container_name: magma-soup-postgis
    environment:
      POSTGRES_DB: magma_soup
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgis_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  mcp_server:
    build:
      context: ./mcp_server
      dockerfile: Dockerfile
    container_name: magma-soup-mcp-server
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  api_server:
    build:
      context: ./api_server
      dockerfile: Dockerfile
    container_name: magma-soup-api-server
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - PORT=3001
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - MCP_SERVER_URL=http://mcp_server:3000
      - DB_HOST=postgis
      - DB_PORT=5432
      - DB_NAME=magma_soup
      - DB_USER=postgres
      - DB_PASSWORD=postgres
    depends_on:
      postgis:
        condition: service_healthy
      mcp_server:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgis_data:
```

### 6.2 Update API Server Dockerfile

Create `api_server/Dockerfile`:

```dockerfile
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source
COPY . .

# Build TypeScript
RUN npm run build

# Run migrations on startup (or create separate init script)
CMD ["sh", "-c", "npm run migrate && npm start"]
```

### 6.3 Environment Configuration

**`.env.example`** (root directory):
```
ANTHROPIC_API_KEY=sk-ant-...

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=magma_soup
DB_USER=postgres
DB_PASSWORD=postgres

# Servers
MCP_SERVER_URL=http://localhost:3000
API_SERVER_PORT=3001
```

---

## Step 7: Testing

### 7.1 Local Testing (Without Docker)

1. **Start PostgreSQL with PostGIS:**
```bash
docker run -d \
  --name magma-postgis \
  -e POSTGRES_DB=magma_soup \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgis/postgis:15-3.4
```

2. **Run migrations:**
```bash
cd api_server
npm run migrate
```

3. **Start development server:**
```bash
npm run dev
```

### 7.2 Test Scenarios

**1. Create conversation:**
```bash
curl -X POST http://localhost:3001/conversations \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Conversation"}'
```

**2. Send message (stores to database):**
```bash
curl -N -X POST http://localhost:3001/conversations/<UUID>/messages \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the distance between NYC and LA?"}'
```

**3. Retrieve conversation history:**
```bash
curl http://localhost:3001/conversations/<UUID>
```

**4. List all conversations:**
```bash
curl http://localhost:3001/conversations
```

### 7.3 Database Verification

Connect to PostgreSQL and verify data:

```bash
docker exec -it magma-postgis psql -U postgres -d magma_soup

# Check conversations
SELECT * FROM conversations;

# Check messages
SELECT id, conversation_id, role, created_at FROM messages;

# Check LLM history
SELECT entry_type, tool_name, timestamp FROM llm_history;

# Check geo features (if implemented)
SELECT id, feature_type, ST_AsText(geometry) as location FROM geo_features;
```

### 7.4 Full Stack Testing with Docker Compose

```bash
# Build and start all services
docker-compose up --build

# Check service health
docker-compose ps

# View logs
docker-compose logs -f api_server

# Test endpoints (use same curl commands as above)

# Shutdown
docker-compose down
```

---

## Step 8: API Server Startup Integration

### 8.1 Update `src/index.ts`

Add database initialization and graceful shutdown:

```typescript
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import conversationRoutes from './routes/conversations.js';
import { getPool, closePool } from './config/database.js';
import { runMigrations } from './utils/migrate.js';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/conversations', conversationRoutes);
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'api-server' });
});

const PORT = process.env.PORT || 3001;

async function start() {
  try {
    // Test database connection
    const pool = getPool();
    await pool.query('SELECT NOW()');
    console.log('✓ Database connected');

    // Run migrations
    if (process.env.AUTO_MIGRATE !== 'false') {
      await runMigrations();
    }

    // Start server
    app.listen(PORT, () => {
      console.log(`✓ API Server running on http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await closePool();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await closePool();
  process.exit(0);
});

start();
```

---

## Success Criteria

Phase 2 is complete when:

1. ✅ PostgreSQL with PostGIS running in Docker container
2. ✅ Database schema created via migrations
3. ✅ Conversations can be created and retrieved
4. ✅ Messages stored with proper sequencing
5. ✅ LLM history entries persisted for each interaction
6. ✅ Geographic features stored (if implemented)
7. ✅ API endpoints return conversation history from database
8. ✅ Agentic loop integrated with database persistence
9. ✅ Migration system runs automatically on startup
10. ✅ Full docker-compose stack works (postgis + mcp_server + api_server)
11. ✅ Database survives container restarts (volume persistence)
12. ✅ Error handling for database operations
13. ✅ Graceful shutdown closes database connections

---

## Optional Enhancements

### Future Improvements (Not in Phase 2 scope)

1. **Query optimization**: Add database indexes for common queries
2. **Soft deletes**: Add `deleted_at` column for conversation archival
3. **Search**: Full-text search on message content
4. **Spatial queries**: Find nearby features, calculate areas, etc.
5. **Message attachments**: Store images, files referenced in conversations
6. **User management**: Add users table and associate conversations with users
7. **Rate limiting**: Track and limit API usage per user
8. **Backup system**: Automated database backups
9. **Connection pooling optimization**: Tune pool size for production
10. **Read replicas**: Scale read queries separately

---

## Files Created/Modified

**New files:**
- `api_server/src/config/database.ts`
- `api_server/src/models/conversation.ts`
- `api_server/src/models/message.ts`
- `api_server/src/models/llm-history.ts`
- `api_server/src/models/geo-feature.ts` (optional)
- `api_server/src/utils/migrate.ts`
- `api_server/migrations/001_initial_schema.sql`
- `api_server/migrations/002_geo_features.sql`
- `api_server/Dockerfile`
- `docker-compose.yml` (root)
- `.env.example` (root)

**Modified files:**
- `api_server/package.json` - Add pg dependency and migrate script
- `api_server/src/index.ts` - Add database initialization and graceful shutdown
- `api_server/src/services/agent.ts` - Add database persistence calls
- `api_server/src/routes/conversations.ts` - Add conversation management endpoints

---

## Timeline Estimate

- **Step 1-2** (Schema & Models): 2-3 hours
- **Step 3** (Agent Integration): 1-2 hours
- **Step 4** (API Routes): 1 hour
- **Step 5** (Migrations): 1-2 hours
- **Step 6** (Docker Setup): 1-2 hours
- **Step 7-8** (Testing & Integration): 2-3 hours

**Total**: 8-13 hours of development time
