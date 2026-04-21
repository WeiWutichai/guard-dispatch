-- Refund workflow tracking for booking.payments.
--
-- Up to now, `refund_amount` is computed by `prorate_payment_in_tx` when a
-- job completes partially (actual_hours < booked_hours). The column is
-- ledger-only — no operational workflow for admins to mark "I transferred
-- the money back to the customer" + attach a bank reference.
--
-- This migration adds that workflow:
--   - `refund_status`: pending (default for new refund_amount > 0 rows),
--                      processed (admin transferred), skipped (e.g. customer
--                      waived, owner merged into next booking).
--   - `refund_processed_at` / `refund_reference` / `refund_processed_by`:
--     the audit trail when an admin marks the refund complete.
--
-- Backfill: existing rows with refund_amount > 0 are marked 'pending' so the
-- new admin UI surfaces historical unprocessed refunds.

ALTER TABLE booking.payments
    ADD COLUMN refund_status     TEXT
        CHECK (refund_status IN ('pending', 'processed', 'skipped')),
    ADD COLUMN refund_processed_at TIMESTAMPTZ,
    ADD COLUMN refund_reference    TEXT,
    ADD COLUMN refund_processed_by UUID REFERENCES auth.users(id);

-- Index for the common admin filter: "show me all pending refunds newest first"
CREATE INDEX idx_payments_refund_status
    ON booking.payments (refund_status, paid_at DESC)
    WHERE refund_status IS NOT NULL;

-- Backfill historical rows
UPDATE booking.payments
SET refund_status = 'pending'
WHERE refund_amount IS NOT NULL
  AND refund_amount > 0
  AND refund_status IS NULL;
