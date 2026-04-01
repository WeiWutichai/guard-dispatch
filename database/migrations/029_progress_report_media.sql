-- Progress report media attachments (multiple photos + video per report)
CREATE TABLE booking.progress_report_media (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id   UUID NOT NULL REFERENCES booking.progress_reports(id) ON DELETE CASCADE,
    file_key    TEXT NOT NULL,
    mime_type   TEXT NOT NULL,
    file_size   INTEGER NOT NULL,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_progress_report_media_report ON booking.progress_report_media(report_id, sort_order);
