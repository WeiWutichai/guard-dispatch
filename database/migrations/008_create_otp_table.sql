-- =============================================================================
-- OTP codes table for phone verification (registration flow)
-- =============================================================================

CREATE TABLE auth.otp_codes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       TEXT NOT NULL,
    code        VARCHAR(6) NOT NULL,
    purpose     VARCHAR(20) NOT NULL DEFAULT 'register',
    is_used     BOOLEAN NOT NULL DEFAULT false,
    attempts    INTEGER NOT NULL DEFAULT 0,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_codes_phone_purpose ON auth.otp_codes(phone, purpose, is_used);
CREATE INDEX idx_otp_codes_expires_at ON auth.otp_codes(expires_at);
