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

# basePath baked into the build. Next.js needs this at BUILD time (not runtime)
# because asset URLs and router paths are generated at build. The default
# matches nginx.prod.conf's /p-guard-app location (note the dash).
# Override via: docker compose build --build-arg NEXT_PUBLIC_BASE_PATH=/your-path
ARG NEXT_PUBLIC_BASE_PATH=/p-guard-app
ENV NEXT_PUBLIC_BASE_PATH=${NEXT_PUBLIC_BASE_PATH}

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
