-- Add full_name, contact_phone, email columns to customer_profiles
ALTER TABLE auth.customer_profiles
    ADD COLUMN full_name      TEXT,
    ADD COLUMN contact_phone  TEXT,
    ADD COLUMN email          TEXT;
