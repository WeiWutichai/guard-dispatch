-- =============================================================================
-- Migration 020: Chat sender_role + read receipts
-- Adds sender_role to messages for role-based chat alignment
-- Creates read_receipts table for unread tracking
-- =============================================================================

-- Add sender_role to messages (guard/customer)
ALTER TABLE chat.messages ADD COLUMN sender_role VARCHAR(20);

-- Read receipts: track last read message per user per role per conversation
CREATE TABLE chat.read_receipts (
    conversation_id UUID NOT NULL REFERENCES chat.conversations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_role       VARCHAR(20) NOT NULL DEFAULT 'guard',
    last_read_message_id UUID REFERENCES chat.messages(id) ON DELETE SET NULL,
    read_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id, user_role)
);

CREATE INDEX idx_read_receipts_user ON chat.read_receipts(user_id, user_role);
