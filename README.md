# Security Guard Dispatch System

Real-time security guard dispatch platform at city/national scale.
ระบบเรียก รปภ. แบบ Real-time ระดับเมือง/ประเทศ รองรับ GPS Tracking, Push Notification, Video/Audio Call และ Chat พร้อมรูปภาพ

---

## Architecture (สถาปัตยกรรม)

All traffic enters through a single Nginx gateway. Internal services are not exposed to the host network.

```
nginx-gateway (port 80/443 -- single entry point)
├── web-admin                  (Next.js 16, /p-guard-app)
├── rust-auth-service          (Port 3001, /auth/*)
├── rust-booking-service       (Port 3002, /booking/*)
├── rust-tracking-service      (Port 3003, /ws/track + /tracking/*)
├── rust-notification-service  (Port 3004, /notification/*)
├── mediasoup-server           (Port 3005, /call/*) -- Node.js Video/Audio
└── rust-chat-service          (Port 3006, /ws/chat + /chat/*)

postgres-db    (Port 5432) -- Primary Database
redis-cache    (Port 6379) -- Cache Layer
redis-pubsub   (Port 6379) -- GPS + Chat Pub/Sub
minio          (Port 9000) -- Object Storage (Dev) / Cloudflare R2 (Prod)
```

**Total: 12 containers**

---

## Tech Stack (เทคโนโลยีที่ใช้)

| Layer | Technology |
|---|---|
| Web Admin | Next.js 16 + TypeScript (App Router) |
| Mobile App | Flutter (iOS + Android) |
| Backend | Rust + Axum 0.8 (5 microservices) |
| Async Runtime | Tokio |
| ORM / Query | SQLx (compile-time checked macros) |
| Auth | JWT (jsonwebtoken crate) |
| API Documentation | utoipa 5 + utoipa-swagger-ui 9 |
| Primary Database | PostgreSQL 16 |
| Cache | Redis 7 (password-protected) |
| GPS + Chat Pub/Sub | Redis 7 (password-protected, separate instance) |
| File Storage (Dev) | MinIO (S3-compatible) |
| File Storage (Prod) | Cloudflare R2 |
| Video / Audio Call | MediaSoup (Node.js) |
| Reverse Proxy | Nginx 1.27 |
| Containerization | Docker Compose |

---

## Container List (12 Containers)

Only Nginx exposes ports to the host. All other containers are accessible exclusively through the Docker internal network.

| Container | Technology | Internal Port | Exposed to Host |
|---|---|---|---|
| nginx-gateway | Nginx 1.27 | 80 / 443 | Yes (80/443) |
| web-admin | Next.js 16 | 3000 | No |
| rust-auth | Rust + Axum | 3001 | No |
| rust-booking | Rust + Axum | 3002 | No |
| rust-tracking | Rust + Axum + WebSocket | 3003 | No |
| rust-notification | Rust + Axum + FCM | 3004 | No |
| mediasoup-server | Node.js | 3005 | No (UDP 40000-49999 only) |
| rust-chat | Rust + Axum + WebSocket | 3006 | No |
| postgres-db | PostgreSQL 16 | 5432 | No |
| redis-cache | Redis 7 | 6379 | No |
| redis-pubsub | Redis 7 | 6379 | No |
| minio | MinIO | 9000 / 9001 | No |

---

## Quick Start (เริ่มต้นใช้งาน)

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- [Rust](https://rustup.rs/) (latest stable)
- [Node.js](https://nodejs.org/) 20+
- [Flutter](https://flutter.dev/docs/get-started/install) 3.x
- [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli) (`cargo install sqlx-cli`)

### 1. Clone and Configure Environment

```bash
git clone <repo-url>
cd guard-dispatch

cp .env.example .env
# Edit .env with your configuration (database credentials, JWT secret, Redis password, etc.)
```

### 2. Start All Services

```bash
docker compose up -d
```

This starts all 12 containers. The web admin portal is available at `http://localhost/p-guard-app`.

### 3. Run Database Migrations (if developing locally outside Docker)

```bash
export DATABASE_URL=postgresql://guard_user:guard_pass@localhost:5432/guard_dispatch_db
sqlx migrate run --source database/migrations
```

### 4. Flutter Mobile Development

| Device | API URL |
|---|---|
| Android Emulator | `http://10.0.2.2:80` |
| iOS Simulator | `http://localhost:80` |
| Physical Device | `http://<your-LAN-IP>:80` |

```bash
cd frontend/mobile
flutter run --dart-define=API_URL=http://10.0.2.2:80
```

---

## Service Endpoints (through Nginx on localhost)

All services are accessed through the Nginx gateway. Direct access to internal ports is not available from the host.

| Service | REST Endpoints | WebSocket | Swagger UI |
|---|---|---|---|
| Auth | `/auth/*` | -- | `/auth/swagger-ui/` |
| Booking | `/booking/*` | -- | `/booking/swagger-ui/` |
| Tracking | `/tracking/*` | `/ws/track` | `/tracking/swagger-ui/` |
| Notification | `/notification/*` | -- | `/notification/swagger-ui/` |
| Chat | `/chat/*` | `/ws/chat` | `/chat/swagger-ui/` |
| MediaSoup | `/call/*` | -- | -- |
| Web Admin | `/p-guard-app` | -- | -- |

Swagger UI is available for each Rust service during development. Access via `http://localhost/<service>/swagger-ui/`.

---

## Database Schema (โครงสร้างฐานข้อมูล)

The system uses a single PostgreSQL instance with 6 schemas for logical separation:

```
guard_dispatch_db
├── schema: auth         -- users, sessions, roles (ผู้ใช้, เซสชัน, บทบาท)
├── schema: booking      -- requests, assignments, status (คำขอ, การมอบหมาย, สถานะ)
├── schema: tracking     -- locations, history (ตำแหน่ง, ประวัติ GPS)
├── schema: notification -- logs, templates (บันทึกแจ้งเตือน, เทมเพลต)
├── schema: chat         -- messages, attachments metadata (ข้อความ, ไฟล์แนบ)
└── schema: audit        -- all action logs (บันทึกการกระทำทั้งหมด)
```

File attachments (chat images) are stored in MinIO/R2 object storage. PostgreSQL stores only `file_key` and `file_url` references -- binary data is never stored in the database.

---

## Performance Targets (เป้าหมายประสิทธิภาพ)

| Metric | Target |
|---|---|
| Push Notification delivery | < 1 second |
| GPS location update (Critical) | < 3 seconds |
| REST API response | < 200ms |
| Chat message delivery | < 1 second |

---

## Security Summary (ความปลอดภัย)

- **JWT authentication** with httpOnly + Secure + SameSite=Lax cookies (web) and FlutterSecureStorage (mobile)
- **Rate limiting at Nginx layer** -- auth: 5 req/s, API: 30 req/s, WebSocket: 5 req/s per IP
- **Global request body limit** of 1MB at Nginx (overridden to 10MB only for chat attachment uploads)
- **Audit logging on all services** -- every request is logged to the `audit` schema via middleware
- **IDOR prevention** on all endpoints -- ownership and role checks enforced at the service layer
- **Network isolation** -- only Nginx exposes ports to the host; all services, databases, and caches are internal-only
- **Redis password protection** on both cache and pubsub instances
- **Argon2 password hashing** executed in blocking threads to avoid stalling the async runtime
- **Signed URLs** for all file access -- MinIO/R2 buckets are never exposed directly
- **Security headers** via Nginx -- X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy, Permissions-Policy
- **Non-root containers** -- all Docker images run as `appuser`

---

## Project Structure (โครงสร้างโปรเจกต์)

```
guard-dispatch/                         -- Monorepo
├── CLAUDE.md                           -- AI project rules and coding standards
├── README.md                           -- This file
├── Cargo.toml                          -- Rust workspace root (6 members)
├── docker-compose.yml                  -- Development (12 containers)
├── docker-compose.prod.yml             -- Production overrides
├── .env.example                        -- Environment variables template
├── .github/workflows/
│   ├── ci.yml                          -- Build, lint, test
│   └── deploy.yml                      -- Auto-deploy to production
├── nginx/
│   └── nginx.conf                      -- Reverse proxy + security headers + rate limiting
├── services/
│   ├── shared/                         -- Shared library crate (auth, config, error, models)
│   ├── auth/                           -- Rust: JWT Auth Service (port 3001)
│   ├── booking/                        -- Rust: Booking Service (port 3002)
│   ├── tracking/                       -- Rust: GPS Tracking + WebSocket (port 3003)
│   ├── notification/                   -- Rust: FCM Push Notifications (port 3004)
│   ├── chat/                           -- Rust: Chat + WebSocket + MinIO (port 3006)
│   └── mediasoup/                      -- Node.js: Video/Audio Call (port 3005)
├── frontend/
│   ├── web/                            -- Next.js 16 + TypeScript (App Router)
│   └── mobile/                         -- Flutter (iOS + Android)
├── database/
│   └── migrations/                     -- SQL migration files
└── docs/
    ├── pages/                          -- Web admin page documentation
    └── screens/                        -- Mobile screen documentation
```

---

## Docker Commands (คำสั่ง Docker)

```bash
# Start all services (development)
docker compose up -d

# Start with production overrides
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Rebuild a specific service
docker compose build rust-chat && docker compose up rust-chat -d

# View logs for a service
docker compose logs -f rust-chat

# View logs for all services
docker compose logs -f

# Connect to PostgreSQL
docker compose exec postgres-db psql -U guard_user -d guard_dispatch_db

# Connect to Redis cache
docker compose exec redis-cache redis-cli -a "$REDIS_PASSWORD"

# Connect to Redis pubsub
docker compose exec redis-pubsub redis-cli -a "$REDIS_PASSWORD"

# Stop all services
docker compose down

# Stop and remove volumes (full reset)
docker compose down -v
```

---

## Branch Strategy (กลยุทธ์การจัดการ Branch)

| Branch | Purpose |
|---|---|
| `main` | Production -- protected, auto-deploy via GitHub Actions |
| `develop` | Feature integration before merging to main |
| `feature/*` | Individual feature branches |
| `hotfix/*` | Urgent production fixes |

---

## Environment Variables

Key variables required in `.env` (see `.env.example` for the full list):

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_PASSWORD` | Password for both Redis instances |
| `REDIS_CACHE_URL` | Redis cache connection URL (includes password) |
| `REDIS_PUBSUB_URL` | Redis pubsub connection URL (includes password) |
| `JWT_SECRET` | Secret key for JWT signing (min 64 characters) |
| `JWT_EXPIRY_MINUTES` | Access token expiry in minutes (default: 15, OWASP-recommended) |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging server key |
| `FCM_PROJECT_ID` | Firebase project ID |
| `S3_ENDPOINT` | MinIO/R2 endpoint URL |
| `S3_ACCESS_KEY` | Object storage access key |
| `S3_SECRET_KEY` | Object storage secret key |
| `S3_BUCKET` | Bucket name (default: guard-dispatch-files) |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowed origins |
| `RUST_LOG` | Log level (default: info) |

---

## Documentation (เอกสารเพิ่มเติม)

- [Developer Guide](docs/DEVELOPER_GUIDE.md) -- Detailed development setup and coding conventions
- [Web Admin Page Docs](docs/pages/) -- Documentation for each web admin dashboard page
- [Mobile Screen Docs](docs/screens/) -- Documentation for each Flutter mobile screen
- [AI Project Rules](CLAUDE.md) -- Complete coding rules, architecture details, and constraints

---

## License

This project is proprietary software. All rights reserved.
