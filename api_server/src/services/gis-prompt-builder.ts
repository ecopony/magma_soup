// ABOUTME: GIS-specific prompt builder for adding context to user commands
// ABOUTME: Constructs system prompts with optional spatial context

export class GisPromptBuilder {
  private static systemContext = `You are a GIS (Geographic Information Systems) processing assistant. You help users with geospatial data analysis, manipulation, and transformation tasks.`;

  static buildPrompt(userCommand: string): string {
    return `${this.systemContext}

User request: ${userCommand}

Attempt to complete the user's request. If you lack the tools to do so, let the user know.`;
  }
}
