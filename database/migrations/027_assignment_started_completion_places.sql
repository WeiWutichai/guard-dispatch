-- Add GPS + place name fields for started and completion check-in locations
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS started_lat DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS started_lng DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS started_place TEXT;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS completion_lat DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS completion_lng DOUBLE PRECISION;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS completion_place TEXT;
