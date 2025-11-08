// ABOUTME: API routes for conversation management and message handling
// ABOUTME: Implements SSE streaming endpoint for agentic loop execution

import { Router } from 'express';
import { AgentService } from '../services/agent.js';
import { SSEStream } from '../utils/sse.js';
import {
  createConversation,
  getConversation,
  listConversations,
} from '../models/conversation.js';
import { getConversationMessages } from '../models/message.js';
import { getMessageGeoFeatures } from '../models/geo-feature.js';

const router = Router();

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

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const conversation = await getConversation(id);

    if (!conversation) {
      res.status(404).json({ error: 'Conversation not found' });
      return;
    }

    const messages = await getConversationMessages(id);

    const messagesWithDetails = await Promise.all(
      messages.map(async (msg) => ({
        ...msg,
        geo_features:
          msg.type === 'assistant' ? await getMessageGeoFeatures(msg.id) : [],
      }))
    );

    res.json({
      ...conversation,
      messages: messagesWithDetails,
    });
  } catch (error) {
    console.error('Error getting conversation:', error);
    res.status(500).json({ error: 'Failed to get conversation' });
  }
});

router.post('/:id/messages', async (req, res) => {
  const { id } = req.params;
  const { message } = req.body;

  if (!message || typeof message !== 'string') {
    res.status(400).json({ error: 'Message is required and must be a string' });
    return;
  }

  const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
  const mcpServerUrl = process.env.MCP_SERVER_URL || 'http://localhost:3000';

  if (!anthropicApiKey) {
    res.status(500).json({ error: 'ANTHROPIC_API_KEY not configured' });
    return;
  }

  try {
    let conversation = await getConversation(id);
    if (!conversation) {
      conversation = await createConversation();
    }

    const stream = new SSEStream(res);
    const agentService = new AgentService(anthropicApiKey, mcpServerUrl);

    const result = await agentService.executeAgenticLoopWithPersistence(
      id,
      message,
      (update) => {
        stream.send(update.type, update.data);
      }
    );

    stream.send('done', {
      final_response: result.finalResponse,
      geo_features: result.geoFeatures,
    });

    stream.end();
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    const stream = new SSEStream(res);
    stream.send('error', { error: errorMessage });
    stream.end();
  }
});

export default router;
