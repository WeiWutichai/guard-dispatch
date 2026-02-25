# =============================================================================
# MediaSoup Server — Node.js (Video/Audio Call)
# =============================================================================

FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies for mediasoup native modules
RUN apk add --no-cache python3 make g++ linux-headers

COPY services/mediasoup/package*.json ./
RUN npm ci --omit=dev

# Stage 2: Runtime
FROM node:20-alpine AS runtime

WORKDIR /app

RUN apk add --no-cache python3 make g++ linux-headers

COPY --from=builder /app/node_modules ./node_modules
COPY services/mediasoup/src ./src
COPY services/mediasoup/package*.json ./

EXPOSE 3005
EXPOSE 40000-49999/udp

CMD ["node", "src/index.js"]
