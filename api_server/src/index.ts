// ABOUTME: Main entry point for the API server
// ABOUTME: Configures Express app with routes and middleware

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
    const pool = getPool();
    await pool.query('SELECT NOW()');
    console.log('✓ Database connected');

    if (process.env.AUTO_MIGRATE !== 'false') {
      await runMigrations();
    }

    app.listen(PORT, () => {
      console.log(`✓ API Server running on http://localhost:${PORT}`);
      console.log(`MCP Server URL: ${process.env.MCP_SERVER_URL || 'http://localhost:3000'}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

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
