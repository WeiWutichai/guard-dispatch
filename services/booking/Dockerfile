# =============================================================================
# Booking Service — Multi-stage Dockerfile
# =============================================================================

FROM rust:1.83-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.toml
COPY services/shared/Cargo.toml        services/shared/Cargo.toml
COPY services/auth/Cargo.toml          services/auth/Cargo.toml
COPY services/booking/Cargo.toml       services/booking/Cargo.toml
COPY services/tracking/Cargo.toml      services/tracking/Cargo.toml
COPY services/notification/Cargo.toml  services/notification/Cargo.toml
COPY services/chat/Cargo.toml          services/chat/Cargo.toml

RUN mkdir -p services/shared/src services/auth/src services/booking/src \
    services/tracking/src services/notification/src services/chat/src \
    && echo '' > services/shared/src/lib.rs \
    && for s in auth booking tracking notification chat; do \
    echo 'fn main() {}' > services/$s/src/main.rs; \
    done

RUN cargo build --release -p booking-service 2>/dev/null; true

COPY services/shared/src services/shared/src
COPY services/booking/src services/booking/src

RUN touch services/booking/src/main.rs && cargo build --release -p booking-service

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/booking-service /app/booking-service

EXPOSE 3002

CMD ["/app/booking-service"]
