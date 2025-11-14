# Skills-Based Progressive Disclosure System

**Date:** 2025-11-13
**Purpose:** Implement progressive disclosure of tools to minimize token usage while maintaining full functionality

## Problem Statement

Current token usage inefficiencies:

1. **All tools always present**: Every tool definition sent on every request
2. **No progressive disclosure**: Can't add tools mid-conversation based on need
3. **No conversation memory**: Each request starts fresh with full tool list

## Solution: Skills with Progressive Disclosure

### What is a Skill?

A skill is a simple object containing:
- **Name**: Unique identifier for the skill
- **Documentation**: Inline string describing capabilities
- **Tools**: Array of tool definitions with handlers

### Progressive Disclosure via Meta-Tool

Instead of using an intent classifier (adds latency/cost), we give Claude an `activate_skill` meta-tool that lets it request additional capabilities when needed.

**Flow:**
```
User message arrives
    ↓
Load active skills for this conversation from DB
    ↓
Build tool list: MCP tools + active skill tools + activate_skill meta-tool
    ↓
Execute agentic loop with Sonnet
    ↓
If Claude calls activate_skill:
  - Add skill to conversation's active_skills
  - Return skill documentation and available tools
    ↓
Skills persist for future messages in this conversation
```

### Example: Database Skill

```typescript
// api_server/src/skills/database.ts
import { handleRemoveFeature } from '../tools/remove-feature.js';

export const databaseSkill = {
  name: 'database',
  documentation: 'Tools for managing geographic features stored in the conversation database.',

  tools: [{
    name: 'database__remove_feature',
    description: 'Remove a geographic feature from the current conversation by its ID',
    input_schema: {
      type: 'object',
      properties: {
        feature_id: {
          type: 'string',
          description: 'ID of the feature to remove'
        }
      },
      required: ['feature_id']
    },
    handler: handleRemoveFeature
  }]
};
```

## Implementation Plan

### Phase 1: Database Migration

**File:** `api_server/migrations/004_conversation_skills.sql`

```sql
-- Add active_skills column to conversations
ALTER TABLE conversations
ADD COLUMN active_skills TEXT[] DEFAULT '{}';

-- Index for querying conversations by skill
CREATE INDEX idx_conversations_active_skills ON conversations USING GIN(active_skills);
```

### Phase 2: Conversation Model Functions

**File:** `api_server/src/models/conversation.ts`

Add skill management functions:

```typescript
export async function getConversationSkills(id: string): Promise<string[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT active_skills FROM conversations WHERE id = $1',
    [id]
  );
  return result.rows[0]?.active_skills || [];
}

export async function addConversationSkill(
  id: string,
  skillName: string
): Promise<void> {
  const pool = getPool();
  await pool.query(
    `UPDATE conversations
     SET active_skills = array_append(active_skills, $2)
     WHERE id = $1 AND NOT ($2 = ANY(active_skills))`,
    [id, skillName]
  );
}
```

### Phase 3: Skill Registry

**File:** `api_server/src/services/skill-registry.ts` (NEW)

Simple registry for managing skills:

```typescript
import { databaseSkill } from '../skills/database.js';
import { addConversationSkill } from '../models/conversation.js';

export class SkillRegistry {
  private skills = new Map<string, any>();

  register(skill: any) {
    this.skills.set(skill.name, skill);
  }

  initialize() {
    this.register(databaseSkill);
    // Register other skills here as they're created
  }

  getToolsForSkills(skillNames: string[]) {
    const tools = [];
    for (const name of skillNames) {
      const skill = this.skills.get(name);
      if (skill) {
        tools.push(...skill.tools);
      }
    }
    return tools;
  }

  findHandler(toolName: string) {
    for (const skill of this.skills.values()) {
      const tool = skill.tools.find((t: any) => t.name === toolName);
      if (tool) return tool.handler;
    }
    return undefined;
  }

  getActivateSkillTool(conversationId: string) {
    const availableSkills = Array.from(this.skills.keys());

    return {
      name: 'activate_skill',
      description: `Activate a skill to access additional tools. Available skills: ${availableSkills.join(', ')}`,
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

        const toolNames = skill?.tools.map((t: any) => t.name).join(', ') || 'none';
        return `Activated "${args.skill_name}" skill. ${skill?.documentation || ''}\n\nAvailable tools: ${toolNames}`;
      }
    };
  }
}
```

### Phase 4: Create Database Skill

**File:** `api_server/src/skills/database.ts` (NEW)

Move `remove_map_feature` from local tools to a skill:

```typescript
import { handleRemoveFeature } from '../tools/remove-feature.js';

export const databaseSkill = {
  name: 'database',
  documentation: 'Tools for managing geographic features stored in the conversation database.',

  tools: [{
    name: 'database__remove_feature',
    description: 'Remove a geographic feature from the current conversation by its ID',
    input_schema: {
      type: 'object',
      properties: {
        feature_id: {
          type: 'string',
          description: 'ID of the feature to remove'
        }
      },
      required: ['feature_id']
    },
    handler: handleRemoveFeature
  }]
};
```

### Phase 5: Update Agent Service

**File:** `api_server/src/services/agent.ts`

Update `executeAgenticLoopWithPersistence` to load skills:

```typescript
import { SkillRegistry } from './skill-registry.js';
import { getConversationSkills } from '../models/conversation.js';

export class AgentService {
  private anthropicService: AnthropicService;
  private mcpClient: McpClient;
  private skillRegistry: SkillRegistry;
  private geoFeatureExtractor: GeoFeatureExtractor;
  private maxToolCalls = 10;

  constructor(anthropicApiKey: string, mcpServerUrl: string) {
    this.anthropicService = new AnthropicService(anthropicApiKey);
    this.mcpClient = new McpClient(mcpServerUrl);
    this.skillRegistry = new SkillRegistry();
    this.skillRegistry.initialize();
    this.geoFeatureExtractor = new GeoFeatureExtractor();
  }

  async executeAgenticLoopWithPersistence(
    conversationId: string,
    userMessage: string,
    onProgress?: (update: StreamUpdate) => void
  ): Promise<AgenticLoopResult> {
    // ... existing code to load conversation context ...

    // Load active skills for this conversation
    const activeSkills = await getConversationSkills(conversationId);

    // Get MCP tools (geospatial tools - keep these for now)
    const mcpTools = await this.mcpClient.getToolsForAnthropic();

    // Get skill tools (only active ones)
    const skillTools = this.skillRegistry.getToolsForSkills(activeSkills);

    // Add the activate_skill meta-tool
    const activateSkillTool = this.skillRegistry.getActivateSkillTool(conversationId);

    // Merge all tools
    const tools = [...mcpTools, ...skillTools, activateSkillTool];

    // ... rest of existing code ...
  }
}
```

Update tool dispatch in `executeAgenticLoop`:

```typescript
// In the tool execution loop:
let result: string;

// Check skills first
const skillHandler = this.skillRegistry.findHandler(toolName);
if (skillHandler) {
  result = await skillHandler(toolInput);
} else if (toolName === 'activate_skill') {
  const activateSkillTool = this.skillRegistry.getActivateSkillTool(conversationId);
  result = await activateSkillTool.handler(toolInput);
} else if (this.localTools.has(toolName)) {
  // Keep local tools as fallback during migration
  result = await this.localTools.get(toolName).handler(toolInput);
} else {
  // Fall back to MCP
  result = await this.mcpClient.callTool(toolName, toolInput);
}
```

### Phase 6: Remove Local Tools Map

Once database skill is working, remove the `localTools` Map and the old `remove-feature.ts` tool registration:

```typescript
// Remove this from constructor:
private localTools = new Map<string, any>([
  [removeFeatureTool.name, { definition: removeFeatureTool, handler: handleRemoveFeature }],
]);

// Remove this import:
import {
  removeFeatureTool,
  handleRemoveFeature,
} from "../tools/remove-feature.js";

// Remove the localTools check from tool dispatch
```

## Demo Flow: Side-by-Side MCP and Skills

**Message 1:** "What's the distance from SF to LA?"
- Active skills: []
- Tools sent:
  - MCP: `geocode_address`, `calculate_distance`, `find_points_in_radius`, `calculate_area`
  - Skills: (none)
  - Meta: `activate_skill`
- Claude uses MCP tools directly (no skill activation needed)

**Message 2:** "Remove the first feature"
- Active skills: []
- Tools sent:
  - MCP: (all 4 geospatial tools)
  - Skills: (none)
  - Meta: `activate_skill`
- Claude: *calls `activate_skill('database')`*
- System: Adds 'database' to active_skills
- Claude: *calls `database__remove_feature`*

**Message 3:** "Add a marker in Chicago"
- Active skills: ['database']
- Tools sent:
  - MCP: (all 4 geospatial tools)
  - Skills: `database__remove_feature`
  - Meta: `activate_skill`
- Claude can now use database tools without activation

This demonstrates:
- ✅ MCP tools (geospatial) work as before
- ✅ Skills (database) use progressive disclosure
- ✅ Both patterns coexist peacefully
- ✅ Token savings when database skill not needed

## Migration Strategy

### Step 1: Add skills system alongside MCP (this plan)
- Implement skill registry
- Create database skill with `remove_feature`
- Keep all MCP tools working
- Keep local tools map during transition

### Step 2: Move more tools to skills (future)
- Create geospatial skill
- Move MCP tools to local skills
- More token savings with progressive disclosure

### Step 3: Remove MCP infrastructure (future)
- Delete MCP client
- Delete MCP server
- Remove from docker-compose

## Benefits

1. **Progressive disclosure**: Only load database tools when needed
2. **Token efficiency**: ~200 tokens saved on messages that don't need database operations
3. **Conversation memory**: Skills persist across messages
4. **Simple implementation**: ~150 lines of new code
5. **No breaking changes**: MCP tools continue to work
6. **No latency overhead**: No Haiku classification calls

## Success Criteria

- [ ] Database migration adds `active_skills` to conversations
- [ ] SkillRegistry created and initialized
- [ ] Database skill created with `remove_feature` tool
- [ ] AgentService loads and merges skill tools
- [ ] `activate_skill` meta-tool works
- [ ] Skills persist across conversation
- [ ] MCP tools continue to work unchanged
- [ ] Token usage reduced on non-database messages
- [ ] Local tools map can be removed

## Token Usage Comparison

### Before (all tools always present)

```
System prompt: 500 tokens
MCP tool definitions: 800 tokens
Local tool definitions: 200 tokens
User message: 100 tokens
---
Total per request: 1,600 tokens
```

### After (with progressive disclosure)

```
First message (no database operations needed):
  System prompt: 500 tokens
  MCP tools: 800 tokens
  activate_skill: 50 tokens
  User message: 100 tokens
  ---
  Total: 1,450 tokens (-150 tokens, ~9% savings)

Second message (after activating database skill):
  System prompt: 500 tokens
  MCP tools: 800 tokens
  Database skill tools: 200 tokens
  activate_skill: 50 tokens
  User message: 100 tokens
  ---
  Total: 1,650 tokens
```

**Savings**: ~9% token reduction on messages that don't need database operations. As more skills are added and progressively disclosed, savings increase proportionally.
