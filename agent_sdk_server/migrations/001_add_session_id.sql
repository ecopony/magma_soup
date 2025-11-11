-- Add session_id column to conversations table for Agent SDK session management
-- This allows the SDK to automatically handle conversation history via the resume parameter

ALTER TABLE conversations
ADD COLUMN session_id TEXT;

CREATE INDEX idx_conversations_session_id ON conversations(session_id);

COMMENT ON COLUMN conversations.session_id IS 'Agent SDK session ID for automatic conversation history management';
