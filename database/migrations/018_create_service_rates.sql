-- Service rate types (ประเภทบริการ)
CREATE TABLE booking.service_rates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  description   TEXT,
  min_price     DECIMAL(10,2) NOT NULL,
  max_price     DECIMAL(10,2) NOT NULL,
  base_fee      DECIMAL(10,2) NOT NULL,
  min_hours     INTEGER NOT NULL DEFAULT 6,
  notes         TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_service_rates_active ON booking.service_rates(is_active);

-- Seed data matching Web Admin mock data
INSERT INTO booking.service_rates (name, description, min_price, max_price, base_fee, min_hours, notes) VALUES
  ('เจ้าหน้าที่รักษาความปลอดภัย', 'สำหรับรักษาความปลอดภัยบ้าน สำนักงาน หรือสถานที่ต่างๆ', 80, 200, 100, 6, 'ราคามาตรฐานสำหรับงานทั่วไป'),
  ('บอดี้การ์ด', 'สำหรับคุ้มครองส่วนตัว ติดตาม หรือป้องกันภัยส่วนบุคคล', 180, 300, 200, 4, 'สำหรับงานระดับสูง ต้องผ่านการอบรมพิเศษ'),
  ('เจ้าหน้าที่รักษาความปลอดภัยงานอีเวนต์', 'สำหรับงานอีเวนต์และคอนเสิร์ต', 100, 250, 150, 4, 'สำหรับงานอีเวนต์และคอนเสิร์ต');
