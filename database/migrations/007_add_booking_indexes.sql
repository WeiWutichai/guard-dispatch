-- =============================================================================
-- Migration 007: Performance Indexes for Booking Service
-- Adds composite index for list_requests queries (status + created_at)
-- =============================================================================

-- Composite index to optimize list_requests filtered by status and sorted by date
CREATE INDEX IF NOT EXISTS idx_guard_requests_status_created
    ON booking.guard_requests(status, created_at DESC);

-- Index to optimize is_guard_assigned lookups
CREATE INDEX IF NOT EXISTS idx_assignments_request_guard
    ON booking.assignments(request_id, guard_id);
