-- =============================================================================
-- Migration 004: Notification Schema
-- Creates notification_type enum
-- Creates notification.notification_logs, notification.fcm_tokens
-- =============================================================================

CREATE TYPE notification_type AS ENUM (
    'booking_created',
    'guard_assigned',
    'guard_en_route',
    'guard_arrived',
    'booking_completed',
    'booking_cancelled',
    'chat_message',
    'system'
);

CREATE SCHEMA IF NOT EXISTS notification;

-- Notification logs
CREATE TABLE notification.notification_logs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title             TEXT NOT NULL,
    body              TEXT NOT NULL,
    notification_type notification_type NOT NULL,
    payload           JSONB,
    is_read           BOOLEAN NOT NULL DEFAULT false,
    sent_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at           TIMESTAMPTZ
);

CREATE INDEX idx_notification_logs_user_id ON notification.notification_logs(user_id);
CREATE INDEX idx_notification_logs_is_read ON notification.notification_logs(user_id, is_read);
CREATE INDEX idx_notification_logs_sent_at ON notification.notification_logs(sent_at DESC);

-- FCM device tokens
CREATE TABLE notification.fcm_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token       TEXT UNIQUE NOT NULL,
    device_type TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fcm_tokens_user_id ON notification.fcm_tokens(user_id);
CREATE INDEX idx_fcm_tokens_token ON notification.fcm_tokens(token);

CREATE TRIGGER trigger_fcm_tokens_updated_at
    BEFORE UPDATE ON notification.fcm_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
