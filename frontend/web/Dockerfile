# =============================================================================
# Guard Dispatch — Admin Portal (Next.js)
# Multi-stage Docker build for production deployment
# =============================================================================

# Stage 1: Install dependencies
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# Stage 2: Build the application
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build-time env vars
ENV NEXT_TELEMETRY_DISABLED=1

# IMPORTANT: Next.js inlines NEXT_PUBLIC_* env vars at BUILD time, not runtime.
# These values are baked into the static bundle and the rewrites() function,
# so they MUST be passed as build args, not just runtime environment.
#
# basePath matches nginx.prod.conf's /p-guard-app location (note the dash).
#
# Per-service URLs point directly at the Rust service containers on the
# `backend` Docker network. web-admin joins `backend` via the compose override
# and resolves each container by its service name. This bypasses nginx for
# server-to-server calls entirely, avoiding the HTTP→HTTPS redirect loop that
# otherwise forces the browser to try to reach `http://nginx-gateway` and fail.
ARG NEXT_PUBLIC_BASE_PATH=/p-guard-app
# Server-only service URLs — intentionally NOT prefixed with NEXT_PUBLIC_
# to prevent accidental client-side inlining that would leak internal
# Docker hostnames (rust-auth:3001 etc.) to the browser.
ARG AUTH_SERVICE_URL=http://rust-auth:3001
ARG BOOKING_SERVICE_URL=http://rust-booking:3002
ARG TRACKING_SERVICE_URL=http://rust-tracking:3003
ARG NOTIFICATION_SERVICE_URL=http://rust-notification:3004
ARG CHAT_SERVICE_URL=http://rust-chat:3006

ENV NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH}
ENV AUTH_SERVICE_URL=${AUTH_SERVICE_URL}
ENV BOOKING_SERVICE_URL=${BOOKING_SERVICE_URL}
ENV TRACKING_SERVICE_URL=${TRACKING_SERVICE_URL}
ENV NOTIFICATION_SERVICE_URL=${NOTIFICATION_SERVICE_URL}
ENV CHAT_SERVICE_URL=${CHAT_SERVICE_URL}

RUN npm run build

# Stage 3: Production runner
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy public assets
COPY --from=builder /app/public ./public

# Copy standalone output
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
