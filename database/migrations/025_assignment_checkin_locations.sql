-- Add check-in location and timestamp fields to assignments
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS en_route_at TIMESTAMPTZ;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS en_route_lat DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS en_route_lng DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS arrived_lat DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS arrived_lng DOUBLE PRECISION;
