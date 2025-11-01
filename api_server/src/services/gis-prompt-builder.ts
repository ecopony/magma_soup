// ABOUTME: GIS-specific prompt builder for adding context to user commands
// ABOUTME: Constructs system prompts with optional spatial context

export class GisPromptBuilder {
  private static systemContext = `You are a GIS (Geographic Information Systems) processing assistant. You help users with geospatial data analysis, manipulation, and transformation tasks.`;

  static buildPrompt(userCommand: string): string {
    return `${this.systemContext}

User request: ${userCommand}

Attempt to complete the user's request. If you lack the tools to do so, let the user know.`;
  }

  static buildPromptWithContext(options: {
    userCommand: string;
    currentCrs?: string;
    dataFormat?: string;
    previousCommands?: string[];
  }): string {
    const { userCommand, currentCrs, dataFormat, previousCommands } = options;
    const contextParts: string[] = [];

    if (currentCrs) {
      contextParts.push(`Current CRS: ${currentCrs}`);
    }

    if (dataFormat) {
      contextParts.push(`Current data format: ${dataFormat}`);
    }

    if (previousCommands && previousCommands.length > 0) {
      contextParts.push(`Previous commands:\n${previousCommands.join('\n')}`);
    }

    const additionalContext =
      contextParts.length === 0
        ? ''
        : `\n\nContext:\n${contextParts.join('\n')}\n`;

    return `${this.systemContext}${additionalContext}

User request: ${userCommand}

Please provide a detailed response with specific GIS processing steps, commands, or code as appropriate.`;
  }
}
