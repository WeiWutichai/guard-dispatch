-- Migration 045: Add address + emergency contact to guard_profiles
--
-- Context: Approved guards can now self-edit all personal information from the
-- mobile app. The address and emergency contact fields were already shown in
-- the profile UI as placeholders but had no DB backing — this migration adds
-- the missing columns. All four are nullable since existing guards do not
-- have this data; they will populate it via PUT /profile/guard/info.

ALTER TABLE auth.guard_profiles
    ADD COLUMN IF NOT EXISTS address                          TEXT,
    ADD COLUMN IF NOT EXISTS emergency_contact_name           TEXT,
    ADD COLUMN IF NOT EXISTS emergency_contact_phone          TEXT,
    ADD COLUMN IF NOT EXISTS emergency_contact_relationship   TEXT;
