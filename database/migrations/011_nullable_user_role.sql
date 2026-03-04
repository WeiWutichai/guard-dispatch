-- Allow users to register without selecting a role (onboarding users).
-- Null role means the user has not yet chosen guard/customer during registration.
-- Admins can see these users in the applicants list with "ยังไม่ได้ระบุ" indicator.
ALTER TABLE auth.users ALTER COLUMN role DROP NOT NULL;
