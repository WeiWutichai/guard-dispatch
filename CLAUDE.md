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
- **Web Admin:** Next.js 16 + TypeScript (App Router)
  - Dev: `localhost:3000` ตรง (ไม่มี basePath)
  - Production (Docker/Nginx): basePath `/pguard-app` (ตั้งผ่าน `NEXT_PUBLIC_BASE_PATH`)
- **Mobile App:** Flutter (iOS + Android) — อยู่ใน Monorepo เดียวกัน
  - **State Management:** Provider (`ChangeNotifierProvider`)
  - **HTTP Client:** Dio (with JWT interceptor via `ApiClient`)
  - **Secure Storage:** FlutterSecureStorage (Keychain on iOS, EncryptedSharedPreferences on Android)
  - **Auth Provider:** `AuthProvider` (centralized auth state via Provider)

### Backend (Rust ทั้งหมด)
- **Framework:** Axum 0.8 (ใช้ route syntax `/{id}` ไม่ใช่ `:id`)
- **Async Runtime:** Tokio (latest stable)
- **ORM/Query:** SQLx (latest) + compile-time checked macros เท่านั้น
- **Auth:** JWT (jsonwebtoken crate)
- **Serialization:** Serde + serde_json
- **API Docs:** utoipa 5 + utoipa-swagger-ui 9 (Swagger UI ที่ `/docs` ของแต่ละ service)

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
- ต้อง validate ทั้ง **declared MIME type** และ **magic bytes** ก่อน upload เสมอ
  - JPEG: `FF D8 FF`
  - PNG: `89 50 4E 47 0D 0A 1A 0A`
  - WEBP: `RIFF....WEBP` (bytes 0-3 = `RIFF`, bytes 8-11 = `WEBP`)
- ห้ามเชื่อ Content-Type จาก client เพียงอย่างเดียว — ต้องตรวจ magic bytes ด้วยเสมอ
- ใช้ **Signed URL** เสมอ ห้าม expose bucket โดยตรง
- file_key format: `chat/{chat_id}/{uuid}.{ext}`
- URL หมดอายุ: **1 ชั่วโมง**

### Database & Cache
- ห้าม query ตรงไปที่ PostgreSQL โดยไม่ผ่าน **Connection Pool**
- Connection Pool size: max 20 per service
- ทุก query ที่อ่านบ่อยต้องผ่าน **Redis Cache** ก่อน
- Migration ใช้ `sqlx migrate` เท่านั้น
- **Redis Connection Pattern:** เก็บ `redis::aio::MultiplexedConnection` ใน AppState — ห้ามเรียก `get_multiplexed_tokio_connection()` ทุกครั้งที่ใช้
  - Clone `MultiplexedConnection` สำหรับแต่ละ operation (cheap — shares underlying connection)
- **Cache Update:** ใช้ `SET_EX` (atomic overwrite) แทนการทำ `DEL` แล้ว `SET_EX` แยก
- **Concurrent I/O:** ใช้ `tokio::join!` สำหรับ independent DB/Redis operations (เช่น GPS handler: upsert + history + publish)
- **Performance Indexes:**
  - `booking.guard_requests`: composite `(status, created_at DESC)` สำหรับ list_requests
  - `booking.assignments`: composite `(request_id, guard_id)` สำหรับ is_guard_assigned
- **Query Optimization:** ใช้ `SELECT EXISTS(SELECT 1 ...)` แทน `SELECT COUNT(*)` สำหรับ boolean check (เช่น `is_guard_assigned`)
- **Data Retention:** `tracking.location_history` ต้องมี scheduled cleanup job (pg_cron หรือ external) ลบข้อมูลเก่ากว่า retention period (เช่น 90 วัน)

### Input Validation
- **Email:** ต้องมี `@`, `.`, ความยาวขั้นต่ำ 5 ตัวอักษร — validate ใน `register()` service
- **Phone (Thai format):** ต้องเป็นตัวเลข 10 หลัก ขึ้นต้นด้วย `0` — strip non-digit ก่อน validate
- ทุก input validation ต้อง return `AppError::BadRequest` พร้อมข้อความที่ชัดเจน

### Security
- ทุก API ต้องมี **JWT validation** ยกเว้น `/auth/login` และ `/auth/register`
- Rate limiting ที่ Nginx layer (auth: 5r/s, API: 30r/s, WS: 5r/s)
- ทุก request log เก็บใน `audit` schema
- **JWT Storage:**
  - Web: httpOnly + Secure + SameSite=Lax **cookies** (ห้ามใช้ localStorage เด็ดขาด)
  - Mobile (Flutter): Bearer token ใน Authorization header — เก็บใน `FlutterSecureStorage` เท่านั้น
  - AuthUser extractor อ่านจาก Authorization header ก่อน → fallback ไป cookie
- **JWT Key Caching:** `JwtConfig` เก็บ pre-computed `encoding_key` และ `decoding_key` — ใช้ `encode_jwt_with_key()` / `decode_jwt_with_key()` แทน `encode_jwt()` / `decode_jwt()` ใน production code
  - `HasJwtSecret` trait: `decoding_key()` returns `&DecodingKey` (reference, ไม่ clone) — implement ใน AppState ให้ return `&self.jwt_config.decoding_key`
  - ห้าม return owned `DecodingKey` จาก trait — ต้อง return reference เพื่อ zero-copy performance
- **JWT Validation:** ใช้ explicit `Validation` struct — `validate_exp = true`, iss/aud prepared สำหรับอนาคต (commented-out)
- **Cookie Architecture:**
  - `access_token` → httpOnly, Secure, SameSite=Lax, Path=/
  - `refresh_token` → httpOnly, Secure, SameSite=Lax, Path=/auth
  - `logged_in` → non-httpOnly, **Secure**, SameSite=Lax, marker (ค่า "1") สำหรับ frontend ตรวจสอบ auth state
- **CORS:** ใช้ `shared::config::build_cors_layer()` เท่านั้น — อ่าน origins จาก `CORS_ALLOWED_ORIGINS` env var (comma-separated)
  - ห้ามใช้ `CorsLayer::permissive()` เด็ดขาด
  - Default (dev): `http://localhost:3000`
  - Production ต้องตั้ง `CORS_ALLOWED_ORIGINS` ให้ตรงกับ domain จริง
- **Redis:** ต้องใช้ password authentication (`--requirepass`) ทั้ง cache และ pubsub
  - **Redis URL Logging:** ห้าม log Redis URL ที่มี password เป็น plaintext — ใช้ `redact_redis_url()` ใน `create_redis_client()` เสมอ
- **Network Isolation:** เฉพาะ Nginx expose port 80/443 — ห้าม expose port ของ service/DB/Redis/MinIO ไปยัง host
  - Docker Compose: ใช้ `expose` ไม่ใช่ `ports` สำหรับ internal services (PostgreSQL, Redis, MinIO)
- **Nginx:**
  - Security Headers: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy, Permissions-Policy
  - **Global `client_max_body_size 1m;`** ที่ http block — override เฉพาะ endpoint ที่ต้องการ (เช่น chat attachments: 10m)
  - **Swagger UI rate limiting:** ทุก Swagger location (`/swagger-ui`, `/api-docs`, `/docs`) ต้องมี `limit_req zone=api_limit burst=10 nodelay`
- **WebSocket Auth:** ใช้ cookie (ส่งอัตโนมัติตอน upgrade) — ห้ามส่ง token ใน URL query params
- **WebSocket Data:** ห้ามส่ง conversation_id หรือ sensitive data ใน URL query params — ส่งเป็น message หลัง connection open
- **Audit Middleware:** ต้อง validate JWT signature ด้วย real secret ก่อน trust user_id — ห้ามใช้ `insecure_disable_signature_validation()`
  - ใช้ `middleware::from_fn_with_state(state.clone(), audit_middleware::<Arc<AppState>>)` — ต้อง turbofish type annotation เพราะ `HasJwtSecret` implement ทั้ง `AppState` และ `Arc<T>`
  - **ทุก service ต้องมี audit middleware** — ปัจจุบัน 5 services (auth, booking, tracking, notification, chat) ทั้งหมดมีแล้ว
  - Audit log persist แบบ **fire-and-forget** ผ่าน `tokio::spawn` — ห้าม block response
  - IP address: ใช้ `X-Real-IP` ก่อน → fallback `X-Forwarded-For` rightmost entry
  - **entity_type:** derive จาก URL path segment แรก (เช่น `/auth/login` → `"auth"`, `/booking/requests` → `"booking"`) — ห้ามใช้ HTTP status code เป็น entity_type
- **Password Hashing:** Argon2 ต้อง run ใน `tokio::task::spawn_blocking()` เสมอ — ห้าม block async runtime
- **Login Error Messages:** ห้ามส่ง error ที่เปิดเผยว่า email มีอยู่ในระบบหรือไม่ — ใช้ message เดียวกันสำหรับ wrong password, inactive account, not found
- **Refresh Token Rotation:** ต้องเป็น **atomic** (single `UPDATE ... WHERE refresh_token = $1 RETURNING ...`) — ห้ามทำ SELECT แล้ว UPDATE แยก
- **Session Limit:** จำกัด max **5 sessions ต่อ user** — evict oldest sessions เมื่อเกิน
- **Authorization (IDOR Prevention):**
  - Tracking endpoints: Guards เข้าถึงได้เฉพาะ location ตัวเอง — admins/customers เข้าถึงได้ทุก guard
  - Booking endpoints: `get_request` / `get_assignments` / `cancel_request` / `update_assignment_status` ต้องตรวจว่า user เป็น owner, assigned guard, หรือ admin — ใช้ `is_guard_assigned()` helper (ใช้ `EXISTS` ไม่ใช่ `COUNT(*)`)
  - Chat endpoints: `list_messages` ต้อง pass `user_role` param — admin bypass participant check, non-admin ต้องเป็น participant
  - Chat attachment endpoints: `upload_attachment` / `get_signed_url` ต้องตรวจว่า user เป็น participant ของ conversation หรือเป็น admin — ใช้ `is_conversation_participant_by_conversation()`
  - ห้ามใช้ `_user: AuthUser` (ignore user) ใน endpoint ที่ต้องการ authorization check
- **FCM Config:** `FcmConfig::from_env()` ต้อง **fail-fast** ด้วย `AppError` ถ้า env vars ไม่ได้ตั้ง — ห้าม fallback เป็นค่า default เช่น `"not-set"`
- **Docker Security:**
  - ทุก Dockerfile runtime stage ต้องมี non-root user (`appuser`) — ห้าม run container เป็น root
  - ต้อง `strip` binary ใน runtime stage เพื่อลดขนาด image
  - MinIO credentials ต้องตั้งผ่าน env var — ห้ามใช้ default `minioadmin`
  - Docker Compose ใช้ `${VAR:?error}` syntax เพื่อ require env vars

### Web Admin (Next.js)
- ทุกหน้าใช้ `useLanguage()` hook — ห้าม hardcode ข้อความภาษาไทย/อังกฤษใน component ตรง
- Translations อยู่ใน `lib/i18n.ts` — เพิ่ม key ใหม่ทั้ง `th` และ `en` เสมอ
- ใช้ `cn()` จาก `@/lib/utils` สำหรับ conditional className (clsx + tailwind-merge)
- ใช้ **lucide-react** สำหรับ icons — ห้ามใช้ icon library อื่น
- API calls ต้องผ่าน `lib/api.ts` เท่านั้น — ห้ามเรียก `fetch()` ตรง
- Auth state ใช้ `AuthProvider` (cookie-based) — ห้ามเก็บ JWT ใน localStorage
- Sidebar navigation defined ใน `components/Sidebar.tsx` — array 14 items
- Modal pattern: `fixed inset-0 z-50`, `backdrop-blur-sm`, `animate-in fade-in zoom-in`
- Applicants page ใช้ discriminated union types (`GuardApplicant | CustomerApplicant`) — ห้ามใช้ single generic type

### Flutter Mobile
- **Secure Storage:** ข้อมูล sensitive (JWT tokens, PIN hash) ต้องเก็บใน `FlutterSecureStorage` เท่านั้น — ห้ามใช้ `SharedPreferences` สำหรับ tokens
  - `SharedPreferences` ใช้ได้เฉพาะ non-sensitive data (language pref, registration flags)
- **PIN Security:** Hash PIN ด้วย SHA-256 ก่อนเก็บ — ห้ามเก็บ plaintext PIN
- **API Client:** ใช้ `ApiClient` (Dio-based) ที่มี JWT interceptor อัตโนมัติ — ห้ามเรียก API ตรงโดยไม่ผ่าน interceptor
  - Interceptor ใส่ Bearer token จาก `FlutterSecureStorage` อัตโนมัติ
  - 401 response → auto-refresh token แล้ว retry
  - Skip auth สำหรับ public endpoints (`/auth/login`, `/auth/register`, etc.)
- **State Management:** ใช้ Provider pattern (`ChangeNotifierProvider`) — `AuthProvider` เป็น centralized auth state
  - `main.dart` wrap app ด้วย `MultiProvider`
  - ห้ามเช็ค auth state แยกในแต่ละ screen — ใช้ `context.read<AuthProvider>()` / `context.watch<AuthProvider>()`
- **OTP:** ห้าม hardcode OTP ในโค้ด — ต้องส่งผ่าน API (`AuthService.verifyOtp()`)
- **Bank Account Input:** ใช้ `FilteringTextInputFormatter.digitsOnly`, `maxLength: 15`, ปิด `autocorrect` + `enableSuggestions`

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
│   │   ├── lib/
│   │   │   ├── api.ts          ← Centralized API client (cookie-based auth)
│   │   │   ├── i18n.ts         ← Bilingual translations (TH/EN) + TranslationStructure type
│   │   │   └── utils.ts        ← cn() utility (clsx/tailwind-merge)
│   │   ├── components/
│   │   │   ├── AuthProvider.tsx ← Auth context + cookie-based session
│   │   │   ├── LanguageProvider.tsx ← i18n context (useLanguage hook)
│   │   │   ├── Header.tsx      ← Top bar + search + user menu
│   │   │   ├── Sidebar.tsx     ← Navigation (14 menu items)
│   │   │   └── ThemeProvider.tsx
│   │   └── app/(dashboard)/    ← Dashboard route group (16 pages)
│   │       ├── page.tsx        ← Dashboard overview
│   │       ├── applicants/     ← ผู้สมัคร (Guard + Customer tabs)
│   │       ├── guards/         ← พนักงานรักษาความปลอดภัย (approved guards)
│   │       ├── customers/      ← ลูกค้า (approved customers)
│   │       ├── map/            ← แผนที่สด
│   │       ├── tasks/          ← จัดการงาน
│   │       ├── recruitment/    ← สรรหาบุคลากร
│   │       ├── reviews/        ← รีวิว
│   │       ├── wallet/         ← กระเป๋าเงิน
│   │       ├── pricing/        ← กำหนดราคา
│   │       ├── reports/        ← รายงาน
│   │       ├── automation/     ← กฎอัตโนมัติ
│   │       ├── activity/       ← Activity Log
│   │       ├── settings/       ← ตั้งค่า
│   │       └── profile/        ← โปรไฟล์
│   └── mobile/                 ← Flutter
│       ├── lib/
│       │   ├── main.dart               ← Entry point (MultiProvider wrap)
│       │   ├── providers/
│       │   │   └── auth_provider.dart   ← Centralized auth state (Provider)
│       │   ├── services/
│       │   │   ├── api_client.dart      ← Dio HTTP client + JWT interceptor
│       │   │   ├── auth_service.dart    ← Token storage + login/OTP
│       │   │   ├── pin_storage_service.dart ← PIN hash + FlutterSecureStorage
│       │   │   └── language_service.dart
│       │   ├── screens/                ← 31 screens (guard/customer/common)
│       │   ├── l10n/                   ← Bilingual strings (TH/EN)
│       │   └── theme/                  ← Colors, styles
│       └── pubspec.yaml
└── database/
    └── migrations/             ← SQL files (auto-run by PostgreSQL on init)
```

---

## Web Admin — Page Architecture & Business Logic

### Applicant Flow (ผู้สมัคร → อนุมัติ → แยกเมนู)
```
ผู้ใช้ลงทะเบียน (โทรศัพท์ + OTP)
    │
    ▼
หน้า "ผู้สมัคร" (/applicants)
    ├── Tab: เจ้าหน้าที่ รปภ. (Guard Applicants)
    │     ├── แสดง: ประสบการณ์, เงินเดือน, เอกสาร, ใบประกาศ
    │     └── อนุมัติ → ย้ายไปเมนู "พนักงานรักษาความปลอดภัย" (/guards)
    │
    └── Tab: ผู้เรียก รปภ. (Customer Applicants)
          ├── แสดง: ชื่อบริษัท, วัตถุประสงค์การจอง
          └── อนุมัติ → ย้ายไปเมนู "ลูกค้า" (/customers)
```

### Applicants Page Technical Details
- **Types:** Discriminated union — `GuardApplicant` (type: "guard") | `CustomerApplicant` (type: "customer")
- **Tabs:** 3 tabs (ทั้งหมด / เจ้าหน้าที่ รปภ. / ผู้เรียก รปภ.)
- **Dynamic Columns:** Table columns เปลี่ยนตาม active tab
  - Tab "all": แสดงคอลัมน์ ประเภท + experience + salary
  - Tab "guard": แสดง experience + salary (ไม่มีคอลัมน์ประเภท)
  - Tab "customer": แสดง companyName + bookingPurpose
- **Stats Cards:** Scope ตาม active tab (นับเฉพาะ applicants ในประเภทที่เลือก)
- **Modal:** Content แตกต่างตามประเภท — Guard แสดงเอกสาร/ใบประกาศ/ประวัติ, Customer แสดงบริษัท/วัตถุประสงค์
- **Approved Note:** เมื่อสถานะ approved จะแสดงข้อความว่าไปอยู่เมนูไหน

### Sidebar Navigation Order (14 items)
```
แดชบอร์ด → แผนที่สด → ผู้สมัคร → พนักงานรักษาความปลอดภัย → ลูกค้า →
รีวิว → กระเป๋าเงิน → กำหนดราคา → จัดการงาน → สรรหาบุคลากร →
รายงาน → กฎอัตโนมัติ → Activity Log → ตั้งค่า
```

### i18n Pattern
- ทุกหน้าใช้ `useLanguage()` hook จาก `LanguageProvider`
- `t` object มี nested keys ตาม page (e.g., `t.applicants.tabs.guard`)
- Translation structure defined ใน `lib/i18n.ts` ด้วย `TranslationStructure` type
- รองรับ 2 ภาษา: ไทย (th) และ อังกฤษ (en)

### UI Component Patterns
- **Modal:** `fixed inset-0 z-50`, backdrop-blur-sm, rounded-2xl, animate-in fade-in zoom-in
- **Stats Cards:** `bg-gradient-to-br`, rounded-2xl, hover:shadow-md
- **Table:** bg-white rounded-2xl, hover:bg-slate-50/50 on rows
- **Badge/Pill:** rounded-full, text-xs font-semibold, dot indicator
- **Status Colors:** pending=amber, approved=emerald, rejected=red
- **Type Colors:** guard=amber, customer=blue

---

## Swagger UI (API Documentation)

ทุก Rust service มี Swagger UI ที่ `/docs`:
- **Auth:** `http://localhost:3001/docs`
- **Booking:** `http://localhost:3002/docs`
- **Tracking:** `http://localhost:3003/docs`
- **Notification:** `http://localhost:3004/docs`
- **Chat:** `http://localhost:3006/docs`

### Implementation
- ใช้ `utoipa 5` + `utoipa-swagger-ui 9`
- Security scheme: `SecurityAddon` (Bearer JWT) อยู่ใน `shared::openapi`
- แต่ละ service ใช้ `#[derive(OpenApi)]` + `modifiers(&SecurityAddon)` ใน `main.rs`
- Swagger UI mount ด้วย `SwaggerUi::new("/docs").url("/api-docs/openapi.json", ...)`
- utoipa macro ต้องใช้ `&SimpleIdent` ใน modifiers (ห้ามใช้ path expression เช่น `&shared::openapi::SecurityAddon`)

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
utoipa           = { version = "5", features = ["axum_extras", "uuid", "chrono"] }
utoipa-swagger-ui = { version = "9", features = ["axum"] }
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
CORS_ALLOWED_ORIGINS=http://localhost:3000
RUST_LOG=info
```

> **Note:** Redis ทั้งสอง instance ใช้ internal port 6379 (ไม่ใช่ 6380 สำหรับ pubsub อีกแล้ว)

---

## ข้อห้าม (Do NOT)

### Rust Backend
- ❌ ห้ามแก้ไข `/database/migrations` โดยไม่สร้าง migration ใหม่
- ❌ ห้ามใช้ `.unwrap()` ใน production code
- ❌ ห้าม hardcode credentials ในโค้ด
- ❌ ห้าม run migration โดยตรงบน production database
- ❌ ห้ามส่ง GPS data ผ่าน REST API
- ❌ ห้าม store binary/image ใน PostgreSQL
- ❌ ห้าม expose MinIO/R2 bucket โดยตรง
- ❌ ห้าม accept ไฟล์ที่ไม่ใช่ image/jpeg, image/png, image/webp
- ❌ ห้ามเรียก fetch ตรงใน Frontend — ใช้ `lib/api.ts` (web) หรือ `ApiClient` (mobile) เท่านั้น
- ❌ ห้ามเก็บ JWT ใน localStorage/sessionStorage — ใช้ httpOnly cookie (web) หรือ FlutterSecureStorage (mobile) เท่านั้น
- ❌ ห้ามส่ง JWT token ใน WebSocket URL query params — ใช้ cookie auth
- ❌ ห้าม expose port ของ service/DB/Redis/MinIO ไปยัง host — เฉพาะ Nginx 80/443 — ใช้ `expose` ไม่ใช่ `ports` ใน docker-compose
- ❌ ห้ามเชื่อมต่อ Redis โดยไม่มี password
- ❌ ห้าม validate file upload ด้วย MIME type อย่างเดียว — ต้องตรวจ **magic bytes** ด้วยเสมอ
- ❌ ห้ามใช้ `insecure_disable_signature_validation()` — audit middleware ต้อง validate JWT ด้วย real secret
- ❌ ห้าม log Redis URL ที่มี password เป็น plaintext — ใช้ `redact_redis_url()` redact ก่อน log
- ❌ ห้าม block async runtime ด้วย Argon2 — ต้องใช้ `spawn_blocking()`
- ❌ ห้ามส่ง error message ที่เปิดเผย email existence (เช่น "Account is deactivated")
- ❌ ห้ามทำ refresh token rotation แบบ SELECT → UPDATE แยก — ต้อง atomic single query
- ❌ ห้ามใช้ `_user: AuthUser` (ignore user) ใน endpoint ที่ต้อง authorization check — ต้องตรวจสิทธิ์เสมอ
- ❌ ห้ามส่ง sensitive IDs (conversation_id) ใน WebSocket URL query params — ส่งเป็น message หลัง connect
- ❌ ห้ามเรียก `get_multiplexed_tokio_connection()` ทุก request — เก็บ connection ใน AppState
- ❌ ห้ามทำ `DEL` + `SET_EX` แยก เมื่อ update cache — ใช้ `SET_EX` ตรง (atomic overwrite)
- ❌ ห้าม `.clone()` file data ก้อนใหญ่โดยไม่จำเป็น — capture size ก่อนแล้ว move ownership
- ❌ ห้ามใช้ `CorsLayer::permissive()` — ใช้ `shared::config::build_cors_layer()` ที่อ่านจาก `CORS_ALLOWED_ORIGINS` env var
- ❌ ห้ามสร้าง `EncodingKey`/`DecodingKey` ทุก request — ใช้ cached keys จาก `JwtConfig` (`encode_jwt_with_key()` / `decode_jwt_with_key()`)
- ❌ ห้าม return owned `DecodingKey` จาก `HasJwtSecret::decoding_key()` — ต้อง return `&DecodingKey` (reference)
- ❌ ห้าม run Docker container เป็น root — ทุก Dockerfile ต้องมี `USER appuser` (non-root)
- ❌ ห้ามใช้ MinIO default credentials (`minioadmin`) — ต้องตั้ง `S3_ACCESS_KEY` / `S3_SECRET_KEY` ผ่าน env var
- ❌ ห้ามใช้ `audit_middleware` โดยไม่มี turbofish type — ต้องใช้ `audit_middleware::<Arc<AppState>>` เสมอ
- ❌ ห้ามใช้ HTTP status code เป็น `entity_type` ใน audit log — ต้อง derive จาก URL path segment แรก
- ❌ ห้ามใช้ `COUNT(*)` สำหรับ boolean existence check — ใช้ `EXISTS(SELECT 1 ...)` แทน
- ❌ ห้าม FCM config fallback เป็นค่า default (เช่น `"not-set"`) — ต้อง fail-fast ด้วย `AppError`
- ❌ ห้ามสร้าง service โดยไม่เพิ่ม audit middleware — ทุก service ต้องมี `audit_middleware` layer

### Web Admin (Next.js)
- ❌ ห้าม hardcode ข้อความภาษาในหน้า — ต้องใช้ `t.xxx` จาก `useLanguage()` เสมอ
- ❌ ห้ามเพิ่ม translation เฉพาะภาษาเดียว — ต้องเพิ่มทั้ง `th` และ `en` ใน `lib/i18n.ts`
- ❌ ห้ามใช้ icon library อื่นนอกจาก **lucide-react**
- ❌ ห้ามสร้างหน้าใหม่โดยไม่เพิ่มใน Sidebar navigation (`components/Sidebar.tsx`)
- ❌ ห้ามมี `/members` route — ถูกรวมเข้า `/applicants` แล้ว (ใช้ tabs แบ่ง guard/customer)

### Flutter Mobile
- ❌ ห้ามเก็บ JWT tokens หรือ PIN ใน `SharedPreferences` — ใช้ `FlutterSecureStorage` เท่านั้น
- ❌ ห้ามเก็บ plaintext PIN — ต้อง hash ด้วย SHA-256 ก่อน store
- ❌ ห้าม hardcode OTP ในโค้ด — ต้องส่งผ่าน API (`AuthService.verifyOtp()`)
- ❌ ห้ามเรียก API ตรงโดยไม่ผ่าน `ApiClient` — ต้องใช้ Dio interceptor ที่ attach Bearer token อัตโนมัติ
- ❌ ห้ามเช็ค auth state แยกในแต่ละ screen — ใช้ `AuthProvider` ผ่าน Provider
- ❌ ห้าม navigate ตรงหลัง login โดยไม่ validate credentials กับ backend ก่อน
- ❌ ห้าม expose bank account number ใน UI ที่ไม่จำเป็น — input ต้อง mask, ปิด autocorrect/suggestions
