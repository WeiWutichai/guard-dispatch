-- 044_guard_request_scheduled_start.sql — fix /operations 500
--
-- PR #33's `list_active_operations` query references gr.scheduled_start but
-- no migration ever added the column. The endpoint has been 500-ing on every
-- request since that PR shipped — it just wasn't noticed because nobody
-- visited /operations on staging until 2026-04-25.
--
-- Until the booking form lets the customer pick a start time, default to
-- NOW() for new rows and backfill existing rows from created_at so the
-- admin dashboard sorts coherently. Service-layer code that derives
-- "late_threshold = scheduled_start + 5min" still works the same — old
-- rows just get classified by their creation time, which is close enough
-- for the in-flight assignments the dashboard cares about.

ALTER TABLE booking.guard_requests
    ADD COLUMN IF NOT EXISTS scheduled_start TIMESTAMPTZ;

UPDATE booking.guard_requests
SET scheduled_start = created_at
WHERE scheduled_start IS NULL;

ALTER TABLE booking.guard_requests
    ALTER COLUMN scheduled_start SET NOT NULL,
    ALTER COLUMN scheduled_start SET DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_guard_requests_scheduled_start
    ON booking.guard_requests(scheduled_start);
