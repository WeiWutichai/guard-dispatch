-- =============================================================================
-- Migration 030: Add is_online to guard_locations
-- Tracks whether guard's GPS WebSocket is currently connected.
-- Set true on GPS update, false on WebSocket disconnect.
-- =============================================================================

ALTER TABLE tracking.guard_locations
    ADD COLUMN IF NOT EXISTS is_online BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_guard_locations_online
    ON tracking.guard_locations(is_online) WHERE is_online = true;
