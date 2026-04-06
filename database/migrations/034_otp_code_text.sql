-- OTP codes are now stored as SHA-256 hashes (64 hex chars) instead of plaintext.
-- VARCHAR(16) is too small for the hash. Change to TEXT.
ALTER TABLE auth.otp_codes ALTER COLUMN code TYPE TEXT;
