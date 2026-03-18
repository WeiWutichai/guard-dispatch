-- Add place name fields for check-in locations (reverse geocoded)
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS en_route_place TEXT;
ALTER TABLE booking.assignments ADD COLUMN IF NOT EXISTS arrived_place TEXT;
