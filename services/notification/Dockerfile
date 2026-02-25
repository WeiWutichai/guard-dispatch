# =============================================================================
# Notification Service — Multi-stage Dockerfile (FCM)
# =============================================================================

FROM rust:1.83-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.toml
COPY services/auth/Cargo.toml services/auth/Cargo.toml
COPY services/booking/Cargo.toml services/booking/Cargo.toml
COPY services/tracking/Cargo.toml services/tracking/Cargo.toml
COPY services/notification/Cargo.toml services/notification/Cargo.toml

RUN mkdir -p services/auth/src services/booking/src services/tracking/src services/notification/src \
    && echo 'fn main() {}' > services/auth/src/main.rs \
    && echo 'fn main() {}' > services/booking/src/main.rs \
    && echo 'fn main() {}' > services/tracking/src/main.rs \
    && echo 'fn main() {}' > services/notification/src/main.rs

RUN cargo build --release -p notification-service 2>/dev/null; true

COPY services/notification/src services/notification/src

RUN touch services/notification/src/main.rs && cargo build --release -p notification-service

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/notification-service /app/notification-service

EXPOSE 3004

CMD ["/app/notification-service"]
