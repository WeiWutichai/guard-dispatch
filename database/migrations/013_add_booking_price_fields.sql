-- Add pricing and instruction fields to guard_requests
ALTER TABLE booking.guard_requests
    ADD COLUMN offered_price DECIMAL(10, 2),
    ADD COLUMN special_instructions TEXT;

-- Partial index to optimize guard earnings queries (completed assignments)
CREATE INDEX IF NOT EXISTS idx_assignments_guard_completed
    ON booking.assignments(guard_id, status, completed_at DESC)
    WHERE status = 'completed';
