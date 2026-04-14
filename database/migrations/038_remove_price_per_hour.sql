-- Simplify pricing: remove price_per_hour, keep only base_fee
ALTER TABLE booking.service_rates DROP COLUMN IF EXISTS price_per_hour;
