# 🛡️ Security Guard Dispatch System (ระบบเรียก รปภ.)

ระบบเรียก รปภ. แบบ Real-time ระดับเมือง/ประเทศ รองรับ GPS Tracking, Push Notification, Video/Audio Call และ **Chat พร้อมรูปภาพ**

---

## 📐 Architecture

```
nginx-gateway (80/443)
├── rust-auth-service          (Port 3001) — JWT Authentication
├── rust-booking-service       (Port 3002) — Request & Assignment
├── rust-tracking-service      (Port 3003) — GPS via WebSocket
├── rust-notification-service  (Port 3004) — FCM Push Notifications
├── mediasoup-server           (Port 3005) — Video/Audio Call (Node.js)
└── rust-chat-service          (Port 3006) — WebSocket Chat + Image Upload

postgres-db    (Port 5432) — Primary Database
redis-cache    (Port 6379) — Cache Layer
redis-pubsub   (Port 6380) — GPS + Chat Pub/Sub
minio          (Port 9000) — Object Storage (Dev) | Cloudflare R2 (Prod)
```

**Total: 11 containers**

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Web Admin | React + TypeScript + Vite |
| Mobile App | Flutter (iOS + Android) |
| Backend | Rust + Axum 0.8 |
| Async Runtime | Tokio |
| ORM | SQLx (compile-time macros only) |
| Auth | JWT (jsonwebtoken) |
| Primary DB | PostgreSQL 16 |
| Cache | Redis 7 |
| GPS + Chat Pub/Sub | Redis 7 |
| File Storage (Dev) | MinIO (S3-compatible) |
| File Storage (Prod) | Cloudflare R2 |
| Video/Audio | MediaSoup (Node.js) |
| Reverse Proxy | Nginx |
| Containerization | Docker Compose |

---

## 📁 Project Structure

```
guard-dispatch/                      ← Monorepo
├── CLAUDE.md                        ← Project rules (AI reads first)
├── Cargo.toml                       ← Rust workspace root
├── docker-compose.yml               ← Development (11 containers)
├── docker-compose.prod.yml          ← Production overrides
├── .env.example                     ← Environment variables template
├── .github/
│   └── workflows/
│       ├── ci.yml                   ← Build, lint, test
│       └── deploy.yml               ← Auto-deploy to production
├── nginx/
│   └── nginx.conf                   ← Reverse proxy + rate limiting
├── services/
│   ├── auth/                        ← Rust: JWT Auth Service (3001)
│   ├── booking/                     ← Rust: Booking Service (3002)
│   ├── tracking/                    ← Rust: GPS Tracking + WebSocket (3003)
│   ├── notification/                ← Rust: FCM Notification Service (3004)
│   ├── chat/                        ← Rust: Chat + WebSocket + MinIO (3006)
│   └── mediasoup/                   ← Node.js: Video/Audio Call (3005)
├── frontend/
│   ├── web/                         ← React + TypeScript + Vite
│   └── mobile/                      ← Flutter (iOS + Android)
└── database/
    └── migrations/                  ← SQLx migrations
```

---

## 🚀 Getting Started (Local Development)

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/)
- [Rust](https://rustup.rs/) (latest stable)
- [Node.js](https://nodejs.org/) 20+
- [Flutter](https://flutter.dev/docs/get-started/install) 3.x
- [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli)

### 1. Clone & Setup Environment

```bash
git clone <repo-url>
cd guard-dispatch

cp .env.example .env
# แก้ไข .env ตามต้องการ
```

### 2. Start Infrastructure (Database + Redis + MinIO)

```bash
docker compose up postgres-db redis-cache redis-pubsub minio -d
```

### 3. Create MinIO Bucket

```bash
# เข้า MinIO Console: http://localhost:9001
# user: minioadmin / pass: minioadmin
# สร้าง bucket ชื่อ: guard-dispatch-files
```

### 4. Run Database Migrations

```bash
export DATABASE_URL=postgresql://guard_user:guard_pass@localhost:5432/guard_dispatch_db
sqlx migrate run --source database/migrations
```

### 5. Start All Services

```bash
# Start everything
docker compose up -d

# หรือ start เฉพาะ service ที่ต้องการ
docker compose up nginx-gateway rust-auth rust-booking rust-chat -d
```

### 6. Flutter Mobile Development

| Device | API URL |
|---|---|
| Android Emulator | `http://10.0.2.2:80` |
| iOS Simulator | `http://localhost:80` |
| Physical Device | `http://<LAN IP>:80` |

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:80
```

---

## 🔌 Service Endpoints

| Service | URL | Protocol |
|---|---|---|
| Auth | `http://localhost:3001` | REST |
| Booking | `http://localhost:3002` | REST |
| Tracking | `ws://localhost:3003/ws/track` | WebSocket |
| Notification | `http://localhost:3004` | REST |
| MediaSoup | `http://localhost:3005` | REST + WS |
| Chat | `ws://localhost:3006/ws/chat` | WebSocket |
| Chat Attachments | `http://localhost:3006/chat/attachments` | REST (multipart) |
| MinIO Console | `http://localhost:9001` | Web UI |

---

## 🗄️ Database Schema

```
guard_dispatch_db
├── schema: auth         — users, sessions, roles
├── schema: booking      — requests, assignments, status
├── schema: tracking     — locations, history
├── schema: notification — logs, templates
├── schema: chat         — messages, attachments metadata
└── schema: audit        — all action logs
```

### Chat Attachments Rule

```
file_key format : chat/{chat_id}/{uuid}.{ext}
Signed URL expiry: 1 hour
Allowed formats  : JPEG, PNG, WEBP (max 10MB per file)
Rule             : NEVER store binary in PostgreSQL — store file_key + file_url only
```

---

## ⚡ Performance Targets

| Metric | Target |
|---|---|
| Push Notification | < 1 second |
| GPS Update | < 3 seconds (Critical) |
| API Response | < 200ms |
| Chat Message Delivery | < 1 second |

---

## 🔒 Security Rules

- ทุก API ต้องมี JWT validation ยกเว้น `/auth/login` และ `/auth/register`
- Rate limiting ที่ Nginx layer (`client_max_body_size 10m` สำหรับ chat uploads)
- ทุก request log เก็บใน `audit` schema
- ห้าม hardcode credentials ในโค้ด
- ห้าม expose MinIO/R2 bucket โดยตรง — ใช้ Signed URL เท่านั้น

---

## 🐳 Docker Compose Commands

```bash
# Start all (development)
docker compose up -d

# Start production mode
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Rebuild specific service
docker compose build rust-chat && docker compose up rust-chat -d

# View logs
docker compose logs -f rust-chat

# Shell into containers
docker compose exec postgres-db psql -U guard_user -d guard_dispatch_db
docker compose exec redis-cache redis-cli
docker compose exec minio mc ls local/guard-dispatch-files
```

---

## 🌿 Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Production (protected, auto-deploy via deploy.yml) |
| `develop` | Feature integration |
| `feature/*` | Individual features |
| `hotfix/*` | Urgent production fixes |

---

## 📋 Development Rules

ดูรายละเอียดทั้งหมดใน [CLAUDE.md](./CLAUDE.md)
