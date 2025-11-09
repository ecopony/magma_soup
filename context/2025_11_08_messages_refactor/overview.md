# Proposed Schema

```
  CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
      'user', 'assistant', 'user_prompt', 'llm_response',
      'tool_call', 'tool_result', 'tool_error'
    )),
    sequence_number INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    content JSONB NOT NULL,

    UNIQUE(conversation_id, sequence_number)
  );
```

# Content shapes by type

- user: {"text": "what's the distance..."}
- assistant: {"text": "The distance is 559 km"}
- user_prompt: {"prompt": "You are a GIS assistant...\n\nUser request: what's..."}
- llm_response: {"content": [...], "stop_reason": "tool_use"}
- tool_call: {"tool_use_id": "toolu_123", "tool_name": "geocode", "arguments": {...}}
- tool_result: {"tool_use_id": "toolu_123", "tool_name": "geocode", "result": "..."}
- tool_error: {"tool_use_id": "toolu_123", "tool_name": "geocode", "error": "..."}

# Benefits

- Conversation history query: SELECT \* FROM messages WHERE conversation_id = ? AND type IN ('user', 'assistant') ORDER BY sequence_number
- Full interaction view: SELECT \* FROM messages WHERE conversation_id = ? ORDER BY sequence_number
- Simple, clean, one source of truth

# Complete Implementation Plan

## Database Layer

1. Migration (api_server/migrations/003_unify_messages.sql)

- Create new unified messages table with type discriminator
- Don't worry about migrating data
- Drop old llm_history table
- Keep constraint on conversation_id + sequence_number uniqueness

## API Server Changes

2. Models (api_server/src/models/message.ts)

- Update to handle all message types with JSONB content
- Remove separate llm-history.ts model
- Add helper functions to filter by type

3. Agent Service (api_server/src/services/agent.ts)

- executeAgenticLoopWithPersistence: Load previous user/assistant messages from DB
- executeAgenticLoop: Accept optional conversation history parameter
- Write all interactions (user_prompt, llm_response, tool_call, tool_result, tool_error) as messages in sequence
- IMPORTANT: Preserve tool_use_id when storing tool_call, tool_result, and tool_error messages
- Pass conversation history to AnthropicService

4. Anthropic Service (api_server/src/services/anthropic.ts)

- Update sendMessage to accept and use full conversation history
- Build proper message array for Anthropic API

5. API Routes (api_server/src/routes/conversations.ts)

- GET /conversations/:id: Return all messages (caller filters by type)
- POST /conversations/:id/messages: Stream all message types as SSE events
- Remove llm_history field from done event (streamed in real-time instead)

6. SSE Streaming (api_server/src/utils/sse.ts)

- Add event types for user_prompt if not already streaming
- Ensure all interaction types stream as they occur

## Flutter Client Changes

7. Models (flutter_client/lib/models/)

- Keep existing SSE event types (they map to message types)
- Update DoneEvent to remove llmHistory field (no longer needed)
- Consider: unified Interaction model that represents any message type

8. BLoC Simplification (flutter_client/lib/bloc/)

- Remove AgenticTraceBloc entirely
- Update ChatBloc to:
  - Store ALL messages (all types) in state
  - Handle all SSE event types by appending to message list
  - Filter messages by type for different views

9. State Management (flutter_client/lib/bloc/chat_state.dart)

- messages: List of ALL interactions (not just user/assistant)
- Helper getters:
  - conversationMessages: Filter for type IN ('user', 'assistant')
  - allInteractions: Return everything

10. UI Components (flutter_client/lib/widgets/)

- ConversationPane: Display state.conversationMessages (filtered view)
- InteractionViewer: Display state.allInteractions (complete view)
- Remove references to AgenticTraceBloc

## Testing

11. Integration Testing

- Test multi-turn conversation with context
- Verify LLM receives previous messages
- Verify both panes show correct filtered views
- Verify sequence numbers are correct across all message types

# Key Benefits of This Design

1. Single source of truth: One table, one list in client state
2. Simple filtering: Show what you need by filtering on type
3. Natural ordering: Sequence number orders everything correctly
4. Real-time + persistent: Stream as events happen, reload from DB on app start
5. LLM context: Easy to build conversation history for API calls
6. Cleaner code: Remove AgenticTraceBloc complexity
