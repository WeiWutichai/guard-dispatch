-- Cost summary on job completion.
--
-- When a job ends, the booking service prorates `payments.amount` by
-- (actual_hours_worked / booked_hours) and stores the result in
-- `final_amount`. Any positive difference becomes `refund_amount` (admin
-- processes the actual refund later — this column is just the ledger).
--
-- `tip_amount` lets the customer optionally pay extra to the guard from
-- the completion-summary screen. Defaults to 0 so existing rows stay valid.
--
-- All columns are nullable (except tip_amount) so they only get populated
-- after the assignment reaches a terminal state. This avoids backfilling
-- historical pending payments.

ALTER TABLE booking.payments
    ADD COLUMN IF NOT EXISTS actual_hours_worked DECIMAL(5,2),
    ADD COLUMN IF NOT EXISTS final_amount        DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS refund_amount       DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS tip_amount          DECIMAL(10,2) NOT NULL DEFAULT 0;

-- Sanity bounds (non-negative). Proration logic must clamp before insert.
ALTER TABLE booking.payments
    ADD CONSTRAINT payments_actual_hours_nonneg
        CHECK (actual_hours_worked IS NULL OR actual_hours_worked >= 0),
    ADD CONSTRAINT payments_final_amount_nonneg
        CHECK (final_amount IS NULL OR final_amount >= 0),
    ADD CONSTRAINT payments_refund_amount_nonneg
        CHECK (refund_amount IS NULL OR refund_amount >= 0),
    ADD CONSTRAINT payments_tip_amount_nonneg
        CHECK (tip_amount >= 0);
