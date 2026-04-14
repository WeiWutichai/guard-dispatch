-- Replace min_price + max_price with single price_per_hour
ALTER TABLE booking.service_rates ADD COLUMN price_per_hour DECIMAL(10,2);

-- Migrate data: use midpoint of min/max as the single price
UPDATE booking.service_rates SET price_per_hour = (min_price + max_price) / 2;

-- Make NOT NULL after data migration
ALTER TABLE booking.service_rates ALTER COLUMN price_per_hour SET NOT NULL;

-- Drop old columns
ALTER TABLE booking.service_rates DROP COLUMN min_price;
ALTER TABLE booking.service_rates DROP COLUMN max_price;

-- Update seed data to round prices
UPDATE booking.service_rates SET price_per_hour = 140 WHERE name = 'เจ้าหน้าที่รักษาความปลอดภัย';
UPDATE booking.service_rates SET price_per_hour = 240 WHERE name = 'บอดี้การ์ด';
UPDATE booking.service_rates SET price_per_hour = 175 WHERE name = 'เจ้าหน้าที่รักษาความปลอดภัยงานอีเวนต์';
