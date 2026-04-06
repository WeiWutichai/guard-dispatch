-- Fix: allow hour_number = 0 for "start of duty" report (เริ่มปฏิบัติงาน)
-- Original migration 028 incorrectly used CHECK (hour_number >= 1)
ALTER TABLE booking.progress_reports
    DROP CONSTRAINT IF EXISTS progress_reports_hour_number_check;

ALTER TABLE booking.progress_reports
    ADD CONSTRAINT progress_reports_hour_number_check CHECK (hour_number >= 0);
