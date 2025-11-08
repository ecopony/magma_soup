-- ABOUTME: Migration to unify messages and llm_history into single messages table
-- ABOUTME: Creates type-discriminated message structure for all conversation interactions

-- Drop the old llm_history table
DROP TABLE IF EXISTS llm_history CASCADE;

-- Drop and recreate the messages table with the new unified structure
-- NOTE: This migration intentionally drops existing data. For development use only.
DROP TABLE IF EXISTS messages CASCADE;

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

CREATE INDEX idx_messages_conversation_sequence ON messages(conversation_id, sequence_number);
CREATE INDEX idx_messages_conversation_type ON messages(conversation_id, type);
CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC);
