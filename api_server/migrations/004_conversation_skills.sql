-- ABOUTME: Add active_skills tracking to conversations
-- ABOUTME: Enables progressive disclosure of tool skills per conversation

-- Add active_skills column to conversations
ALTER TABLE conversations
ADD COLUMN active_skills TEXT[] DEFAULT '{}';

-- Index for querying conversations by skill
CREATE INDEX idx_conversations_active_skills ON conversations USING GIN(active_skills);
