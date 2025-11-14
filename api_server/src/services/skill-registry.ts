// ABOUTME: Registry for managing progressive disclosure skills
// ABOUTME: Coordinates skill activation and tool routing for conversations

import { addConversationSkill } from '../models/conversation.js';

export interface SkillTool {
  name: string;
  description: string;
  input_schema: any;
  handler: (args: any) => Promise<string>;
}

export interface Skill {
  name: string;
  documentation: string;
  tools: SkillTool[];
}

export class SkillRegistry {
  private skills = new Map<string, Skill>();

  register(skill: Skill): void {
    this.skills.set(skill.name, skill);
  }

  initialize(): void {
    // Skills are registered here as they're created
    // For now, this will be empty until we add skills
  }

  getToolsForSkills(skillNames: string[]): SkillTool[] {
    const tools: SkillTool[] = [];
    for (const name of skillNames) {
      const skill = this.skills.get(name);
      if (skill) {
        tools.push(...skill.tools);
      }
    }
    return tools;
  }

  findHandler(toolName: string): ((args: any) => Promise<string>) | undefined {
    for (const skill of this.skills.values()) {
      const tool = skill.tools.find((t) => t.name === toolName);
      if (tool) return tool.handler;
    }
    return undefined;
  }

  getActivateSkillTool(conversationId: string): SkillTool {
    const availableSkills = Array.from(this.skills.keys());
    const skillDocs = Array.from(this.skills.values())
      .map(s => `- ${s.name}: ${s.documentation}`)
      .join('\n');

    return {
      name: 'activate_skill',
      description: `Activate a skill to access additional tools.\n\nAvailable skills:\n${skillDocs}`,
      input_schema: {
        type: 'object',
        properties: {
          skill_name: {
            type: 'string',
            enum: availableSkills,
            description: 'Name of the skill to activate'
          }
        },
        required: ['skill_name']
      },
      handler: async (args: any) => {
        await addConversationSkill(conversationId, args.skill_name);
        const skill = this.skills.get(args.skill_name);

        const toolList = skill?.tools.map((t) => {
          const props = t.input_schema.properties || {};
          const params = Object.keys(props).map(key => `${key}: ${props[key].description || props[key].type}`).join(', ');
          return `  • ${t.name}(${params})`;
        }).join('\n') || 'none';

        return `Successfully activated "${args.skill_name}" skill!\n\n${skill?.documentation || ''}\n\nThe following tools are now available and can be used immediately:\n${toolList}`;
      }
    };
  }
}
