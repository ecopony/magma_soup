// ABOUTME: Server-Sent Events (SSE) streaming utility
// ABOUTME: Handles SSE response formatting and event transmission

import type { Response } from 'express';

export class SSEStream {
  constructor(private res: Response) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();
  }

  send(event: string, data: any): void {
    this.res.write(`event: ${event}\n`);
    this.res.write(`data: ${JSON.stringify(data)}\n\n`);
  }

  end(): void {
    this.res.end();
  }
}
