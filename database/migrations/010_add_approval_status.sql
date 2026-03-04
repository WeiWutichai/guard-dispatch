-- =============================================================================
-- Add approval_status to auth.users for applicant management workflow.
-- New users register as 'pending'; admin approves/rejects via API.
-- Default 'approved' so existing users are unaffected.
-- =============================================================================

CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');

ALTER TABLE auth.users
    ADD COLUMN approval_status approval_status NOT NULL DEFAULT 'approved';

-- Index for admin listing: filter by status + role, ordered by newest first
CREATE INDEX idx_users_approval_status_role_created
    ON auth.users (approval_status, role, created_at DESC);
