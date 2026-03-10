-- Track per-profile approval for customer profiles (separate from auth.users.approval_status).
-- This allows an already-approved guard to submit a customer profile that requires its own approval.
ALTER TABLE auth.customer_profiles
    ADD COLUMN approval_status approval_status NOT NULL DEFAULT 'pending';
