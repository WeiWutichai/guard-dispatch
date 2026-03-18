-- Guard hourly progress reports (photo + message per hour)
CREATE TABLE booking.progress_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id   UUID NOT NULL REFERENCES booking.assignments(id) ON DELETE CASCADE,
    guard_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    hour_number     INTEGER NOT NULL CHECK (hour_number >= 1),
    message         TEXT,
    photo_file_key  TEXT,
    photo_mime_type TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (assignment_id, hour_number)
);

CREATE INDEX idx_progress_reports_assignment ON booking.progress_reports(assignment_id, hour_number);
