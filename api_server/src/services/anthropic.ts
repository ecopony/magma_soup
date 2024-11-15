// ABOUTME: Anthropic API client for Claude interactions
// ABOUTME: Handles message sending, tool use extraction, and response parsing

import Anthropic from '@anthropic-ai/sdk';
import type { Message, ToolUse } from '../types/index.js';

export class AnthropicService {
  private client: Anthropic;
  private model = 'claude-sonnet-4-5-20250929';
  private maxTokens = 4096;

  constructor(apiKey: string) {
    if (!apiKey) {
      throw new Error('Anthropic API key not configured');
    }
    this.client = new Anthropic({ apiKey });
  }

  async sendMessage(options: {
    prompt?: string;
    tools?: Anthropic.Tool[];
    conversationHistory?: Message[];
  }): Promise<any> {
    const { prompt, tools, conversationHistory } = options;

    if (!conversationHistory && (!prompt || prompt.trim().length === 0)) {
      throw new Error('Either prompt or conversationHistory must be provided');
    }

    const messages = conversationHistory ?? [
      {
        role: 'user' as const,
        content: prompt!,
      },
    ];

    const requestParams: any = {
      model: this.model,
      max_tokens: this.maxTokens,
      messages,
    };

    if (tools && tools.length > 0) {
      requestParams.tools = tools;
    }

    const response = await this.client.messages.create(requestParams);

    return response;
  }

  extractTextResponse(response: any): string {
    const content = response.content;
    if (!content || content.length === 0) {
      return '';
    }

    const textParts = content.filter((c: any) => c.type === 'text');
    return textParts.map((c: any) => c.text || '').join('\n');
  }

  extractToolUses(response: any): ToolUse[] {
    const content = response.content;
    if (!content || content.length === 0) {
      return [];
    }

    return content
      .filter((c: any) => c.type === 'tool_use')
      .map((c: any) => ({
        id: c.id,
        name: c.name,
        input: c.input,
      }));
  }
}
