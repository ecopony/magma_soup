// ABOUTME: Main entry point for the API server
// ABOUTME: Configures Express app with routes and middleware

import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import conversationRoutes from './routes/conversations.js';

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
  console.log(`MCP Server URL: ${process.env.MCP_SERVER_URL || 'http://localhost:3000'}`);
});
