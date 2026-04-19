-- Review finding M4: store guard_count on booking.guard_requests
--
-- Frontend already uses guard_count to compute subtotal (_baseFee × hours × guards)
-- but the value never reached the backend — hirer history always showed "1 guard"
-- regardless of the actual booking, and the backend could not verify client-
-- supplied amounts against an expected total (payment amount bypass C1 follow-up).
--
-- DEFAULT 1 keeps all historical rows well-defined. CHECK constraint matches
-- the 1..=20 range enforced by validate_create_request() in the service layer.

ALTER TABLE booking.guard_requests
    ADD COLUMN guard_count INTEGER NOT NULL DEFAULT 1
        CHECK (guard_count BETWEEN 1 AND 20);
