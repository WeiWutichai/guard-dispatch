-- Admin can hide/show individual reviews on the public-facing pages.
-- Default is true so existing reviews remain visible after rollout.
ALTER TABLE reviews.guard_reviews
    ADD COLUMN IF NOT EXISTS is_visible BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_guard_reviews_is_visible
    ON reviews.guard_reviews(is_visible);
