-- =============================================================================
-- Migration 006: Audit Schema
-- Creates audit.audit_logs for tracking all actions
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE audit.audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   UUID,
    old_value   JSONB,
    new_value   JSONB,
    ip_address  INET,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user_id ON audit.audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON audit.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit.audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit.audit_logs(action);
