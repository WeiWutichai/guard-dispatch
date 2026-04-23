-- 043_call_logs.sql — C2 in-app calls
-- Peer-to-peer WebRTC audio calls between guards and customers. The backend
-- is a thin signaling relay + this audit log. No MediaSoup / SFU — 2-party
-- calls don't need one. STUN comes from the public Google server; TURN is
-- out of scope for staging (strict-NAT customers can fall back to chat).

CREATE SCHEMA IF NOT EXISTS calls;

-- `initiated` = caller has opened the call, callee not yet notified
-- `ringing`   = FCM delivered; waiting for callee decision
-- `accepted`  = callee picked up; both peers negotiating media
-- `connected` = ICE finished, media flowing (reported by callee's client)
-- `ended`     = normal hangup from either side
-- `rejected`  = callee explicitly declined
-- `missed`    = callee didn't answer in timeout (45s default)
-- `failed`    = signaling/media error
CREATE TYPE calls.call_status AS ENUM (
    'initiated',
    'ringing',
    'accepted',
    'connected',
    'ended',
    'rejected',
    'missed',
    'failed'
);

CREATE TYPE calls.call_type AS ENUM ('audio', 'video');

CREATE TABLE calls.call_logs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caller_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    callee_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    call_type         calls.call_type NOT NULL DEFAULT 'audio',
    status            calls.call_status NOT NULL DEFAULT 'initiated',
    -- Optional linkage to a booking assignment / chat conversation so the
    -- admin view can show the job context without extra lookups.
    assignment_id     UUID REFERENCES booking.assignments(id) ON DELETE SET NULL,
    conversation_id   UUID REFERENCES chat.conversations(id) ON DELETE SET NULL,
    -- Lifecycle timestamps. `started_at` is row creation; the others are
    -- populated as the call advances and are used to derive duration.
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    answered_at       TIMESTAMPTZ,
    ended_at          TIMESTAMPTZ,
    duration_seconds  INTEGER,
    -- Who/what ended the call. Populated on transition to a terminal state.
    end_reason        TEXT,
    -- Network/device diagnostics (optional, client-submitted).
    caller_network    TEXT,  -- "wifi" / "cellular" / "unknown"
    callee_network    TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Admin dashboard: newest calls first, plus per-user history.
CREATE INDEX idx_call_logs_created_at ON calls.call_logs(created_at DESC);
CREATE INDEX idx_call_logs_caller ON calls.call_logs(caller_id, created_at DESC);
CREATE INDEX idx_call_logs_callee ON calls.call_logs(callee_id, created_at DESC);
CREATE INDEX idx_call_logs_status ON calls.call_logs(status, created_at DESC);
CREATE INDEX idx_call_logs_assignment ON calls.call_logs(assignment_id) WHERE assignment_id IS NOT NULL;
