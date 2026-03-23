-- =============================================================================
-- Migration 031: Location History Retention
-- Adds index for efficient date-range deletion + cleanup function.
-- Schedule via pg_cron or call from application background task.
-- =============================================================================

-- Index for efficient DELETE by recorded_at range (retention cleanup)
CREATE INDEX IF NOT EXISTS idx_location_history_recorded_at
    ON tracking.location_history(recorded_at);

-- Also add accuracy/heading/speed columns that were missing from history
ALTER TABLE tracking.location_history
    ADD COLUMN IF NOT EXISTS accuracy REAL,
    ADD COLUMN IF NOT EXISTS heading  REAL,
    ADD COLUMN IF NOT EXISTS speed    REAL;

-- Function to delete location history older than retention_days (default 90)
CREATE OR REPLACE FUNCTION tracking.cleanup_old_history(retention_days INTEGER DEFAULT 90)
RETURNS BIGINT AS $$
DECLARE
    deleted BIGINT;
BEGIN
    DELETE FROM tracking.location_history
    WHERE recorded_at < NOW() - (retention_days || ' days')::INTERVAL;
    GET DIAGNOSTICS deleted = ROW_COUNT;
    RETURN deleted;
END;
$$ LANGUAGE plpgsql;
