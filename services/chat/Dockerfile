# =============================================================================
# Chat Service — Multi-stage Dockerfile (WebSocket + MinIO)
# =============================================================================

FROM rust:1-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Copy workspace manifests
COPY Cargo.toml Cargo.toml
COPY services/shared/Cargo.toml        services/shared/Cargo.toml
COPY services/auth/Cargo.toml          services/auth/Cargo.toml
COPY services/booking/Cargo.toml       services/booking/Cargo.toml
COPY services/tracking/Cargo.toml      services/tracking/Cargo.toml
COPY services/notification/Cargo.toml  services/notification/Cargo.toml
COPY services/chat/Cargo.toml          services/chat/Cargo.toml

# Dummy sources for dep caching
RUN mkdir -p services/shared/src services/auth/src services/booking/src \
  services/tracking/src services/notification/src services/chat/src \
  && echo '' > services/shared/src/lib.rs \
  && for s in auth booking tracking notification chat; do \
  echo 'fn main() {}' > services/$s/src/main.rs; \
  done

RUN cargo build --release -p chat-service 2>/dev/null; true

COPY services/shared/src services/shared/src
COPY services/chat/src services/chat/src

RUN find services/shared/src services/chat/src -name '*.rs' | xargs touch && cargo build --release -p chat-service

# Runtime
FROM debian:trixie-slim AS runtime

RUN apt-get update && apt-get install -y ca-certificates binutils && rm -rf /var/lib/apt/lists/* \
    && groupadd -r appuser && useradd -r -g appuser -s /sbin/nologin appuser

WORKDIR /app

COPY --from=builder /app/target/release/chat-service /app/chat-service

RUN strip /app/chat-service

USER appuser

EXPOSE 3006

CMD ["/app/chat-service"]
