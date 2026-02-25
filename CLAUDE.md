# Security Guard Dispatch System (ระบบเรียก รปภ.)

## Project Overview
ระบบเรียก รปภ. แบบ Real-time ระดับเมือง/ประเทศ รองรับ GPS Tracking, Push Notification และ Video/Audio Call

---

## Tech Stack

### Frontend
- **Web Admin:** React + TypeScript + Vite
- **Mobile App:** Flutter (iOS + Android)

### Backend (Rust ทั้งหมด)
- **Framework:** Axum 0.8 (ใช้ route syntax `/{id}` ไม่ใช่ `:id`)
- **Async Runtime:** Tokio (latest stable)
- **ORM/Query:** SQLx (latest) + compile-time checked macros เท่านั้น
- **Auth:** JWT (jsonwebtoken crate)
- **Serialization:** Serde + serde_json

### Database & Cache
- **Primary DB:** PostgreSQL (1 instance ใช้ร่วมกัน)
- **Cache:** Redis (2 instances — หนึ่งสำหรับ Cache, หนึ่งสำหรับ Pub/Sub GPS)

### Real-time & Notifications
- **WebSocket:** Axum ws feature (GPS Tracking)
- **Push Notification:** Firebase FCM
- **Video/Audio Call:** MediaSoup (Node.js) — ข้อยกเว้นเดียวที่ไม่ใช่ Rust

### Infrastructure
- **Reverse Proxy:** Nginx (SSL + Load Balancer)
- **Containerization:** Docker + Docker Compose
- **Container Orchestration (อนาคต):** Kubernetes

---

## Architecture — Microservices

```
nginx-gateway
├── rust-auth-service          (Port 3001)
├── rust-booking-service       (Port 3002)
├── rust-tracking-service      (Port 3003) ← WebSocket
├── rust-notification-service  (Port 3004)
└── mediasoup-server           (Port 3005) ← Node.js
```

---

## Container List (9 Containers)

| Container | Technology | Port |
|---|---|---|
| nginx-gateway | Nginx | 80 / 443 |
| rust-auth | Rust + Axum | 3001 |
| rust-booking | Rust + Axum | 3002 |
| rust-tracking | Rust + Axum + WebSocket | 3003 |
| rust-notification | Rust + Axum + FCM | 3004 |
| mediasoup-server | Node.js | 3005 |
| postgres-db | PostgreSQL | 5432 |
| redis-cache | Redis | 6379 |
| redis-pubsub | Redis | 6380 |

---

## Database Schema Structure

```
PostgreSQL: guard_dispatch_db
├── schema: auth        (users, sessions, roles)
├── schema: booking     (requests, assignments, status)
├── schema: tracking    (locations, history)
├── schema: notification (logs, templates)
└── schema: audit       (logs ทุก action)
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

### Database
- ห้าม query ตรงไปที่ PostgreSQL โดยไม่ผ่าน **Connection Pool**
- Connection Pool size: max 20 per service
- ทุก query ที่อ่านบ่อยต้องผ่าน **Redis Cache** ก่อน
- Migration ใช้ `sqlx migrate` เท่านั้น

### Security
- ทุก API ต้องมี **JWT validation** ยกเว้น `/auth/login` และ `/auth/register`
- Rate limiting ที่ Nginx layer
- ทุก request log เก็บใน `audit` schema

### Performance Target
- Push notification: **< 1 วินาที**
- GPS update: **< 3 วินาที** (Critical)
- API response: **< 200ms**

---

## Project Structure

```
/
├── CLAUDE.md                  ← ไฟล์นี้
├── docker-compose.yml
├── nginx/
│   └── nginx.conf
├── services/
│   ├── auth/                  ← Rust
│   │   ├── Cargo.toml
│   │   └── src/
│   ├── booking/               ← Rust
│   ├── tracking/              ← Rust + WebSocket
│   ├── notification/          ← Rust + FCM
│   └── mediasoup/             ← Node.js (Video/Audio)
├── frontend/
│   ├── web/                   ← React + TypeScript
│   └── mobile/                ← Flutter
└── database/
    └── migrations/
```

---

## Cargo.toml Dependencies Template

```toml
[dependencies]
axum = { version = "0.8", features = ["ws"] }
tokio = { version = "1", features = ["full"] }
sqlx = { version = "0.8", features = ["runtime-tokio-rustls", "postgres", "uuid", "chrono"] }
redis = { version = "0.27", features = ["tokio-comp"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
jsonwebtoken = "9"
uuid = { version = "1", features = ["v4"] }
chrono = { version = "0.4", features = ["serde"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace"] }
tracing = "0.1"
tracing-subscriber = "0.3"
```

---

## Environment Variables

```env
DATABASE_URL=postgresql://user:pass@postgres-db:5432/guard_dispatch_db
REDIS_CACHE_URL=redis://redis-cache:6379
REDIS_PUBSUB_URL=redis://redis-pubsub:6380
JWT_SECRET=<strong-secret>
FCM_SERVER_KEY=<firebase-key>
RUST_LOG=info
```

---

## ข้อห้าม (Do NOT)
- ❌ ห้ามแก้ไข `/database/migrations` โดยไม่สร้าง migration ใหม่
- ❌ ห้ามใช้ `.unwrap()` ใน production code — ใช้ `?` หรือ proper error handling
- ❌ ห้าม hardcode credentials ในโค้ด
- ❌ ห้าม run migration โดยตรงบน production database
- ❌ ห้ามส่ง GPS data ผ่าน REST API
