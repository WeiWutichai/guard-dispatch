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
ARG NEXT_PUBLIC_AUTH_URL=http://rust-auth:3001
ARG NEXT_PUBLIC_BOOKING_URL=http://rust-booking:3002
ARG NEXT_PUBLIC_TRACKING_URL=http://rust-tracking:3003
ARG NEXT_PUBLIC_NOTIFICATION_URL=http://rust-notification:3004
ARG NEXT_PUBLIC_CHAT_URL=http://rust-chat:3006

ENV NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH}
ENV NEXT_PUBLIC_AUTH_URL=${NEXT_PUBLIC_AUTH_URL}
ENV NEXT_PUBLIC_BOOKING_URL=${NEXT_PUBLIC_BOOKING_URL}
ENV NEXT_PUBLIC_TRACKING_URL=${NEXT_PUBLIC_TRACKING_URL}
ENV NEXT_PUBLIC_NOTIFICATION_URL=${NEXT_PUBLIC_NOTIFICATION_URL}
ENV NEXT_PUBLIC_CHAT_URL=${NEXT_PUBLIC_CHAT_URL}

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
