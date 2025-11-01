// ABOUTME: API routes for conversation management and message handling
// ABOUTME: Implements SSE streaming endpoint for agentic loop execution

import { Router } from 'express';
import { AgentService } from '../services/agent.js';
import { SSEStream } from '../utils/sse.js';

const router = Router();

router.post('/:id/messages', async (req, res) => {
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

  const stream = new SSEStream(res);
  const agentService = new AgentService(anthropicApiKey, mcpServerUrl);

  try {
    const result = await agentService.executeAgenticLoop(
      message,
      (update) => {
        stream.send(update.type, update.data);
      }
    );

    // Send final response
    stream.send('done', {
      final_response: result.finalResponse,
      llm_history: result.llmHistory,
      geo_features: result.geoFeatures,
    });

    stream.end();
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    stream.send('error', { error: errorMessage });
    stream.end();
  }
});

export default router;
