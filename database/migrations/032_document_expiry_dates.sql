-- =============================================================================
-- Migration 032: Document Expiry Dates
-- Adds expiry date columns for each document in guard_profiles.
-- =============================================================================

ALTER TABLE auth.guard_profiles
    ADD COLUMN IF NOT EXISTS id_card_expiry DATE,
    ADD COLUMN IF NOT EXISTS security_license_expiry DATE,
    ADD COLUMN IF NOT EXISTS training_cert_expiry DATE,
    ADD COLUMN IF NOT EXISTS criminal_check_expiry DATE,
    ADD COLUMN IF NOT EXISTS driver_license_expiry DATE;
