-- =============================================================================
-- Migration 002: Booking Schema
-- Creates request_status, urgency_level, assignment_status enums
-- Creates booking.guard_requests, booking.assignments
-- =============================================================================

CREATE TYPE request_status AS ENUM ('pending', 'assigned', 'in_progress', 'completed', 'cancelled');
CREATE TYPE urgency_level AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE assignment_status AS ENUM ('assigned', 'en_route', 'arrived', 'completed', 'cancelled');

CREATE SCHEMA IF NOT EXISTS booking;

-- Guard requests (customer creates a request for a guard)
CREATE TABLE booking.guard_requests (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    location_lat  DOUBLE PRECISION NOT NULL,
    location_lng  DOUBLE PRECISION NOT NULL,
    address       TEXT NOT NULL,
    description   TEXT,
    status        request_status NOT NULL DEFAULT 'pending',
    urgency       urgency_level NOT NULL DEFAULT 'medium',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_guard_requests_customer_id ON booking.guard_requests(customer_id);
CREATE INDEX idx_guard_requests_status ON booking.guard_requests(status);
CREATE INDEX idx_guard_requests_urgency ON booking.guard_requests(urgency);
CREATE INDEX idx_guard_requests_created_at ON booking.guard_requests(created_at DESC);

-- Assignments (guard assigned to a request)
CREATE TABLE booking.assignments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id    UUID NOT NULL REFERENCES booking.guard_requests(id) ON DELETE CASCADE,
    guard_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status        assignment_status NOT NULL DEFAULT 'assigned',
    assigned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    arrived_at    TIMESTAMPTZ,
    completed_at  TIMESTAMPTZ
);

CREATE INDEX idx_assignments_request_id ON booking.assignments(request_id);
CREATE INDEX idx_assignments_guard_id ON booking.assignments(guard_id);
CREATE INDEX idx_assignments_status ON booking.assignments(status);

CREATE TRIGGER trigger_guard_requests_updated_at
    BEFORE UPDATE ON booking.guard_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
