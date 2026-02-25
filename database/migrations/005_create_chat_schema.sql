-- =============================================================================
-- Migration 005: Chat Schema
-- Creates message_type enum
-- Creates chat.conversations, chat.conversation_participants,
--         chat.messages, chat.attachments
-- =============================================================================

CREATE TYPE message_type AS ENUM ('text', 'image', 'system');

CREATE SCHEMA IF NOT EXISTS chat;

-- Conversations (linked to a guard request)
CREATE TABLE chat.conversations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID NOT NULL REFERENCES booking.guard_requests(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversations_request_id ON chat.conversations(request_id);

-- Conversation participants
CREATE TABLE chat.conversation_participants (
    conversation_id UUID NOT NULL REFERENCES chat.conversations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conversation_participants_user_id
    ON chat.conversation_participants(user_id);

-- Messages
CREATE TABLE chat.messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat.conversations(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content         TEXT,
    message_type    message_type NOT NULL DEFAULT 'text',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation_id
    ON chat.messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender_id ON chat.messages(sender_id);

-- Attachments (file metadata only — binary stored in MinIO/R2)
CREATE TABLE chat.attachments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id  UUID NOT NULL REFERENCES chat.messages(id) ON DELETE CASCADE,
    uploader_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    file_key    TEXT NOT NULL,
    file_url    TEXT NOT NULL,
    file_size   INT,
    mime_type   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachments_message_id ON chat.attachments(message_id);
