-- Migration 019: Booking flow enhancements
-- Adds new assignment statuses, payments table, and countdown fields

-- Add new assignment statuses for guard acceptance flow
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'pending_acceptance' BEFORE 'assigned';
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'accepted' AFTER 'assigned';
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'declined' AFTER 'accepted';

-- Add started_at to assignments for countdown tracking
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;

-- Add booked_hours to guard_requests for countdown calculation
ALTER TABLE booking.guard_requests ADD COLUMN IF NOT EXISTS booked_hours INTEGER;

-- Payments table (simulated, ready for real gateway integration)
CREATE TABLE IF NOT EXISTS booking.payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      UUID NOT NULL REFERENCES booking.guard_requests(id),
  customer_id     UUID NOT NULL REFERENCES auth.users(id),
  amount          DECIMAL(10,2) NOT NULL,
  payment_method  TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending',
  transaction_ref TEXT,
  paid_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_request_id ON booking.payments(request_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON booking.payments(customer_id);
