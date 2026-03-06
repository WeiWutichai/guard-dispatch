-- Reviews schema for guard ratings and customer feedback
CREATE SCHEMA IF NOT EXISTS reviews;

CREATE TABLE reviews.guard_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guard_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assignment_id UUID NOT NULL REFERENCES booking.assignments(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES booking.guard_requests(id),

    -- Overall + category ratings (1.0 - 5.0)
    overall_rating DECIMAL(2, 1) NOT NULL CHECK (overall_rating >= 1 AND overall_rating <= 5),
    punctuality DECIMAL(2, 1) CHECK (punctuality >= 1 AND punctuality <= 5),
    professionalism DECIMAL(2, 1) CHECK (professionalism >= 1 AND professionalism <= 5),
    communication DECIMAL(2, 1) CHECK (communication >= 1 AND communication <= 5),
    appearance DECIMAL(2, 1) CHECK (appearance >= 1 AND appearance <= 5),

    review_text TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One review per assignment
    UNIQUE (assignment_id)
);

CREATE INDEX idx_guard_reviews_guard_id ON reviews.guard_reviews(guard_id, created_at DESC);
CREATE INDEX idx_guard_reviews_customer_id ON reviews.guard_reviews(customer_id);
