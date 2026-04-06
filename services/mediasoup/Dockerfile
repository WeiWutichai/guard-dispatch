# =============================================================================
# MediaSoup Server — Node.js (Video/Audio Call)
# =============================================================================

# Use Debian-based image (not Alpine) — mediasoup prebuilt binaries require glibc.
# Alpine uses musl libc → prebuilt fails (exit 127) → falls back to C++ compile → OOM.
FROM node:22-slim AS builder

WORKDIR /app

# Install build dependencies for mediasoup native modules (fallback if prebuilt unavailable)
RUN apt-get update && apt-get install -y python3 python3-pip make g++ && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci

# Stage 2: Runtime — no build tools
FROM node:22-slim AS runtime

WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser -s /sbin/nologin appuser

COPY --from=builder /app/node_modules ./node_modules
COPY src ./src
COPY package*.json ./

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 3005
EXPOSE 40000-49999/udp

CMD ["node", "src/index.js"]
