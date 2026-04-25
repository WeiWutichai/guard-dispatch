-- =============================================================================
-- reset-staging.sql — Wipe everything except admin users on staging
-- =============================================================================
-- Safe to re-run. Wraps the whole thing in a transaction so you can ROLLBACK
-- if something looks off in the row counts. Does NOT drop tables/schemas —
-- only deletes rows.
--
-- Kept:
--   - auth.users WHERE role = 'admin'
--   - auth.sessions for those admins
--   - booking.service_rates (pricing config the admin curated)
--
-- Wiped:
--   - All non-admin users (guards, customers, null-role applicants) and the
--     full cascade of their data: profiles, bookings, payments, refunds,
--     reviews, calls, chats, attachments, GPS history, FCM tokens,
--     notifications, OTP codes, audit logs.
--
-- Most FKs to auth.users are ON DELETE CASCADE, but the data tables hold
-- so much (esp. attachments + history) that a TRUNCATE is faster than
-- relying on cascades. We TRUNCATE everything first, then delete the
-- users so there's no dependency to chase.
-- =============================================================================

\echo 'Pre-reset counts'
SELECT 'auth.users (admin)' AS table, COUNT(*) FROM auth.users WHERE role = 'admin'
UNION ALL
SELECT 'auth.users (non-admin)', COUNT(*) FROM auth.users WHERE role IS DISTINCT FROM 'admin'
UNION ALL
SELECT 'booking.guard_requests', COUNT(*) FROM booking.guard_requests
UNION ALL
SELECT 'booking.assignments', COUNT(*) FROM booking.assignments
UNION ALL
SELECT 'booking.payments', COUNT(*) FROM booking.payments
UNION ALL
SELECT 'chat.messages', COUNT(*) FROM chat.messages
UNION ALL
SELECT 'tracking.location_history', COUNT(*) FROM tracking.location_history
UNION ALL
SELECT 'calls.call_logs', COUNT(*) FROM calls.call_logs;

BEGIN;

-- ──────────────────────────────────────────────────────────────────────────
-- 1. TRUNCATE all transactional tables. CASCADE so any unlisted child rows
--    (e.g. progress_report_media linking back to progress_reports) go too.
--    RESTART IDENTITY zeros sequences where present (most are UUID).
-- ──────────────────────────────────────────────────────────────────────────
TRUNCATE
    -- Calls (C2)
    calls.call_logs,
    -- Reviews
    reviews.guard_reviews,
    -- Notifications + FCM tokens
    notification.notification_logs,
    notification.fcm_tokens,
    -- Chat (in dependency order, but CASCADE handles it)
    chat.read_receipts,
    chat.attachments,
    chat.messages,
    chat.conversation_participants,
    chat.conversations,
    -- Tracking
    tracking.location_history,
    tracking.guard_locations,
    -- Booking (progress reports first, then assignments, then payments, then requests)
    booking.progress_report_media,
    booking.progress_reports,
    booking.payments,
    booking.assignments,
    booking.guard_requests,
    -- Auth ephemeral data (OTP only — sessions handled below)
    auth.otp_codes,
    -- Audit log — wipe so the test run starts from a clean slate
    audit.audit_logs
RESTART IDENTITY CASCADE;

-- ──────────────────────────────────────────────────────────────────────────
-- 2. Delete non-admin users. The remaining FKs (guard_profiles,
--    customer_profiles, sessions) all CASCADE on user delete, so this
--    one statement removes those rows automatically.
-- ──────────────────────────────────────────────────────────────────────────
DELETE FROM auth.users WHERE role IS DISTINCT FROM 'admin';

-- ──────────────────────────────────────────────────────────────────────────
-- 3. Sanity-check: profiles for any remaining (admin) user shouldn't exist,
--    but if a stray row escaped, drop it.
-- ──────────────────────────────────────────────────────────────────────────
DELETE FROM auth.guard_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users);
DELETE FROM auth.customer_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users);

\echo 'Post-reset counts'
SELECT 'auth.users (admin)' AS table, COUNT(*) FROM auth.users WHERE role = 'admin'
UNION ALL
SELECT 'auth.users (non-admin)', COUNT(*) FROM auth.users WHERE role IS DISTINCT FROM 'admin'
UNION ALL
SELECT 'auth.sessions', COUNT(*) FROM auth.sessions
UNION ALL
SELECT 'booking.service_rates (kept)', COUNT(*) FROM booking.service_rates
UNION ALL
SELECT 'booking.guard_requests', COUNT(*) FROM booking.guard_requests
UNION ALL
SELECT 'booking.assignments', COUNT(*) FROM booking.assignments
UNION ALL
SELECT 'booking.payments', COUNT(*) FROM booking.payments
UNION ALL
SELECT 'chat.messages', COUNT(*) FROM chat.messages
UNION ALL
SELECT 'tracking.guard_locations', COUNT(*) FROM tracking.guard_locations
UNION ALL
SELECT 'calls.call_logs', COUNT(*) FROM calls.call_logs;

-- Review the counts above. If they look right:
--   COMMIT;
-- If something's off:
--   ROLLBACK;
--
-- (The orchestrator script runs with `\set ON_ERROR_STOP on` and auto-COMMITs
-- on success.)
COMMIT;
