# =============================================================================
# MediaSoup Server — Node.js (Video/Audio Call)
# =============================================================================

FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies for mediasoup native modules
RUN apk add --no-cache python3 py3-pip make g++ linux-headers

COPY package*.json ./
RUN npm ci

# Stage 2: Runtime — no build tools
FROM node:20-alpine AS runtime

WORKDIR /app

# Create non-root user
RUN addgroup -S appuser && adduser -S appuser -G appuser

COPY --from=builder /app/node_modules ./node_modules
COPY src ./src
COPY package*.json ./

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 3005
EXPOSE 40000-49999/udp

CMD ["node", "src/index.js"]
