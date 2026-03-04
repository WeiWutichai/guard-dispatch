-- Guard applicant profile data collected during mobile registration.
-- Stores personal info, document file keys (MinIO), and bank account details.
-- One-to-one with auth.users (UNIQUE on user_id).
CREATE TABLE auth.guard_profiles (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  gender                VARCHAR(20),
  date_of_birth         DATE,
  years_of_experience   INTEGER,
  previous_workplace    TEXT,
  -- Document file keys (MinIO path: profiles/guard/{user_id}/{doc_type}.{ext})
  id_card_key           TEXT,
  security_license_key  TEXT,
  training_cert_key     TEXT,
  criminal_check_key    TEXT,
  driver_license_key    TEXT,
  -- Bank account details
  bank_name             TEXT,
  account_number        TEXT,
  account_name          TEXT,
  passbook_photo_key    TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_guard_profiles_user_id ON auth.guard_profiles(user_id);
