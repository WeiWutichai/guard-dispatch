-- =============================================================================
-- Widen OTP code column to support configurable OTP lengths.
-- Previous: VARCHAR(6) — only allowed exactly 6-digit codes.
-- New: VARCHAR(16) — supports OTP_LENGTH values up to 16 digits.
-- =============================================================================

ALTER TABLE auth.otp_codes
    ALTER COLUMN code TYPE VARCHAR(16);
