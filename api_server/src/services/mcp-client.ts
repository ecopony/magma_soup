// ABOUTME: MCP server HTTP client for tool discovery and execution
// ABOUTME: Interfaces with the GIS tools MCP server on port 3000

import Anthropic from '@anthropic-ai/sdk';

export class McpClient {
  private baseUrl: string;

  constructor(baseUrl: string = 'http://localhost:3000') {
    this.baseUrl = baseUrl;
  }

  async listTools(): Promise<any[]> {
    console.log(`Fetching tools from ${this.baseUrl}/tools/list`);

    const response = await fetch(`${this.baseUrl}/tools/list`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Failed to list tools: ${body}`);
    }

    const data = await response.json();
    const tools = data.tools || [];
    console.log(`Retrieved ${tools.length} tools: ${tools.map((t: any) => t.name).join(', ')}`);
    return tools;
  }

  async callTool(toolName: string, toolArguments: Record<string, any>): Promise<string> {
    console.log(`Calling tool: ${toolName}`);
    console.log('Arguments:', toolArguments);

    const response = await fetch(`${this.baseUrl}/tools/call`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: toolName,
        arguments: toolArguments,
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Failed to call tool: ${response.status} - ${body}`);
    }

    const data = await response.json();
    const content = data.content as any[];

    if (content.length > 0 && content[0].type === 'text') {
      const result = content[0].text as string;
      console.log('Tool result:', result);
      return result;
    }

    throw new Error('Unexpected tool response format');
  }

  async getToolsForAnthropic(): Promise<Anthropic.Tool[]> {
    const tools = await this.listTools();
    return tools.map((tool) => ({
      name: tool.name,
      description: tool.description,
      input_schema: tool.inputSchema,
    }));
  }
}
