-- Add pending_completion status for customer approval flow
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'pending_completion' AFTER 'arrived';

-- Track when guard requested job completion (displayed to customer for review)
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS completion_requested_at TIMESTAMPTZ;
