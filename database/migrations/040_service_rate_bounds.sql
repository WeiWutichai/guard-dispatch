-- Defense-in-depth bounds on booking.service_rates (review findings M3 + L4)
-- Mirrors validate_service_rate() in services/booking/src/service.rs so direct
-- SQL / any future code path that bypasses the service layer is still caught.
--
-- NOT VALID on the base_fee constraint skips historical rows. min_hours is
-- added plain because the NOT NULL DEFAULT 6 column already obeys the range.

ALTER TABLE booking.service_rates
    ADD CONSTRAINT service_rates_base_fee_bounds
        CHECK (base_fee >= 0 AND base_fee <= 1000000) NOT VALID;

ALTER TABLE booking.service_rates
    ADD CONSTRAINT service_rates_min_hours_bounds
        CHECK (min_hours BETWEEN 1 AND 24);
