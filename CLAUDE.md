# Security Guard Dispatch System (ระบบเรียก รปภ.)

## Project Overview
ระบบเรียก รปภ. แบบ Real-time ระดับเมือง/ประเทศ รองรับ GPS Tracking, Push Notification, Video/Audio Call และ Chat พร้อมรูปภาพ

---

## Repository
- **Repo:** 1 Repo (Monorepo) ชื่อ `guard-dispatch`
- **Branch Strategy:**
  - `main` → Production (auto deploy, protected)
  - `develop` → รวม feature ก่อน merge
  - `feature/*` → งานแต่ละชิ้น
  - `hotfix/*` → แก้ด่วน

---

## Tech Stack

### Frontend
- **Web Admin:** Next.js 16 + TypeScript (App Router, basePath `/pguard-app`)
- **Mobile App:** Flutter (iOS + Android) — อยู่ใน Monorepo เดียวกัน

### Backend (Rust ทั้งหมด)
- **Framework:** Axum 0.8 (ใช้ route syntax `/{id}` ไม่ใช่ `:id`)
- **Async Runtime:** Tokio (latest stable)
- **ORM/Query:** SQLx (latest) + compile-time checked macros เท่านั้น
- **Auth:** JWT (jsonwebtoken crate)
- **Serialization:** Serde + serde_json

### Database & Cache
- **Primary DB:** PostgreSQL (1 instance ใช้ร่วมกัน)
- **Cache:** Redis (2 instances — หนึ่งสำหรับ Cache, หนึ่งสำหรับ Pub/Sub GPS) — **password-protected**

### File Storage
- **Development:** MinIO (self-hosted, Docker container)
- **Production:** Cloudflare R2
- **กฎ:** ห้าม store binary ใน PostgreSQL เด็ดขาด — เก็บแค่ URL/file_key เท่านั้น

### Real-time & Notifications
- **WebSocket:** Axum ws feature (GPS Tracking + Chat)
- **Push Notification:** Firebase FCM
- **Video/Audio Call:** MediaSoup (Node.js) — ข้อยกเว้นเดียวที่ไม่ใช่ Rust

### Infrastructure
- **Reverse Proxy:** Nginx (SSL + Load Balancer)
- **Containerization:** Docker + Docker Compose
- **Container Orchestration (อนาคต):** Kubernetes

---

## Architecture — Microservices

```
nginx-gateway (port 80/443 — จุดเข้าเดียว)
├── web-admin                  (Next.js 16, /pguard-app)
├── rust-auth-service          (Port 3001, /auth/*)
├── rust-booking-service       (Port 3002, /booking/*)
├── rust-tracking-service      (Port 3003, /ws/track + /tracking/*)
├── rust-notification-service  (Port 3004, /notification/*)
├── mediasoup-server           (Port 3005, /call/*) ← Node.js Video/Audio
└── rust-chat-service          (Port 3006, /ws/chat + /chat/*)
```

---

## Container List (12 Containers)

> **Security:** เฉพาะ Nginx เท่านั้นที่ expose port ไปยัง host (80/443)
> Service อื่นทั้งหมดเข้าถึงได้เฉพาะผ่าน Docker internal network

| Container | Technology | Internal Port | Exposed to Host |
|---|---|---|---|
| nginx-gateway | Nginx | 80 / 443 | ✅ 80/443 |
| web-admin | Next.js 16 | 3000 | ❌ |
| rust-auth | Rust + Axum | 3001 | ❌ |
| rust-booking | Rust + Axum | 3002 | ❌ |
| rust-tracking | Rust + Axum + WebSocket | 3003 | ❌ |
| rust-notification | Rust + Axum + FCM | 3004 | ❌ |
| mediasoup-server | Node.js | 3005 | ❌ (UDP 40000-49999 only) |
| rust-chat | Rust + Axum + WebSocket | 3006 | ❌ |
| postgres-db | PostgreSQL | 5432 | ❌ |
| redis-cache | Redis (password-protected) | 6379 | ❌ |
| redis-pubsub | Redis (password-protected) | 6379 | ❌ |
| minio | MinIO (Object Storage) | 9000/9001 | ❌ |

---

## Database Schema Structure

```
PostgreSQL: guard_dispatch_db
├── schema: auth         (users, sessions, roles)
├── schema: booking      (requests, assignments, status)
├── schema: tracking     (locations, history)
├── schema: notification (logs, templates)
├── schema: chat         (messages, attachments metadata)
└── schema: audit        (logs ทุก action)
```

### Chat Attachments Table
```sql
CREATE TABLE chat.attachments (
  id          UUID PRIMARY KEY,
  chat_id     UUID NOT NULL,
  uploader_id UUID NOT NULL,
  file_key    TEXT NOT NULL,
  file_url    TEXT NOT NULL,
  file_size   INT,
  mime_type   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Coding Rules — MUST FOLLOW

### Rust
- ใช้ **Axum 0.8** เสมอ — route syntax: `/{id}` ไม่ใช่ `:id`
- ทุก dependency ต้องเป็น **latest stable version**
- ทุก endpoint ต้องมี **error handling** ด้วย `Result<T, AppError>`
- ใช้ **SQLx compile-time macros** เท่านั้น (`query!`, `query_as!`) ห้ามใช้ raw string query
- ทุก Service ต้องเป็น **Stateless** — ห้ามเก็บ session ใน memory
- Session และ state ทั้งหมดเก็บใน **Redis**
- GPS data ส่งผ่าน **WebSocket เท่านั้น** ห้ามใช้ REST polling

### File Upload
- ขนาดไฟล์สูงสุด: **10MB ต่อไฟล์**
- Format ที่รับ: **JPEG, PNG, WEBP เท่านั้น**
- ต้อง validate mime_type ก่อน upload เสมอ
- ใช้ **Signed URL** เสมอ ห้าม expose bucket โดยตรง
- file_key format: `chat/{chat_id}/{uuid}.{ext}`
- URL หมดอายุ: **1 ชั่วโมง**

### Database
- ห้าม query ตรงไปที่ PostgreSQL โดยไม่ผ่าน **Connection Pool**
- Connection Pool size: max 20 per service
- ทุก query ที่อ่านบ่อยต้องผ่าน **Redis Cache** ก่อน
- Migration ใช้ `sqlx migrate` เท่านั้น

### Security
- ทุก API ต้องมี **JWT validation** ยกเว้น `/auth/login` และ `/auth/register`
- Rate limiting ที่ Nginx layer (auth: 5r/s, API: 30r/s, WS: 5r/s)
- ทุก request log เก็บใน `audit` schema
- **JWT Storage:**
  - Web: httpOnly + Secure + SameSite=Lax **cookies** (ห้ามใช้ localStorage เด็ดขาด)
  - Mobile (Flutter): Bearer token ใน Authorization header
  - AuthUser extractor อ่านจาก Authorization header ก่อน → fallback ไป cookie
- **Cookie Architecture:**
  - `access_token` → httpOnly, Secure, SameSite=Lax, Path=/
  - `refresh_token` → httpOnly, Secure, SameSite=Lax, Path=/auth
  - `logged_in` → non-httpOnly marker (ค่า "1") สำหรับ frontend ตรวจสอบ auth state
- **Redis:** ต้องใช้ password authentication (`--requirepass`) ทั้ง cache และ pubsub
- **Network Isolation:** เฉพาะ Nginx expose port 80/443 — ห้าม expose port ของ service/DB/Redis/MinIO ไปยัง host
- **Nginx Security Headers:** X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy, Permissions-Policy
- **WebSocket Auth:** ใช้ cookie (ส่งอัตโนมัติตอน upgrade) — ห้ามส่ง token ใน URL query params

### Performance Target
- Push notification: **< 1 วินาที**
- GPS update: **< 3 วินาที** (Critical)
- API response: **< 200ms**
- Chat message delivery: **< 1 วินาที**

---

## Project Structure

```
guard-dispatch/                 ← Monorepo (1 Repo)
├── CLAUDE.md                   ← ไฟล์นี้ (AI อ่านก่อนเสมอ)
├── Cargo.toml                  ← Workspace root (6 members)
├── docker-compose.yml
├── docker-compose.prod.yml
├── .env.example
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── .claude/
│   ├── settings.json           ← Claude Code hooks config
│   ├── hooks/
│   │   ├── pre-tool.sh         ← Block destructive commands
│   │   └── post-edit.sh        ← Auto fmt + clippy + unwrap check
│   └── skills/
│       ├── pr-review.md        ← PR review checklist
│       ├── websocket.md        ← WebSocket patterns
│       └── ...
├── nginx/
│   └── nginx.conf              ← Security headers + rate limiting
├── services/
│   ├── shared/                 ← Shared library crate (auth, config, error, models)
│   ├── auth/                   ← Rust (JWT + cookies + argon2)
│   ├── booking/                ← Rust
│   ├── tracking/               ← Rust + WebSocket GPS
│   ├── notification/           ← Rust + FCM
│   ├── chat/                   ← Rust + WebSocket + MinIO
│   └── mediasoup/              ← Node.js
├── frontend/
│   ├── web/                    ← Next.js 16 + TypeScript (App Router)
│   │   ├── lib/api.ts          ← Centralized API client (cookie-based auth)
│   │   └── components/AuthProvider.tsx
│   └── mobile/                 ← Flutter
└── database/
    └── migrations/             ← SQL files (auto-run by PostgreSQL on init)
```

---

## Flutter Local Development

| Device | API URL |
|---|---|
| Android Emulator | `http://10.0.2.2:80` |
| iOS Simulator | `http://localhost:80` |
| Physical Device | `http://<LAN IP>:80` |

```bash
docker compose up
flutter run --dart-define=API_URL=http://10.0.2.2:80
```

---

## Antigravity IDE Setup

Antigravity คือ Agentic IDE จาก Google (คล้าย Cursor/Windsurf) ใช้ร่วมกับโปรเจกต์นี้ได้

### การ Setup
1. Download: https://antigravity.google
2. Clone repo: `git clone <repo-url>`
3. Open folder `guard-dispatch` ใน Antigravity
4. Antigravity จะอ่าน CLAUDE.md นี้อัตโนมัติ
5. เลือก Model: **Claude Sonnet** (แนะนำสำหรับ Rust)

### MCP Servers ที่ควรติดตั้ง
```
MCP Store → ค้นหาและติดตั้ง:
- PostgreSQL / AlloyDB     ← query DB ตรงจาก IDE
- GitHub                   ← จัดการ PR/Issues
- Docker                   ← ดู container status
```

### วิธีใช้ให้ได้ประสิทธิภาพสูงสุด
- ใช้ **Planning Mode** สำหรับงานซับซ้อน (สร้าง service ใหม่)
- ใช้ **Fast Mode** สำหรับงานเล็ก (แก้ bug, เพิ่ม endpoint)
- สั่งทีละ Service ไม่ใช่ทั้งระบบพร้อมกัน
- Review Rust ownership/lifetime ทุกครั้งก่อน commit

### ข้อควรระวังใน Antigravity
- ตรวจสอบ Axum version ในโค้ดที่ generate เสมอ (ต้องเป็น 0.8)
- อย่า accept code ที่ใช้ `.unwrap()` โดยไม่มี error handling
- Antigravity ไม่ deploy อัตโนมัติ — ต้อง push ผ่าน GitHub CI/CD เอง

---

## Cargo.toml — Workspace Dependencies

ใช้ `[workspace.dependencies]` ใน root `Cargo.toml` แล้ว inherit ในแต่ละ service:

```toml
# Root Cargo.toml
[workspace]
members = ["services/shared", "services/auth", "services/booking",
           "services/tracking", "services/notification", "services/chat"]

[workspace.dependencies]
axum            = { version = "0.8", features = ["ws", "multipart"] }
tokio           = { version = "1", features = ["full"] }
sqlx            = { version = "0.8", features = ["runtime-tokio-rustls", "postgres", "uuid", "chrono"] }
redis           = { version = "0.27", features = ["tokio-comp"] }
serde           = { version = "1", features = ["derive"] }
serde_json      = "1"
jsonwebtoken    = "9"
uuid            = { version = "1", features = ["v4"] }
chrono          = { version = "0.4", features = ["serde"] }
tower           = "0.5"
tower-http      = { version = "0.6", features = ["cors", "trace"] }
tracing         = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
thiserror       = "2"
anyhow          = "1"
dotenvy         = "0.15"
aws-sdk-s3      = "1"
bytes           = "1"
reqwest         = { version = "0.12", features = ["json", "rustls-tls"], default-features = false }
argon2          = "0.5"
shared          = { path = "services/shared" }
```

แต่ละ service ใช้: `axum = { workspace = true }`

---

## Environment Variables

```env
DATABASE_URL=postgresql://user:pass@postgres-db:5432/guard_dispatch_db
REDIS_PASSWORD=<strong-redis-password>
REDIS_CACHE_URL=redis://:${REDIS_PASSWORD}@redis-cache:6379
REDIS_PUBSUB_URL=redis://:${REDIS_PASSWORD}@redis-pubsub:6379
JWT_SECRET=<strong-secret-at-least-64-chars>
JWT_EXPIRY_HOURS=24
FCM_SERVER_KEY=<firebase-key>
FCM_PROJECT_ID=<firebase-project-id>
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=<access-key>
S3_SECRET_KEY=<secret-key>
S3_BUCKET=guard-dispatch-files
RUST_LOG=info
```

> **Note:** Redis ทั้งสอง instance ใช้ internal port 6379 (ไม่ใช่ 6380 สำหรับ pubsub อีกแล้ว)

---

## ข้อห้าม (Do NOT)
- ❌ ห้ามแก้ไข `/database/migrations` โดยไม่สร้าง migration ใหม่
- ❌ ห้ามใช้ `.unwrap()` ใน production code
- ❌ ห้าม hardcode credentials ในโค้ด
- ❌ ห้าม run migration โดยตรงบน production database
- ❌ ห้ามส่ง GPS data ผ่าน REST API
- ❌ ห้าม store binary/image ใน PostgreSQL
- ❌ ห้าม expose MinIO/R2 bucket โดยตรง
- ❌ ห้าม accept ไฟล์ที่ไม่ใช่ image/jpeg, image/png, image/webp
- ❌ ห้ามเรียก fetch ตรงใน Frontend — ใช้ `lib/api.ts` เท่านั้น
- ❌ ห้ามเก็บ JWT ใน localStorage/sessionStorage — ใช้ httpOnly cookie เท่านั้น
- ❌ ห้ามส่ง JWT token ใน WebSocket URL query params — ใช้ cookie auth
- ❌ ห้าม expose port ของ service/DB/Redis/MinIO ไปยัง host — เฉพาะ Nginx 80/443
- ❌ ห้ามเชื่อมต่อ Redis โดยไม่มี password
