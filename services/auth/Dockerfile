# =============================================================================
# Auth Service — Multi-stage Dockerfile
# =============================================================================

# Stage 1: Builder
FROM rust:1.83-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Copy workspace manifests first (layer cache optimization)
COPY Cargo.toml Cargo.toml
COPY services/auth/Cargo.toml services/auth/Cargo.toml
COPY services/booking/Cargo.toml services/booking/Cargo.toml
COPY services/tracking/Cargo.toml services/tracking/Cargo.toml
COPY services/notification/Cargo.toml services/notification/Cargo.toml

# Create dummy main files to allow dependency caching
RUN mkdir -p services/auth/src services/booking/src services/tracking/src services/notification/src \
    && echo 'fn main() {}' > services/auth/src/main.rs \
    && echo 'fn main() {}' > services/booking/src/main.rs \
    && echo 'fn main() {}' > services/tracking/src/main.rs \
    && echo 'fn main() {}' > services/notification/src/main.rs

# Build dependencies only (cached layer)
RUN cargo build --release -p auth-service 2>/dev/null; true

# Copy actual source
COPY services/auth/src services/auth/src

# Build the actual binary
RUN touch services/auth/src/main.rs && cargo build --release -p auth-service

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/auth-service /app/auth-service

EXPOSE 3001

CMD ["/app/auth-service"]
