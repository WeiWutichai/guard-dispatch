# 🛡️ Security Guard Dispatch System (ระบบเรียก รปภ.)

ระบบเรียก รปภ. แบบ Real-time ระดับเมือง/ประเทศ รองรับ GPS Tracking, Push Notification และ Video/Audio Call

---

## 📐 Architecture

```
nginx-gateway (80/443)
├── rust-auth-service          (Port 3001) — JWT Authentication
├── rust-booking-service       (Port 3002) — Request & Assignment
├── rust-tracking-service      (Port 3003) — GPS via WebSocket
├── rust-notification-service  (Port 3004) — FCM Push Notifications
└── mediasoup-server           (Port 3005) — Video/Audio Call (Node.js)

postgres-db    (Port 5432) — Primary Database
redis-cache    (Port 6379) — Cache Layer
redis-pubsub   (Port 6380) — GPS Pub/Sub
```

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Web Admin | React + TypeScript + Vite |
| Mobile App | Flutter (iOS + Android) |
| Backend | Rust + Axum 0.8 |
| Async Runtime | Tokio |
| ORM | SQLx (compile-time macros) |
| Auth | JWT (jsonwebtoken) |
| Primary DB | PostgreSQL 16 |
| Cache | Redis 7 |
| GPS Pub/Sub | Redis 7 |
| Video/Audio | MediaSoup (Node.js) |
| Reverse Proxy | Nginx |
| Containerization | Docker Compose |

---

## 📁 Project Structure

```
/
├── CLAUDE.md                        ← Project rules & guidelines
├── Cargo.toml                       ← Rust workspace root
├── docker-compose.yml               ← All containers
├── .env.example                     ← Environment variables template
├── nginx/
│   └── nginx.conf                   ← Reverse proxy config
├── services/
│   ├── auth/                        ← Rust: JWT Auth Service (3001)
│   │   ├── Cargo.toml
│   │   └── src/
│   ├── booking/                     ← Rust: Booking Service (3002)
│   │   ├── Cargo.toml
│   │   └── src/
│   ├── tracking/                    ← Rust: GPS Tracking + WebSocket (3003)
│   │   ├── Cargo.toml
│   │   └── src/
│   ├── notification/                ← Rust: FCM Notification Service (3004)
│   │   ├── Cargo.toml
│   │   └── src/
│   └── mediasoup/                   ← Node.js: Video/Audio Call (3005)
│       └── src/
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
- [Node.js](https://nodejs.org/) 20+ (for mediasoup)
- [Flutter](https://flutter.dev/docs/get-started/install) 3.x
- [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli)

### 1. Clone & Setup Environment

```bash
git clone <repo-url>
cd guard-dispatch

cp .env.example .env
# แก้ไข .env ตามต้องการ
```

### 2. Start Infrastructure (Database + Redis)

```bash
docker compose up postgres-db redis-cache redis-pubsub -d
```

### 3. Run Database Migrations

```bash
export DATABASE_URL=postgresql://guard_user:guard_pass@localhost:5432/guard_dispatch_db
sqlx migrate run --source database/migrations
```

### 4. Start All Services

```bash
# Start everything
docker compose up -d

# หรือ start เฉพาะ services ที่ต้องการ
docker compose up nginx-gateway rust-auth rust-booking -d
```

### 5. Verify Services

```bash
# Check all containers
docker compose ps

# Check logs
docker compose logs -f rust-auth
docker compose logs -f rust-booking
```

---

## 🔌 Service Endpoints

| Service | URL | Description |
|---|---|---|
| Auth | `http://localhost:3001` | Login, Register, Token refresh |
| Booking | `http://localhost:3002` | Create/manage guard requests |
| Tracking | `ws://localhost:3003` | GPS WebSocket stream |
| Notification | `http://localhost:3004` | Push notification triggers |
| MediaSoup | `http://localhost:3005` | Video/Audio call signaling |

---

## 🗄️ Database Schema

```
guard_dispatch_db
├── schema: auth         — users, sessions, roles
├── schema: booking      — requests, assignments, status
├── schema: tracking     — locations, history
├── schema: notification — logs, templates
└── schema: audit        — all action logs
```

---

## ⚡ Performance Targets

| Metric | Target |
|---|---|
| Push Notification | < 1 second |
| GPS Update | < 3 seconds (Critical) |
| API Response | < 200ms |

---

## 🔒 Security Rules

- ทุก API ต้องมี JWT validation ยกเว้น `/auth/login` และ `/auth/register`
- Rate limiting ที่ Nginx layer
- ทุก request log เก็บใน `audit` schema
- ห้าม hardcode credentials ในโค้ด

---

## 📋 Development Rules

ดูรายละเอียดทั้งหมดใน [CLAUDE.md](./CLAUDE.md)

---

## 🐳 Docker Compose Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Rebuild specific service
docker compose build rust-auth
docker compose up rust-auth -d

# View logs
docker compose logs -f [service-name]

# Shell into container
docker compose exec postgres-db psql -U guard_user -d guard_dispatch_db
docker compose exec redis-cache redis-cli
```
