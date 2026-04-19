-- Security hotfix C1: prevent zero/negative payment amounts
--
-- Application-level validation in services/booking/src/service.rs::create_payment
-- already rejects amount <= 0 before the INSERT. This DB-level CHECK is a
-- defense-in-depth backstop: any future code path or direct SQL that bypasses
-- the service layer will also be caught here.
--
-- NOT VALID: the constraint applies to future INSERTs/UPDATEs only and does
-- NOT scan existing rows. This keeps the migration safe even if production
-- contains legacy rows with amount = 0 from the pre-fix exploit window.
--
-- Post-migration cleanup (run manually, not in this file):
--   1. SELECT COUNT(*) FROM booking.payments WHERE amount <= 0;
--   2. Investigate / refund / soft-delete offending rows.
--   3. ALTER TABLE booking.payments VALIDATE CONSTRAINT payments_amount_positive;

ALTER TABLE booking.payments
    ADD CONSTRAINT payments_amount_positive CHECK (amount > 0) NOT VALID;
