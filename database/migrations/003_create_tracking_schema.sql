-- =============================================================================
-- Migration 003: Tracking Schema
-- Creates tracking.guard_locations (latest), tracking.location_history
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS tracking;

-- Latest guard location (one row per guard, upserted on each GPS update)
CREATE TABLE tracking.guard_locations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guard_id    UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    accuracy    REAL,
    heading     REAL,
    speed       REAL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_guard_locations_guard_id ON tracking.guard_locations(guard_id);

-- Full location history (append-only, for playback and analytics)
CREATE TABLE tracking.location_history (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guard_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES booking.assignments(id) ON DELETE SET NULL,
    lat           DOUBLE PRECISION NOT NULL,
    lng           DOUBLE PRECISION NOT NULL,
    recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_location_history_guard_recorded
    ON tracking.location_history(guard_id, recorded_at DESC);
CREATE INDEX idx_location_history_assignment_id
    ON tracking.location_history(assignment_id);
