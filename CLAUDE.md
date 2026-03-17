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
  - **Map:** react-leaflet + leaflet (OpenStreetMap tiles — ต้องเปลี่ยนเป็น commercial tile provider สำหรับ production)
- **Mobile App:** Flutter (iOS + Android) — อยู่ใน Monorepo เดียวกัน
  - **State Management:** Provider (`ChangeNotifierProvider`)
  - **HTTP Client:** Dio (with JWT interceptor via `ApiClient`)
  - **Secure Storage:** FlutterSecureStorage (Keychain on iOS, EncryptedSharedPreferences on Android)
  - **Auth Provider:** `AuthProvider` (centralized auth state via Provider)
  - **Map:** flutter_map + latlong2 + geolocator

### Backend (Rust ทั้งหมด)
- **Framework:** Axum 0.8 (ใช้ route syntax `/{id}` ไม่ใช่ `:id`)
- **Async Runtime:** Tokio (latest stable)
- **ORM/Query:** SQLx (latest) + compile-time checked macros เท่านั้น
- **Auth:** JWT (jsonwebtoken crate)
- **OTP:** Phone verification via SMS (INET/Cheese Digital CSGAPI)
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
├── schema: auth         (users, sessions, roles, otp_codes, guard_profiles, customer_profiles)
├── schema: booking      (requests, assignments, payments, service_rates)
├── schema: tracking     (locations, history)
├── schema: notification (logs, fcm_tokens)
├── schema: reviews      (guard_reviews)
├── schema: chat         (conversations, messages, read_receipts, attachments)
└── schema: audit        (logs ทุก action)
```

### Customer Profiles Table
```sql
CREATE TABLE auth.customer_profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL UNIQUE REFERENCES auth.users(id),
  full_name       TEXT,
  contact_phone   TEXT,
  email           TEXT,
  company_name    TEXT,
  address         TEXT NOT NULL,
  approval_status approval_status NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```
> **Dual approval tracking:** `auth.users.approval_status` tracks guard profile approval.
> `auth.customer_profiles.approval_status` tracks customer profile approval independently.
> A guard with `users.approval_status='approved'` can have `customer_profiles.approval_status='pending'`.

### OTP Codes Table
```sql
CREATE TABLE auth.otp_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       TEXT NOT NULL,
  code        VARCHAR(16) NOT NULL,
  purpose     VARCHAR(20) NOT NULL DEFAULT 'register',
  is_used     BOOLEAN NOT NULL DEFAULT false,
  attempts    INTEGER NOT NULL DEFAULT 0,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_otp_codes_phone_purpose ON auth.otp_codes(phone, purpose, is_used);
CREATE INDEX idx_otp_codes_expires_at ON auth.otp_codes(expires_at);
```

### Chat Tables
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
> `chat.messages` has `sender_role VARCHAR(20)` column — stores `'guard'` or `'customer'` to enable role-based message alignment (same user can send as different roles).

```sql
CREATE TABLE chat.read_receipts (
    conversation_id UUID NOT NULL REFERENCES chat.conversations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_role       VARCHAR(20) NOT NULL DEFAULT 'guard',
    last_read_message_id UUID REFERENCES chat.messages(id) ON DELETE SET NULL,
    read_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id, user_role)
);
```
> **Read receipts per role:** PK includes `user_role`, so the same user reading as guard vs customer are tracked independently.
> **Unread count:** Calculated via `COUNT(messages WHERE sender_role IS DISTINCT FROM acting_role AND created_at > read_at)`.

### Payments Table
```sql
CREATE TABLE booking.payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id      UUID NOT NULL REFERENCES booking.guard_requests(id),
  customer_id     UUID NOT NULL REFERENCES auth.users(id),
  amount          DECIMAL(10,2) NOT NULL,
  payment_method  TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending',
  transaction_ref TEXT,
  paid_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```
> **Simulated payments** — ready for real gateway integration. Status: `pending` → `completed` / `failed`.
> `booking.assignments` has `started_at TIMESTAMPTZ` for countdown tracking.
> `booking.guard_requests` has `booked_hours INTEGER` for countdown calculation.
> `assignment_status` enum extended: `pending_acceptance` → `accepted` / `declined` (guard acceptance flow).

### Service Rates Table
```sql
CREATE TABLE booking.service_rates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  min_price   DECIMAL(10,2) NOT NULL,
  max_price   DECIMAL(10,2) NOT NULL,
  base_fee    DECIMAL(10,2) NOT NULL,
  min_hours   INTEGER NOT NULL DEFAULT 6,
  notes       TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_service_rates_active ON booking.service_rates(is_active);
```
> **Soft delete:** `is_active = false` instead of actual deletion. All public queries filter `WHERE is_active = true`.
> **Price validation:** `min_price <= max_price`, all prices >= 0, name <= 200 chars — enforced in Rust service layer.
> **Decimal type:** Uses `rust_decimal::Decimal` in Rust — utoipa requires `#[schema(value_type = f64)]` annotation.

### Reviews Table
```sql
CREATE TABLE reviews.guard_reviews (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guard_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assignment_id    UUID NOT NULL REFERENCES booking.assignments(id) ON DELETE CASCADE,
  request_id       UUID NOT NULL REFERENCES booking.guard_requests(id),
  overall_rating   DECIMAL(2,1) NOT NULL CHECK (overall_rating >= 1 AND overall_rating <= 5),
  punctuality      DECIMAL(2,1) CHECK (punctuality >= 1 AND punctuality <= 5),
  professionalism  DECIMAL(2,1) CHECK (professionalism >= 1 AND professionalism <= 5),
  communication    DECIMAL(2,1) CHECK (communication >= 1 AND communication <= 5),
  appearance       DECIMAL(2,1) CHECK (appearance >= 1 AND appearance <= 5),
  review_text      TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (assignment_id)
);
CREATE INDEX idx_guard_reviews_guard_id ON reviews.guard_reviews(guard_id, created_at DESC);
CREATE INDEX idx_guard_reviews_customer_id ON reviews.guard_reviews(customer_id);
```
> **One review per assignment** — UNIQUE constraint on `assignment_id` prevents duplicate reviews.
> **Category ratings optional** — only `overall_rating` is required; category breakdowns (punctuality, professionalism, communication, appearance) are optional.
> **Real ratings in guard discovery** — `list_available_guards()` JOINs `reviews.guard_reviews` with `AVG(overall_rating)` and `COUNT(*)` instead of placeholder values.

### Notification Tables
```sql
CREATE TABLE notification.notification_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  title             TEXT NOT NULL,
  body              TEXT NOT NULL,
  notification_type notification_type NOT NULL DEFAULT 'system',
  payload           JSONB,
  is_read           BOOLEAN NOT NULL DEFAULT false,
  read_at           TIMESTAMPTZ,
  sent_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE notification.fcm_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id),
  token      TEXT NOT NULL UNIQUE,
  device_info TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```
> **notification_type enum:** `booking_created`, `guard_assigned`, `guard_en_route`, `guard_arrived`, `booking_completed`, `booking_cancelled`, `chat_message`, `system`
> **Cross-service notification generation:** Booking service INSERTs directly into `notification.notification_logs` using `sqlx::query` (runtime, not compile-time macro) via `spawn_notification()` helper — acceptable tradeoff since notification schema types are defined in notification crate only.

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
- **Presigned URL Host Rewrite:** MinIO ใน Docker มี internal host `http://minio:9000` — browser ไม่สามารถเข้าถึงได้โดยตรง
  - ต้องตั้ง `S3_PUBLIC_URL=http://localhost/minio-files` ใน env — presigned URL จะ replace `http://minio:9000` → `http://localhost/minio-files` ก่อน return ให้ client
  - Nginx proxy `/minio-files/` → `http://minio:9000/` พร้อม `proxy_set_header Host "minio:9000"` เพื่อให้ MinIO validate signature ได้ (signature ถูก sign ด้วย Host `minio:9000`)
  - `AppState` ต้องมีทั้ง `s3_endpoint: String` (internal) และ `s3_public_url: String` (public-facing)
  - `get_guard_profile()` service ใช้ `rewrite` closure: `url.replacen(s3_endpoint, s3_public_url, 1)` — ทำก็ต่อเมื่อ `s3_endpoint != s3_public_url`
  - Production (R2): ไม่ต้องตั้ง `S3_PUBLIC_URL` — `S3_ENDPOINT` คือ public URL อยู่แล้ว

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
- ทุก API ต้องมี **JWT validation** ยกเว้น `/auth/login`, `/auth/register`, `/otp/request`, `/otp/verify`
- Rate limiting ที่ Nginx layer (auth: 5r/s, API: 30r/s, WS: 5r/s, OTP: 3r/m)
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
- **WebSocket Auth:** Web ใช้ cookie (ส่งอัตโนมัติตอน upgrade); Mobile ใช้ Bearer token ใน `Authorization` header ตอน WS upgrade (ผ่าน `IOWebSocketChannel.connect(headers:)`) — ห้ามส่ง token ใน URL query params
- **WebSocket Data:** ห้ามส่ง conversation_id หรือ sensitive data ใน URL query params — ส่งเป็น message หลัง connection open
- **GPS Tracking Security:**
  - `ws_handler` ต้องตรวจ `user.role == "guard"` ก่อน upgrade — ห้ามให้ admin/customer ส่ง GPS
  - `GpsUpdate::validate()` ต้องตรวจ lat (-90..90), lng (-180..180), reject (0,0), accuracy (0..10000), heading (0..360), speed (0..500)
  - Server-side rate limit: max 1 GPS update/second per connection — drop excess messages
  - `list_all_locations` ต้อง restrict เฉพาะ admin — ห้ามให้ customer เห็น bulk guard locations (TODO: เพิ่ม booking-based filtering สำหรับ customer)
- **Audit Middleware:** ต้อง validate JWT signature ด้วย real secret ก่อน trust user_id — ห้ามใช้ `insecure_disable_signature_validation()`
  - ใช้ `middleware::from_fn_with_state(state.clone(), audit_middleware::<Arc<AppState>>)` — ต้อง turbofish type annotation เพราะ `HasJwtSecret` implement ทั้ง `AppState` และ `Arc<T>`
  - **ทุก service ต้องมี audit middleware** — ปัจจุบัน 5 services (auth, booking, tracking, notification, chat) ทั้งหมดมีแล้ว
  - Audit log persist แบบ **fire-and-forget** ผ่าน `tokio::spawn` — ห้าม block response
  - IP address: ใช้ `X-Real-IP` ก่อน → fallback `X-Forwarded-For` rightmost entry
  - **entity_type:** derive จาก URL path segment แรก (เช่น `/auth/login` → `"auth"`, `/booking/requests` → `"booking"`) — ห้ามใช้ HTTP status code เป็น entity_type
- **Password Hashing:** Argon2 ต้อง run ใน `tokio::task::spawn_blocking()` เสมอ — ห้าม block async runtime
- **Login Error Messages:** ห้ามส่ง error ที่เปิดเผยว่า email มีอยู่ในระบบหรือไม่ — ใช้ message เดียวกันสำหรับ wrong password, inactive account, not found
- **OTP Security:**
  - **SMS Gateway:** INET/Cheese Digital CSGAPI (`bulksms.cheesemobile.com/v2/`) — config ผ่าน `SmsConfig::from_env()`
  - **Shared HTTP Client:** `reqwest::Client` เก็บใน AppState — timeout 10s, connect timeout 5s — ห้ามสร้าง client ใหม่ทุก request
  - **Rate Limiting:** Atomic `SET NX EX` ใน Redis (per-phone cooldown) — ห้ามใช้ separate EXISTS + SET (TOCTOU race)
  - **Daily Cap:** Per-phone daily OTP limit ผ่าน Redis `INCR` — ต้องตรวจ `TTL` หลัง INCR แล้ว set EXPIRE ถ้า TTL < 0 (crash-recovery) — ห้ามใช้ `if count == 1` เท่านั้น
  - **Attempt Counter:** Atomic `UPDATE ... WHERE id = (SELECT ... FOR UPDATE)` ใน PostgreSQL — ห้ามทำ SELECT แล้ว UPDATE แยก
  - **Constant-Time Comparison:** ใช้ `subtle::ConstantTimeEq` เปรียบเทียบ OTP code — ห้ามใช้ `==` (timing side-channel)
  - **Phone Verify Token:** JWT พร้อม `jti` (UUID) สำหรับ single-use enforcement — เก็บ jti เป็น "valid" ใน Redis, consume ด้วย `GETDEL` ตอน register
  - **Phone Verify TTL:** แยกจาก OTP expiry — `PHONE_VERIFY_TTL_MINUTES` (default 10 นาที) ให้เวลากรอก form registration
  - **OTP Cleanup:** Background task (`tokio::spawn`) ลบ expired OTP codes ทุก 1 ชั่วโมง
  - **Phone Format:** `otp::validate_thai_phone()` — strip non-digit, ต้อง 10 หลักขึ้นต้นด้วย `0`
  - **International Format:** `otp::to_international_format()` — แปลง `0812345678` → `66812345678` ก่อนส่ง SMS
- **Registration (OTP flow):** `POST /register/otp` ต้อง return **HTTP 202 Accepted** โดยไม่มี token — ห้ามออก access_token/refresh_token ให้ user ที่ยังมี `approval_status = pending`
  - User ต้องรอ Admin อนุมัติก่อนจึงจะ login ได้ (ผ่าน `/auth/login` ปกติ)
  - `register_with_otp()` service ต้อง INSERT user แล้ว return `RegisterWithOtpResponse` เท่านั้น — ห้าม INSERT session หรือเรียก `encode_jwt_with_key()`
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
- **Map (Leaflet):** ต้อง dynamic import ด้วย `ssr: false` เสมอ — Leaflet ต้องการ `window`/DOM
- **Map Auth:** หน้า map ต้อง gate ด้วย `useAuth()` — เฉพาะ admin/customer เท่านั้น (guard เห็นเฉพาะ location ตัวเอง)
- **Map Types:** ใช้ `DisplayGuard` จาก `map/types.ts` — ห้าม duplicate interface ใน component
- **Map Icons:** ใช้ module-level icon cache — ห้ามสร้าง `L.DivIcon` ใหม่ทุก render
- **Map Search:** ต้อง debounce search input — ห้ามใช้ raw `searchQuery` ตรงใน filter useMemo
- **Map Popup:** ใช้ conditional render (`{isSelected && <Popup>}`) — ห้าม mount Popup ทุก Marker

### Flutter Mobile
- **Secure Storage:** ข้อมูล sensitive (JWT tokens, PIN hash) ต้องเก็บใน `FlutterSecureStorage` เท่านั้น — ห้ามใช้ `SharedPreferences` สำหรับ tokens
  - `SharedPreferences` ใช้ได้เฉพาะ non-sensitive data (language pref, registration flags)
- **PIN Security:** Hash PIN ด้วย SHA-256 ก่อนเก็บ — ห้ามเก็บ plaintext PIN
- **API Client:** ใช้ `ApiClient` (Dio-based) ที่มี JWT interceptor อัตโนมัติ — ห้ามเรียก API ตรงโดยไม่ผ่าน interceptor
  - Interceptor ใส่ Bearer token จาก `FlutterSecureStorage` อัตโนมัติ
  - 401 response → auto-refresh token แล้ว retry — **refresh response ต้อง parse `response.data['data']`** (ApiResponse wrapper) ไม่ใช่ `response.data` ตรง
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
│   ├── shared/                 ← Shared library crate (auth, config, error, models, otp, sms)
│   ├── auth/                   ← Rust (JWT + cookies + argon2 + OTP/SMS)
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
│   │       ├── map/            ← แผนที่สด (react-leaflet)
│   │       │   ├── page.tsx           ← Map page (auth-gated, search, fullscreen)
│   │       │   ├── map-area.tsx       ← Leaflet MapContainer (dynamic import, ssr:false)
│   │       │   ├── dashboard-mini-map.tsx ← Read-only mini map for dashboard
│   │       │   └── types.ts           ← Shared DisplayGuard type
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
│       │   │   ├── auth_provider.dart    ← Centralized auth state (Provider)
│       │   │   ├── booking_provider.dart ← Booking/pricing/guard jobs state (Provider)
│       │   │   ├── chat_provider.dart    ← Chat conversations + messages state (Provider)
│       │   │   ├── notification_provider.dart ← Notification list + unread count state (Provider)
│       │   │   └── tracking_provider.dart ← GPS tracking on/off state (Provider)
│       │   ├── services/
│       │   │   ├── api_client.dart      ← Dio HTTP client + JWT interceptor
│       │   │   ├── auth_service.dart    ← Token storage + login/OTP
│       │   │   ├── booking_service.dart ← Booking/pricing/guard API calls
│       │   │   ├── chat_service.dart    ← Chat REST + WebSocket messaging
│       │   │   ├── notification_service.dart ← Notification REST API client
│       │   │   ├── pin_storage_service.dart ← PIN hash + FlutterSecureStorage
│       │   │   ├── tracking_service.dart  ← WebSocket GPS streaming to backend
│       │   │   └── language_service.dart
│       │   ├── screens/                ← 43 screens (guard/hirer/common)
│       │   │   ├── phone_input_screen.dart           ← OTP: กรอกเบอร์โทร
│       │   │   ├── otp_verification_screen.dart      ← OTP: กรอกรหัส 6 หลัก
│       │   │   ├── set_password_screen.dart          ← OTP: ตั้งรหัสผ่าน + ข้อมูล
│       │   │   ├── pin_login_screen.dart              ← Login ด้วย PIN เดิม (returning approved user)
│       │   │   ├── customer_registration_screen.dart ← Customer: กรอก address + company
│       │   │   ├── registration_pending_screen.dart  ← รอ Admin อนุมัติ (no tokens)
│       │   │   ├── notification_screen.dart           ← Notifications list (real API data)
│       │   │   ├── chat_list_screen.dart             ← Chat conversation list (role-aware)
│       │   │   ├── chat_screen.dart                  ← Real-time chat (WebSocket + REST)
│       │   │   ├── guard/active_job_screen.dart      ← Guard active job with countdown
│       │   │   ├── guard/guard_job_detail_screen.dart ← Guard job detail + accept/decline
│       │   │   ├── hirer/payment_success_screen.dart  ← Payment confirmation
│       │   │   └── hirer/waiting_for_guard_screen.dart ← Wait for guard acceptance + status
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
    └── Tab: ผู้เรียก รปภ. (Customer Applicants) ← ใช้ `listCustomerApplicants` API
          ├── แสดง: ชื่อ, เบอร์, company_name, address, approval_status
          └── อนุมัติ (updateCustomerApproval) → ย้ายไปเมนู "ลูกค้า" (/customers)
```

### Applicants Page Technical Details
- **Types:** Discriminated union — `GuardApplicant` (type: "guard") | `CustomerApplicant` (type: "customer")
- **Tabs:** 3 tabs (ทั้งหมด / เจ้าหน้าที่ รปภ. / ผู้เรียก รปภ.)
- **Data Source:**
  - Tab "all" / "guard": `authApi.listUsers()` — queries `auth.users` by role
  - Tab "customer": `authApi.listCustomerApplicants()` — queries `auth.customer_profiles` JOIN `auth.users` (finds guards with customer profiles)
- **Approval Endpoints:**
  - Guard/no-role: `authApi.updateApprovalStatus()` → PATCH `/auth/users/{id}/approval` (updates `auth.users.approval_status`)
  - Customer tab: `authApi.updateCustomerApproval()` → PATCH `/auth/admin/customer-profile/{id}/approval` (updates `customer_profiles.approval_status`)
- **Stats Cards:** Scope ตาม active tab (นับเฉพาะ applicants ในประเภทที่เลือก)
- **Modal:** Content แตกต่างตามประเภท — Guard: fetch `getGuardProfile()` → แสดงเอกสาร/ประวัติ/ธนาคาร; Customer: fetch `getCustomerProfile()` → แสดง full_name, contact_phone, email, company_name, address
- **Approved Note:** เมื่อสถานะ approved จะแสดงข้อความว่าไปอยู่เมนูไหน

### Customers Page (/customers)
- **Data Source:** `authApi.listCustomerApplicants({ approval_status: 'approved' })` — queries `customer_profiles` with approved status (NOT `listUsers` with `role='customer'` — guards who added customer profiles keep `role='guard'` in `auth.users`)
- **Modal:** fetches `getCustomerProfile()` → shows full_name, contact_phone, email, company_name, address

### Pricing Page (/pricing)
- **Data Source:** `pricingApi.listServiceRates()` → `GET /booking/pricing/services` (public, no JWT)
- **API Object:** `pricingApi` in `lib/api.ts` — `listServiceRates()`, `createServiceRate()`, `updateServiceRate()`, `deleteServiceRate()`
- **Type:** `ServiceRateResponse` in `lib/api.ts` — maps to `booking.service_rates` table fields (snake_case)
- **Local Type:** `ServiceRate` (camelCase) in page — mapped via `toServiceRate()` helper
- **Tabs:** 2 tabs — "บริการ" (Services) manages service rates CRUD; "กฎราคา" (Price Rules) placeholder
- **CRUD:** Admin can add/edit/delete service rates — delete calls `pricingApi.deleteServiceRate()` then reloads list (not optimistic)
- **Loading:** Shows `Loader2` spinner in services tab while loading

### Map Page Architecture (/map)
- **Auth Gate:** `useAuth()` — admin + customer only (guards see unauthorized screen)
  - Server-side: tracking API must enforce role-based filtering (guards see own location only)
- **Map Library:** react-leaflet (Leaflet) — loaded via `dynamic(() => import("./map-area"), { ssr: false })` เพราะ Leaflet ต้องการ DOM
- **Shared Type:** `DisplayGuard` interface อยู่ใน `map/types.ts` — ใช้ร่วมระหว่าง `page.tsx` และ `map-area.tsx`
- **Search:** Unified search across `name`, `id`, `location` — debounced 300ms ป้องกัน keystroke lag
- **Filter:** Status filter (all/active/idle/alert) + search ทำงานร่วมกันผ่าน `filteredGuards` useMemo
- **Memoization:** Demo data เป็น module-level constant (`DEMO_GUARDS`) → `displayGuards` wrapped ใน `useMemo([guards])` → downstream useMemo/useCallback ทำงานถูกต้อง
- **Markers:** `GuardMarker` component — conditional Popup render เฉพาะ selected guard + `markerRef.openPopup()` auto-open
- **Icon Cache:** Module-level `Map<string, L.DivIcon>` — 6 variants (3 statuses × 2 selected states) สร้างครั้งเดียว
- **Fullscreen:** `fixed inset-0 z-50` overlay + `map.invalidateSize()` หลัง resize
- **Dashboard Mini Map:** `DashboardMiniMap` — read-only, no interaction (`dragging={false}`, `scrollWheelZoom={false}`)
- **Tile Provider:** OSM (dev only) — production ต้องเปลี่ยนเป็น Mapbox/Maptiler

### Flutter Mobile Map (live_map_screen.dart)
- **Auth Gate:** `AuthProvider` role check — admin + customer only
- **Map Library:** flutter_map + latlong2
- **Stats:** `_GuardStats.from()` single-pass counter
- **Widgets:** Extracted `_GuardMapLayer`, `_MarkerDot`, `_SelectedMarkerCallout` ป้องกัน unnecessary rebuild
- **Import:** `import 'package:latlong2/latlong.dart' show LatLng;` — ต้อง `show LatLng` เพื่อหลีกเลี่ยง conflict กับ `dart:ui.Path`

### OTP Registration Flow — 3-Step Progressive (Phone → OTP → PIN → Register → Role → Guard Profile)

> **Flow เปลี่ยนแปลง (2026-03-05):** 3-step progressive registration with atomic guard role
> - Step 1: `registerWithOtp(role=null)` ถูกเรียกใน `PinSetupScreen._finishSetup()` ทันทีหลัง PIN — Admin เห็น applicant โดยยังไม่มีประเภท
> - Step 2: `updateRole(phone, 'guard')` ถูกเรียกใน `RoleSelectionScreen._onRoleTap()` — ออก `profile_token` เท่านั้น **ไม่ set role ใน DB** (guard ยังเป็น null)
> - Step 2 (customer): `updateRole(phone, 'customer')` → ออก `profile_token` เท่านั้น **ไม่ set role ใน DB** (เหมือน guard)
> - Step 3 (guard): `submitGuardProfile(profileToken)` ถูกเรียกใน `GuardRegistrationScreen._onSubmit()` — set role='guard' + save profile **atomically** → Admin เห็นข้อมูลครบ
> - Step 3 (customer): `submitCustomerProfile(profileToken)` ถูกเรียกใน `CustomerRegistrationScreen._onSubmit()` — set role='customer' + save profile **atomically**
> - **Rollback:** ถ้า Step 3 error → role ยังเป็น null, ไม่มี partial state

```
Flutter Mobile                          Backend (rust-auth)                    External
─────────────────                       ───────────────────                    ────────
PhoneInputScreen
  ├─ validate Thai phone (10 digits)    POST /otp/request
  ├─ authProvider.requestOtp(phone) ──► ├─ validate_thai_phone()
  │                                     ├─ Redis SET NX EX (rate limit)
  │                                     ├─ Redis INCR + TTL (daily cap)
  │                                     ├─ Invalidate old OTPs (DB)
  │                                     ├─ Generate OTP code
  │                                     ├─ Store in auth.otp_codes
  │                                     └─ send_sms() ──────────────────────► INET SMS Gateway
  ▼
OtpVerificationScreen                   POST /otp/verify
  ├─ 6-digit input (auto-advance)       ├─ Atomic UPDATE + FOR UPDATE
  ├─ Auto-trigger on complete           ├─ Check max attempts
  ├─ authProvider.verifyOtp() ────────► ├─ subtle::ConstantTimeEq compare
  │                                     ├─ Mark OTP as used
  │  ◄── phone_verified_token ─────────┤ ├─ Issue JWT (phone + jti)
  │                                     └─ Store jti="valid" in Redis
  ▼ pinService.isPinSet?
  ├─ YES (returning user — skip PinSetup entirely):
  │   registerWithOtp(storedPinHash) → "log in instead"?
  │   → loginWithPhone(phone, storedHash) → RoleSelection (authenticated → dashboard)
  │   → fail → PinLoginScreen(phone) → enter original PIN → dashboard
  │
  └─ NO (new user — navigate to PinSetupScreen):
PinSetupScreen(phone, phoneVerifiedToken)
  ├─ Step 1: Set 6-digit PIN → SHA-256 → FlutterSecureStorage
  ├─ Step 2: Confirm PIN
  ├─ Step 3: Fingerprint/Biometric enroll (Skip หรือ Enable)
  ├─ ★ STEP 1: registerWithOtp(role=null)   POST /register/otp
  │   authProvider.registerWithOtp(     ──► ├─ Decode JWT → (phone, jti)
  │     phoneVerifiedToken)                 ├─ Redis GETDEL jti (single-use)
  │                                         ├─ Argon2 hash PIN (password param = SHA-256 of PIN)
  │   ◄── 202 + user_id ──────────────────┤ ├─ UPSERT user (role=NULL, status=pending)
  │   (no profile_token — role unknown)     └─ Admin เห็น applicant ไม่มีประเภท
  │
  │   ★ RETURNING USER (approved, tokens cleared):
  │   registerWithOtp returns 409 "Please log in instead"
  │   → auto-try loginWithPhone(phone, pinHash) with PIN just entered
  │   → success: RoleSelectionScreen (authenticated → dashboard)
  │   → fail: PinLoginScreen(phone) → enter original PIN → loginWithPhone → dashboard
  │
  └─ Navigate → RoleSelectionScreen(phone)  ← phoneVerifiedToken consumed
  ▼
RoleSelectionScreen(phone)
  ├─ ★ STEP 2: updateRole(phone, role)     POST /profile/role
  │   authProvider.updateRole(phone,   ──► ├─ validate_thai_phone()
  │     'guard'/'customer')                 ├─ Guard: SELECT id (verify user) — ไม่ UPDATE role
  │                                         ├─ Customer: SELECT id (verify user) — ไม่ UPDATE role
  │   ◄── profile_token (both) ───────────┤ └─ encode_profile_token(purpose) → Redis EX 15min
  │                                              Guard: purpose="guard_profile"
  │                                              Customer: purpose="customer_profile"
  ├─ guard → GuardRegistrationScreen(phone, profileToken)
  └─ customer → CustomerRegistrationScreen(phone, profileToken)
  ▼ (guard path)
GuardRegistrationScreen(phone, profileToken)
  ├─ Step 1: full_name, gender, DOB, experience, workplace
  ├─ Step 2: 5 docs (image_picker: id_card, security_license,
  │           training_cert, criminal_check, driver_license)
  ├─ Step 3: bank_name, account_number, account_name, passbook_photo
  └─ ★ STEP 3: _onSubmit():
      authProvider.submitGuardProfile(       POST /profile/guard
        profileToken, files...) ──────────► ├─ validate_profile_token() → Redis GETDEL
                                            ├─ validate magic bytes + size (JPEG/PNG/WEBP ≤10MB)
                                            ├─ upload docs to MinIO in PARALLEL (JoinSet)
                                            ├─ UPSERT auth.guard_profiles
                                            ├─ UPDATE auth.users SET role='guard' ← atomic!
                                            └─ invalidate_user_cache() → Admin เห็นทันที
      (fallback: reissueProfileToken(role:'guard') if profileToken expired)
      ★ ถ้า error → role ยังเป็น null (ไม่มี partial state)
  ▼ (customer path)
CustomerRegistrationScreen(phone, profileToken)
  ├─ address (required, min 10 chars), company_name (optional), email (optional)
  └─ ★ STEP 3 (customer): _onSubmit():
      authProvider.submitCustomerProfile(      POST /profile/customer
        profileToken, address,            ──► ├─ validate_profile_token(purpose="customer_profile")
        companyName)                           ├─ UPSERT auth.customer_profiles (approval_status='pending')
                                               ├─ UPDATE auth.users SET role='customer' WHERE role IS NULL
                                               └─ invalidate_user_cache()
      (fallback: reissueProfileToken(role:'customer') if profileToken expired)
      ★ ถ้า error → role ยังเป็น null (ไม่มี partial state)
      ★ customer_profiles.approval_status = 'pending' → ต้องรอ admin อนุมัติ
  ▼
RegistrationPendingScreen
  ├─ "ตรวจสอบสถานะ" button → _checkApprovalStatus():
  │     ├─ GET /auth/me (check approval_status via AuthService.getStoredPhone())
  │     ├─ phone fallback: _profile?['phone'] (for users registered before storePhone())
  │     ├─ If approved: loginWithPhone(phone, pinHash) → Dashboard
  │     └─ If still pending: show "กำลังรอการอนุมัติ" message
  ├─ "Back to Login" → RoleSelectionScreen
  └─ "แก้ข้อมูล" → GuardRegistrationScreen(phone, initialProfile, dashboard)
      ├─ Pre-fills: full_name, gender, date_of_birth, experience, workplace, bank_name, account_name
      ├─ Empty: account_number (security — masked locally), documents (re-upload or skip — backend COALESCE preserves)
      └─ Back button: canPop() ? pop : pushAndRemoveUntil(RegistrationPendingScreen)
```

> **Design decision:** Registration returns **202 Accepted with no tokens**. The user cannot
> access any protected endpoint until an admin approves the account. Only after approval
> can the user log in via `POST /auth/login/phone` (phone + PIN hash).
>
> **3-step progressive visibility:** Admin sees applicant at each step:
> 1. After PIN: user appears with `role=null` ("ยังไม่ได้ระบุ")
> 2. After role selection: both guard & customer → role ยังเป็น null (แค่ออก profile_token)
> 3. After form submit: guard → `submit_guard_profile()` sets role='guard'; customer → `submit_customer_profile()` sets role='customer' — both atomic
>
> **Atomic role assignment:** `update_user_role()` ไม่ UPDATE role สำหรับทั้ง guard และ customer — แค่ SELECT verify + issue profile_token.
> `submit_guard_profile()` / `submit_customer_profile()` เป็นตัว SET role หลัง save สำเร็จ → ถ้า error, role ยัง null.
>
> **Profile token lifecycle:** `updateRole()` issues `profile_token` (15-min JWT) with purpose (`"guard_profile"` / `"customer_profile"`).
> Used by `submitGuardProfile()` / `submitCustomerProfile()`. If expired, `reissueProfileToken(role:)` gets a fresh one.
> Single-use enforced via Redis GETDEL on jti. Purpose isolation prevents cross-use.

**iOS Keychain & PinLockScreen:**
- iOS Keychain persists across app reinstalls — `isPinSet` อาจเป็น `true` แม้หลัง uninstall
- `main.dart` ต้องเช็ค `auth.status == AuthStatus.authenticated` **ก่อน** `pinService.isPinSet`
- PinLockScreen แสดงเฉพาะ authenticated users เท่านั้น — fresh install/unregistered → PhoneInputScreen
- **Post-PIN navigation:** `_navigateToApp()` async → uses `auth.phone ?? AuthService.getStoredPhone()` for phone fallback → fire-and-forget `auth.fetchProfile()` if `fullName == null` (ห้าม await — ป้องกัน freeze) → `RoleSelectionScreen(phone)` (ไม่ใช่ dashboard ตรง)
- **RoleSelectionScreen สำหรับ authenticated users:** ถ้า `auth.status == authenticated` → retries `fetchProfile()` if `auth.phone == null` → tap role → `pushReplacement` ไป dashboard ทันที (ไม่ผ่าน registration flow)
- **PopScope(canPop: false):** Root-level screens (RoleSelectionScreen, HirerDashboardScreen, GuardDashboardScreen, CustomerRegistrationScreen) ต้อง wrap ด้วย `PopScope(canPop: false)` เพื่อป้องกัน iOS swipe-back gesture ทำ pop() บน single-route stack → จอดำ

**Auth Service OTP & Profile Endpoints (main.rs):**
- `POST /otp/request` → `handlers::request_otp` (public, no JWT)
- `POST /otp/verify` → `handlers::verify_otp` (public, no JWT)
- `POST /register/otp` → `handlers::register_with_otp` (public, requires phone_verified_token) — returns **202**, no session/tokens. Called in `PinSetupScreen` with `role=null`. Password param = SHA-256 hash of user's PIN.
- `POST /login/phone` → `handlers::login_with_phone` (public) — login with `{phone, password}` (PIN hash). Returns `{access_token, refresh_token, role}`. Used by mobile after admin approval.
- `POST /profile/role` → `handlers::update_role` (public, no JWT) — guard: verify user + issue `profile_token` (**ไม่ set role**); customer: verify user + issue `profile_token` (**ไม่ set role**). Returns `profile_token` for both.
- `POST /profile/reissue` → `handlers::reissue_profile_token` (public) — reissues profile_token for pending user. Accepts optional `role` param to determine purpose (`"guard_profile"` / `"customer_profile"`)
- `POST /profile/guard` → `handlers::submit_guard_profile` (profile_token auth, purpose=`"guard_profile"` — single-use)
- `POST /profile/customer` → `handlers::submit_customer_profile` (profile_token auth, purpose=`"customer_profile"` — single-use) — UPSERT `auth.customer_profiles`, SET role='customer' if role IS NULL
- `GET /admin/guard-profile/:user_id` → `handlers::get_guard_profile` (admin JWT)
- `GET /admin/customer-profile/:user_id` → `handlers::get_customer_profile` (admin JWT) — JOIN users + customer_profiles
- `GET /admin/customer-applicants` → `handlers::list_customer_applicants` (admin JWT) — queries `customer_profiles` JOIN `auth.users`, filters by `customer_profiles.approval_status`. Returns `PaginatedUsers` with `role` forced to `"customer"`.
- `PATCH /admin/customer-profile/:user_id/approval` → `handlers::update_customer_approval` (admin JWT) — updates `customer_profiles.approval_status` + `invalidate_user_cache()`
- `GET /me` → `handlers::get_me` (JWT required) — returns `UserResponse { id, full_name, phone, email, role, avatar_url, approval_status, customer_approval_status, customer_full_name }`. `full_name` = guard name from `auth.users`, `customer_full_name` = customer name from `customer_profiles` (separate, never merged). Used by `AuthProvider.fetchProfile()` for dashboard real data.

**Shared Modules:**
- `shared::otp` — `OtpConfig`, `validate_thai_phone()`, `generate_otp()`, `to_international_format()`, `format_otp_message()`
- `shared::sms` — `SmsConfig`, `send_sms()` (INET CSGAPI gateway)
- `shared::auth` — `PhoneVerifyClaims` (JWT with jti), `encode_phone_verify_token()`, `decode_phone_verify_token()`; `ProfileTokenClaims` (JWT with jti + purpose), `encode_profile_token(purpose)` → `(String, String)` (token, jti), `decode_profile_token(expected_purpose)` → `(Uuid, String)` (user_id, jti) — purpose isolation: `"guard_profile"` / `"customer_profile"`

**Auth Service — Guard & Customer Profile:**
- `service::register_with_otp()`: if role=guard (explicit), calls `encode_profile_token(purpose="guard_profile")` → stores jti in Redis `SET EX 900` (15 min). When role=null (3-step flow), does NOT issue profile_token.
- `service::update_user_role()`: Guard path: SELECT verify user (pending + role IS NULL or guard) + issue profile_token (purpose=`"guard_profile"`) — **ไม่ UPDATE role**. Customer path: SELECT verify user + issue profile_token (purpose=`"customer_profile"`) — **ไม่ UPDATE role**. Rejects admin role.
- `service::validate_profile_token(expected_purpose)`: async, takes redis + expected_purpose param — decodes JWT with purpose check, then `GETDEL profile_jti:{jti}` — returns `Err` if value ≠ `"valid"` (expired, used, or forged)
- `service::submit_guard_profile()`: validates size **before** magic bytes; uploads all doc files to MinIO **in parallel** via `tokio::task::JoinSet`; UPSERTs `auth.guard_profiles`; then **SET role='guard'** + `invalidate_user_cache()` — role set only after successful save (atomic, no partial state on error)
- `service::submit_customer_profile()`: validates address not empty; UPSERTs `auth.customer_profiles` with `approval_status='pending'`; then **SET role='customer' WHERE role IS NULL** + `invalidate_user_cache()` — guards keep their role if they also register as customer
- `service::get_profile()`: LEFT JOIN `auth.users` + `customer_profiles` — returns `UserResponse` with **separated** names: `full_name` from `auth.users` (guard name), `customer_full_name` from `customer_profiles.full_name` (customer name, `skip_serializing_if None`). ห้าม merge — ถ้า customer has different name it must remain separate.
- `service::get_customer_profile()`: JOIN `auth.users` + `auth.customer_profiles` — returns `CustomerProfileResponse` (uses `cp.approval_status` not `u.approval_status`)
- `service::list_customer_applicants()`: JOIN `customer_profiles` + `auth.users`, filters by `cp.approval_status`, returns `PaginatedUsers` with `role` forced to `Some(UserRole::Customer)`
- `service::update_customer_approval_status()`: UPDATE `customer_profiles.approval_status` + `invalidate_user_cache()`
- file_key format for guard docs: `profiles/guard/{user_id}/{doc_type}.{ext}`

**Booking Service — Pricing Endpoints (main.rs):**
- `GET /pricing/services` → `handlers::list_service_rates` (public, no JWT) — returns active rates, `LIMIT 100`
- `GET /pricing/services/{id}` → `handlers::get_service_rate` (public, no JWT) — returns single active rate (filters `is_active = true`)
- `POST /pricing/services` → `handlers::create_service_rate` (admin JWT) — validates: name not empty, name ≤ 200 chars, prices ≥ 0, min_price ≤ max_price
- `PUT /pricing/services/{id}` → `handlers::update_service_rate` (admin JWT) — partial update via COALESCE; merges with existing values before validating prices
- `DELETE /pricing/services/{id}` → `handlers::delete_service_rate` (admin JWT) — soft delete (`is_active = false`), returns 204
- **Validation:** `validate_prices()` helper checks all 3 price fields ≥ 0 and min_price ≤ max_price; applied on both create and update (with merged values)
- **Decimal:** Uses `rust_decimal::Decimal` — utoipa annotation `#[schema(value_type = f64)]` required for OpenAPI compatibility

**Booking Service — Request & Assignment Endpoints (main.rs):**
- `POST /requests` → `handlers::create_request` (JWT) — customer creates guard request
- `GET /requests` → `handlers::list_requests` (JWT) — list requests (customer sees own, admin sees all)
- `GET /requests/{id}` → `handlers::get_request` (JWT) — single request detail (owner/admin/assigned guard)
- `PUT /requests/{id}/cancel` → `handlers::cancel_request` (JWT) — cancel pending request (owner/admin)
- `POST /requests/{id}/assign` → `handlers::assign_guard` (JWT: admin or request owner) — assign guard to request. Admin can assign to any request; customer can assign only to own pending request (`request.customer_id == user.user_id`)
- `GET /requests/{id}/assignments` → `handlers::get_assignments` (JWT) — list assignments for request
- `PUT /assignments/{id}/status` → `handlers::update_assignment_status` (JWT) — guard updates own assignment status

**Booking Service — Available Guards Endpoint (main.rs):**
- `GET /available-guards` → `handlers::available_guards` (JWT) — list nearby available guards for customer
  - Query params: `lat` (required), `lng` (required), `radius_km` (optional, default 50, max 200), `limit` (optional, default 20, max 50), `offset` (optional, default 0)
  - Returns `Vec<AvailableGuardResponse>` — guards with `role='guard'`, `is_active=true`, `approval_status='approved'`, GPS location within last 30 minutes, within radius_km
  - **Haversine distance:** Calculated in SQL using `6371 * acos(...)` with `LEAST/GREATEST` clamping to prevent NaN from floating-point rounding
  - **Models:** `AvailableGuardsQuery` (query params), `AvailableGuardRow` (sqlx::FromRow), `AvailableGuardResponse` (API response — includes `id`, `full_name`, `avatar_url`, `experience_years`, `lat`, `lng`, `distance_km`, `last_seen_at`, `completed_jobs`, `rating`, `review_count`)
  - **Placeholder ratings:** `rating = 4.5 + (completed_jobs * 0.01).min(0.4)`, `review_count = completed_jobs.min(200)` — TODO: replace with real reviews table
  - Ordered by distance ascending

**Booking Service — Guard Acceptance & Payment Endpoints (main.rs):**
- `PUT /assignments/{id}/accept` → `handlers::accept_decline_assignment` (guard JWT) — guard accepts or declines assigned job. Body: `AcceptDeclineDto { action: "accept" | "decline" }`. Updates `assignment_status` to `accepted` / `declined`.
- `PUT /assignments/{id}/start` → `handlers::start_job` (guard JWT) — guard starts accepted job. Sets `started_at = NOW()` on assignment.
- `POST /payments` → `handlers::create_payment` (JWT) — create simulated payment. Body: `CreatePaymentDto { request_id, amount, payment_method }`. Returns `PaymentResponse`.
- `GET /guard/active-job` → `handlers::get_active_job` (guard JWT) — returns active job for guard (accepted/in_progress assignment with request details, started_at, booked_hours for countdown)

**Booking Service — Guard Endpoints (main.rs):**
- `GET /guard/dashboard` → `handlers::guard_dashboard` (guard JWT)
- `GET /guard/jobs` → `handlers::guard_jobs` (guard JWT) — query params: `status`, `limit`, `offset`
- `GET /guard/earnings` → `handlers::guard_earnings` (guard JWT)
- `GET /guard/work-history` → `handlers::guard_work_history` (guard JWT) — query params: `status`, `limit`, `offset`
- `GET /guard/ratings` → `handlers::guard_ratings` (guard JWT)

**Booking Service — Review & Completion Endpoints (main.rs):**
- `PUT /assignments/{id}/review-completion` → `handlers::review_completion` (JWT) — customer approves/rejects guard's pending_completion. Body: `{ action: "approve" | "reject" }`. Approve → status=`completed`, triggers "งานเสร็จสมบูรณ์" notification to guard. Reject → status=`accepted` (back to active).
- `POST /assignments/{id}/review` → `handlers::submit_review` (JWT) — customer submits star rating after job completion. Body: `{ overall_rating, punctuality?, professionalism?, communication?, appearance?, review_text? }`. INSERTs into `reviews.guard_reviews`. Triggers "คะแนนรีวิวใหม่" notification to guard.

**Booking Service — Cross-Service Notification Generation:**
- `spawn_notification(db, user_id, title, body, notification_type, payload)` — fire-and-forget helper using `tokio::spawn`. INSERTs directly into `notification.notification_logs` table (shared PostgreSQL). Uses `sqlx::query` (runtime) since notification schema types aren't in booking crate.
- **9 notification trigger points:**
  - `create_request()` → customer: "การจองสำเร็จ" (`booking_created`)
  - `assign_guard()` → guard: "งานใหม่ที่ได้รับ" (`guard_assigned`)
  - `accept_or_decline()` accept → customer: "เจ้าหน้าที่ตอบรับแล้ว" (`guard_assigned`)
  - `accept_or_decline()` decline → customer: "เจ้าหน้าที่ปฏิเสธงาน" (`booking_cancelled`)
  - `create_payment()` → guard: "ชำระเงินสำเร็จ" (`booking_created`)
  - `update_assignment_status()` en_route → customer: "เจ้าหน้าที่กำลังเดินทาง" (`guard_en_route`)
  - `update_assignment_status()` arrived → customer: "เจ้าหน้าที่ถึงแล้ว" (`guard_arrived`)
  - `review_completion()` approve → guard: "งานเสร็จสมบูรณ์" (`booking_completed`)
  - `submit_review()` → guard: "คะแนนรีวิวใหม่" (`system`)
- Customer ID lookups for guard-triggered events use lightweight `query_scalar` inside the spawned task

**Notification Service Endpoints (main.rs, port 3004):**
- `POST /tokens` → `handlers::register_token` (JWT) — register FCM device token
- `DELETE /tokens` → `handlers::unregister_token` (JWT) — unregister FCM token
- `GET /notifications` → `handlers::list_notifications` (JWT) — list user's notifications. Query: `?unread_only=false&limit=20&offset=0`. Returns `Vec<NotificationLogResponse>`.
- `GET /notifications/unread-count` → `handlers::unread_count` (JWT) — returns `UnreadCountResponse { count: i64 }` for badge display
- `PUT /notifications/read-all` → `handlers::mark_all_as_read` (JWT) — marks all user's unread notifications as read. Returns `UnreadCountResponse { count: i64 }` (rows affected).
- `PUT /notifications/{id}/read` → `handlers::mark_as_read` (JWT) — mark single notification as read
- `POST /notifications/send` → `handlers::send_notification` (admin JWT) — send notification (admin tool)
> **Route order:** `unread-count` and `read-all` routes registered BEFORE `{id}/read` to prevent Axum matching `unread-count` as `{id}`.

**Chat Service Endpoints (main.rs, port 3006):**
- `GET /ws/chat` → `handlers::ws_handler` (JWT via WS upgrade headers) — WebSocket for real-time messaging. Bearer token in `Authorization` header. Incoming: `IncomingChatMessage { conversation_id, content, message_type, sender_role? }`. Outgoing: `OutgoingChatMessage { id, conversation_id, sender_id, sender_role?, content, message_type, created_at }`. Redis PubSub for cross-instance broadcast.
- `POST /conversations` → `handlers::create_conversation` (JWT) — create conversation. Body: `{ request_id, participant_ids: [uuid] }`. Links to `booking.guard_requests` via `request_id`.
- `GET /conversations` → `handlers::list_conversations` (JWT) — list user's conversations. Query: `?role=guard|customer`. Returns enriched conversations with `participant_name`, `participant_avatar`, `last_message`, `last_message_at`, `unread_count`, `request_status`. **Name resolution:** JOINs through `booking.guard_requests` + `booking.assignments` + `auth.users` + `auth.customer_profiles`. Uses `acting_role` param to determine which counterpart name to show (guard sees customer name, customer sees guard name). `request_status` (from `guard_requests.status`) enables client-side read-only mode for completed/cancelled jobs.
- `GET /conversations/{id}/messages` → `handlers::list_messages` (JWT) — message history. Query: `?limit=50&offset=0`. Returns newest-first. Includes `sender_role` per message.
- `PUT /conversations/{id}/read` → `handlers::mark_read` (JWT) — mark conversation as read. Query: `?role=guard|customer`. UPSERTs `chat.read_receipts` with `user_role`.
- `POST /attachments` → `handlers::upload_attachment` (JWT, multipart) — upload image attachment to MinIO/R2
- `GET /attachments/{id}` → `handlers::get_signed_url` (JWT) — get presigned URL for attachment

**Flutter Mobile:**
- `AuthProvider`: `requestOtp(phone)`, `verifyOtp(phone, code)`, `registerWithOtp(token, password, fullName, email, role)` → returns `String?` (profile_token for guard, null for others), `updateRole(phone, role)` → returns `String?` (profile_token for both guard & customer), `reissueProfileToken(phone, {role})` (optional role param: `'guard'`/`'customer'`), `submitGuardProfile({profileToken, ...fields, files: Map<String, File>})`, `submitCustomerProfile({profileToken, address, companyName?})`, `loginWithPhone(phone, pinHash)`, `fetchProfile()`
  - `AuthStatus` enum: `unknown` | `authenticated` | `unauthenticated` | `pendingApproval`
  - `registerWithOtp()` sets `_status = AuthStatus.pendingApproval` — **never** sets `authenticated`
  - `updateRole()` calls `POST /auth/profile/role`, updates local pending state with role
  - `loginWithPhone(phone, pinHash)` calls `POST /auth/login/phone` → stores tokens + role, clears pending state → `authenticated`. Called from `RegistrationPendingScreen._checkApprovalStatus()` after admin approval.
  - `fetchProfile()` calls `GET /auth/me` → populates `_fullName`, `_phone`, `_avatarUrl`, `_customerApprovalStatus`, `_customerFullName`. Called in `loginWithPhone()` and `checkAuthStatus()` (when authenticated). Silently fails — dashboard shows fallback values.
  - `checkAuthStatus()`: checks stored access token **first** (tokens take priority over stale pending flag) → clears any stale `pendingApproval` flag → `fetchProfile()` → **if fetchProfile fails but tokens still valid**: treats as authenticated (network timeout/backend down should not log out user) → else checks `isPendingApproval()` → else unauthenticated. Only falls back to unauthenticated when tokens are actually cleared by interceptor (401 + refresh failure).
  - Profile fields: `fullName`, `phone`, `avatarUrl`, `customerApprovalStatus`, `customerFullName` (getters) — used by dashboard screens instead of hardcoded mock data
  - `customerFullName`: `String?` — customer display name from `customer_profiles.full_name` (separate from guard `fullName`). Hirer screens use `customerFullName ?? fullName` for display.
  - `customerApprovalStatus`: `String?` — `'pending'` | `'approved'` | `'rejected'` | `null` (no customer profile). Parsed from `GET /auth/me` response `customer_approval_status` field. Used by `RoleSelectionScreen` and `HirerDashboardScreen` for routing.
  - `profile_token` extraction: safe `raw is String ? raw : null` — never `as String?`
- `AuthService`: `storeTokens()`, `storePhone()`, `getStoredPhone()`, `storeRole()`, `getRole()`, `clearRole()`, `markRegistered()`, `setPendingApproval()`, `isPendingApproval()`, `getPendingRole()`, `clearPendingApproval()`
  - Pending approval state stored in `SharedPreferences` (non-sensitive — no tokens)
  - `savePendingProfile()` stores **masked** account number (last 4 digits only) — full number goes to backend only; also stores `phone` and `date_of_birth` (ISO format) for edit flow
  - `getPendingProfile()` retrieves stored profile for pre-filling edit form
- `ApiClient`: auto-detects platform for default base URL — iOS → `http://localhost:80`, Android → `http://10.0.2.2:80` (override via `--dart-define=API_URL=...`). Skip auth for `/auth/otp/request`, `/auth/otp/verify`, `/auth/register/otp`, `/auth/profile/reissue`, `/auth/profile/role`, `/auth/profile/customer`, `/auth/login/phone`
- `main.dart` `home`: `Consumer<AuthProvider>` — shows loading spinner when `status == unknown` (async auth check in progress), routes to `RegistrationPendingScreen` when `status == pendingApproval`, `PinLockScreen` when authenticated + PIN set, else `PhoneInputScreen`
- `PinSetupScreen._finishSetup()`: calls `registerWithOtp(phoneVerifiedToken, role=null)` immediately after PIN — creates user with no role. Navigates to `RoleSelectionScreen(phone)` without phoneVerifiedToken (consumed). **Returning approved user handling:** if `registerWithOtp` returns "Please log in instead" (Conflict), auto-tries `loginWithPhone(phone, pinHash)` with the PIN just entered — if success → RoleSelectionScreen (authenticated → dashboard); if fail → `PinLoginScreen(phone)` for retry with original PIN.
- `PinLoginScreen`: simple PIN entry screen for returning approved users whose tokens were cleared. Calls `loginWithPhone(phone, hashPin(pin))` → success → RoleSelectionScreen (authenticated → dashboard). Shows "บัญชีได้รับอนุมัติแล้ว" badge. i18n via `PinLoginStrings`.
- `RoleSelectionScreen._onRoleTap()`: **authenticated users** → customer path checks `customerApprovalStatus`: `'approved'` → HirerDashboard, `'pending'` → RegistrationPendingScreen, `null` → CustomerRegistrationScreen; guard path → GuardDashboard ทันที. **unauthenticated users** → calls `updateRole(phone, role)` → guard path gets profile_token → `GuardRegistrationScreen(phone, profileToken)`; customer path gets profile_token → `CustomerRegistrationScreen(phone, profileToken)` (uses `pushReplacement` ไม่ใช่ `push`)
- `HirerDashboardScreen`: `initState` gate — ถ้า `auth.customerApprovalStatus != 'approved'` → redirect ไป `CustomerRegistrationScreen(phone, profileToken: null)` เพื่อบังคับลงทะเบียน customer ก่อนใช้งาน (ใช้ `customerApprovalStatus` ไม่ใช่ `auth.role`)
- `CustomerRegistrationScreen`: single-page form — address (required, min 10 chars), company_name (optional), email (optional with `@` + `.` validation). Submit: **always** calls `submitCustomerProfile` → `fetchProfile()` → `RegistrationPendingScreen` (ทั้ง authenticated และ unauthenticated). Only calls `setPendingApproval(role:'customer')` for **non-authenticated** users. Uses `reissueProfileToken(role:'customer')` fallback if profileToken is null/expired. Back button → `pushReplacement` ไป `RoleSelectionScreen(phone)` (ไม่ใช่ pop หรือ RegistrationPendingScreen).
- `GuardRegistrationScreen`: accepts optional `initialProfile` param for edit mode — `_prefillForm()` restores text fields, gender, DOB, bank from stored profile. Back button uses `canPop()` check to handle edit flow (no route to pop → navigate to `RegistrationPendingScreen`).
- `GuardRegistrationScreen._onSubmit()`: only calls `submitGuardProfile(profileToken)` — no `registerWithOtp()`. Uses `reissueProfileToken()` fallback if profileToken is null/expired.
- **Dashboard real data:** After login, dashboard screens use `AuthProvider` profile fields (`fullName`, `phone`, `avatarUrl`) from `GET /auth/me` instead of hardcoded mock data:
  - `GuardHomeTab`: greeting uses `authProvider.fullName ?? strings.sampleGuardName`; registration check uses `authProvider.isAuthenticated` (not `AuthService.isRegistered()`); status toggle wired to `TrackingProvider` (not local `_isReady` state) — shows connecting/online/offline + GPS accuracy
  - `GuardProfileTab`: real name, formatted phone as ID (`086-320-8235`), avatar from URL or person icon fallback, "ยืนยันแล้ว" badge only (no "ยังไม่ได้ลงทะเบียน")
  - `HirerProfileScreen`: uses `auth.customerFullName ?? auth.fullName` for customer display name, formatted phone as ID, avatar icon fallback
  - `ServiceSelectionScreen`: loads service rates from API via `BookingProvider.fetchServiceRates()` → dynamic cards with icon selection based on service name keywords. Back button uses `pushAndRemoveUntil` → `RoleSelectionScreen(phone)` (ไม่ใช่ `Navigator.pop()` ซึ่งจะทำให้จอดำ)
  - `BookingScreen`: customer fills booking form → `createRequest()` → extracts `requestId` from response → `Navigator.pushReplacement` to `GuardSearchingScreen(requestId, lat, lng)`
    - **Location selection:** `_getCurrentLocation()` (GPS) or `_openMapPicker()` (map picker sheet) — both store `_lat`/`_lng` separately and display place name in `_addressController.text`
    - **Reverse geocoding:** Nominatim `/reverse` API (Thai language) converts coordinates to place name (road/suburb/district). `_setLocationWithGeocode()` shows coordinates immediately, then async reverse geocodes. Address field shows human-readable name (e.g., "ถนนพระราม 1") while `_lat`/`_lng` store actual coordinates for API.
    - **`_MapPickerSheet`:** modal bottom sheet with flutter_map — search (forward geocode), tap-to-pin with auto reverse geocode, zoom +/- buttons (bottom-right). Returns `({LatLng latLng, String? displayName})` record type. Search results → `_selectedDisplayName` set from display_name; manual tap → reverse geocodes to get name.
  - `GuardSearchingScreen`: accepts `requestId` (String?), `lat` (double), `lng` (double). Flow: 2-second radar animation → `fetchAvailableGuards(lat, lng)` → display guard card list (name, avatar, distance, rating, completed jobs, experience) → customer taps "ยืนยันการจอง" → `assignGuardToRequest(requestId, guardId)` → `Navigator.pushReplacement` to `WaitingForGuardScreen`. Empty state: "ไม่พบเจ้าหน้าที่" + retry button. i18n via `LanguageProvider`.
  - `WaitingForGuardScreen`: shows assignment status (pending → accepted/declined). Polls `getAssignments(requestId)` every 5 seconds. Guard accepted → `PaymentScreen(requestId, guardName, amount)`. Guard declined → shows decline message + retry search. Timer auto-decline after 5 minutes.
  - `PaymentScreen`: simulated payment — amount display, payment method selection (QR/bank transfer/credit card). Confirm → `createPayment(requestId, amount, method)` → `PaymentSuccessScreen`.
  - `PaymentSuccessScreen`: success animation + booking summary. "กลับหน้าหลัก" → pop to hirer dashboard.
  - `GuardJobDetailScreen`: guard views job detail — customer info, location, booking time, service type. Actions: accept/decline (calls `acceptDeclineAssignment(assignmentId, action)`), start job (calls `startJob(assignmentId)`), complete job. Chat button → `getOrCreateConversation()` → `ChatScreen`. Call button → `CallScreen`.
  - `ActiveJobScreen`: guard active job with countdown timer. Shows remaining hours/minutes from `started_at` + `booked_hours`. Location map placeholder. Complete job button. Chat/Call shortcuts.
  - `GuardJobsTab`: wired to real API — `fetchJobs()` on init, shows pending/active/completed tabs. Tapping job → `GuardJobDetailScreen`. Chat button per job → creates/finds conversation → `ChatScreen(actingRole: 'guard')`.
- `BookingProvider` (`booking_provider.dart`): `ChangeNotifier` for booking/guard state
  - Guard: `fetchDashboard()`, `fetchJobs()`, `fetchEarnings()`, `updateAssignmentStatus()`, `acceptDeclineAssignment(assignmentId, action)`, `startJob(assignmentId)`, `fetchActiveJob()`, `fetchWorkHistory()`, `fetchRatings()`
  - Customer: `fetchMyRequests()`, `createRequest()`, `cancelRequest()`, `fetchAvailableGuards(lat, lng)`, `assignGuardToRequest(requestId, guardId)`, `createPayment(requestId, amount, method)`
  - Review: `reviewCompletion(assignmentId, action)`, `submitReview(assignmentId, {overallRating, punctuality?, professionalism?, communication?, appearance?, reviewText?})`
  - Pricing: `fetchServiceRates()` — uses separate `_isLoadingRates` flag (not shared `_isLoading`)
  - State: `serviceRates` (list), `myRequests` (list), `availableGuards` (list), `dashboard`, `currentJobs`, `completedJobs`, `earnings`, `workHistory`, `ratings`, `activeJob`
  - `_isLoadingGuards`: separate flag for available guards loading (not shared with `_isLoading` or `_isLoadingRates`)
- `BookingService` (`booking_service.dart`): Dio-based HTTP client for booking API
  - Guard: `getGuardDashboard()`, `getGuardJobs()`, `getGuardEarnings()`, `updateAssignmentStatus()`, `acceptDeclineAssignment(assignmentId, action)`, `startJob(assignmentId)`, `getActiveJob()`, `getGuardWorkHistory()`, `getGuardRatings()`
  - Customer: `createRequest()`, `listMyRequests()`, `getRequest()`, `cancelRequest()`, `getAssignments()`, `listAvailableGuards({lat, lng, radiusKm, limit})`, `assignGuardToRequest(requestId, guardId)`, `createPayment({requestId, amount, paymentMethod})`
  - Review: `reviewCompletion(assignmentId, action)` → `PUT /booking/assignments/$id/review-completion`, `submitReview(assignmentId, body)` → `POST /booking/assignments/$id/review`
  - Pricing: `listServiceRates()` → `GET /booking/pricing/services` — public, returns `List<Map<String, dynamic>>`
- `main.dart`: `ChangeNotifierProvider(create: (_) => BookingProvider(BookingService(apiClient)))` registered in `MultiProvider`

**Chat (Mobile → Backend):**
- `ChatService` (`chat_service.dart`): REST + WebSocket client for chat
  - REST: `getConversations({String? role})` → `GET /chat/conversations?role=...`, `createConversation(requestId, participantIds)` → `POST /chat/conversations`, `getMessages(conversationId)` → `GET /chat/conversations/$id/messages`, `markRead(conversationId, {String? role})` → `PUT /chat/conversations/$id/read?role=...`
  - `getOrCreateConversation(requestId, myUserId, otherUserId)` — finds existing conversation by request_id or creates new one
  - WebSocket: `connectChat(Function(Map) onMessage)` → connects to `/ws/chat` with Bearer token, listens for incoming messages, calls `onMessage` callback
  - `sendChatMessage(conversationId, content, {String? senderRole})` → sends JSON to WS: `{"conversation_id", "content", "message_type": "text", "sender_role"}`
  - `disconnectChat()` → closes WebSocket cleanly
  - WebSocket URL: replaces `http://` → `ws://` from `API_URL` (same pattern as `TrackingService`)
  - Uses `IOWebSocketChannel.connect(headers: {'Authorization': 'Bearer $token'})` — same auth pattern as GPS WebSocket
- `ChatProvider` (`chat_provider.dart`): `ChangeNotifier` for chat state
  - Conversations: `fetchConversations({String? role})` → loads conversation list with unread counts
  - Messages: `fetchMessages(conversationId)` → loads message history (reversed for chronological display), `connectToConversation(conversationId)` → WebSocket listener filters messages for active conversation, deduplicates by `id`
  - Send: `sendMessage(conversationId, content, {String? senderRole})` → sends via WebSocket (server echoes back → listener adds to `_messages`)
  - Read: `markRead(conversationId, {String? role})` → marks conversation as read for acting role
  - Lifecycle: `disconnect()` → clears `_activeConversationId`, clears `_messages`, disconnects WebSocket
  - `getOrCreateConversation(requestId, myUserId, otherUserId)` → delegates to service
  - State: `conversations` (list), `messages` (list), `isLoading`, `isLoadingMessages`, `activeConversationId`
- `ChatListScreen` (`chat_list_screen.dart`): conversation list, role-aware
  - Constructor: `ChatListScreen({String? actingRole})` — `'guard'` or `'customer'`
  - Passes `actingRole` to `fetchConversations(role:)` and through to `ChatScreen`
  - Shows unread badge (green pill) per conversation — bold name/message/time when unread
  - Pull-to-refresh, refreshes after returning from `ChatScreen` (updated unread counts)
  - Guard dashboard passes `actingRole: 'guard'`, Hirer dashboard passes `actingRole: 'customer'`
  - **Read-only mode:** extracts `request_status` from conversation data — if `'completed'` or `'cancelled'`, passes `readOnly: true` to `ChatScreen` (disables messaging + calling)
- `ChatScreen` (`chat_screen.dart`): real-time conversation
  - Constructor: `ChatScreen({conversationId, requestId, userName, userRole, actingRole, readOnly = false})`
  - `initState`: fetches messages + connects WebSocket + marks as read
  - Message alignment: `sender_role == actingRole` → right (me), else → left (them) with avatar
  - Sent messages show checkmark (`Icons.done` / `Icons.done_all` for last in group)
  - Send button: passes `senderRole: actingRole` to `sendMessage()`, clears input, scrolls to bottom
  - Auto-scrolls on new messages via `ScrollController`
  - `dispose`: disconnects WebSocket
  - **Read-only mode (`readOnly: true`):** hides call button from AppBar, replaces message input with lock icon banner ("งานสิ้นสุดแล้ว ไม่สามารถส่งข้อความได้" / "Job ended. Messaging is disabled.") — used when `request_status` is `completed` or `cancelled`
- `main.dart`: `ChangeNotifierProvider(create: (_) => ChatProvider(ChatService(apiClient)))` registered in `MultiProvider`

**Notifications (Mobile → Backend):**
- `NotificationService` (`notification_service.dart`): REST client for notification API
  - `listNotifications({unreadOnly, limit, offset})` → `GET /notification/notifications?unread_only=...&limit=...&offset=...` — returns `List<Map<String, dynamic>>`
  - `getUnreadCount()` → `GET /notification/notifications/unread-count` — returns `int` (count from response)
  - `markAsRead(notificationId)` → `PUT /notification/notifications/$id/read`
  - `markAllAsRead()` → `PUT /notification/notifications/read-all`
- `NotificationProvider` (`notification_provider.dart`): `ChangeNotifier` for notification state
  - State: `notifications` (list), `unreadCount` (int), `isLoading`, `error`
  - `fetchNotifications({unreadOnly})` → loads full notification list, updates `unreadCount` from data
  - `fetchUnreadCount()` → lightweight count-only fetch for badge display
  - `markAsRead(id)` → optimistic local update (set `is_read: true`, decrement count), then API call
  - `markAllAsRead()` → sets all local notifications to read, zeros count, then API call
- `NotificationScreen` (`notification_screen.dart`): StatefulWidget with real API data
  - `initState` → `fetchNotifications()`
  - `RefreshIndicator` for pull-to-refresh
  - `_getNotificationStyle(type)` maps `notification_type` → icon/color: `booking_created`→green check, `guard_assigned`→blue work, `guard_en_route`→blue car, `guard_arrived`→green pin, `booking_completed`→green verified, `booking_cancelled`→red cancel, `chat_message`→blue chat, `system`→gray info
  - `_formatRelativeTime(sentAt, isThai)` — relative time: "เมื่อสักครู่", "5 นาทีที่แล้ว", "1 ชั่วโมงที่แล้ว", "3 วันที่แล้ว", "2 สัปดาห์ที่แล้ว"
  - Tap unread → `markAsRead(id)`, AppBar action "อ่านทั้งหมด" → `markAllAsRead()` (shown only when `unreadCount > 0`)
  - Empty state: bell-off icon + "ไม่มีการแจ้งเตือน" / "No notifications"
  - Constructor: `NotificationScreen({bool isGuard = false})` — for future role-specific behavior
- **Bell icon unread badge** — 3 screens show notification bell with red unread count badge:
  - `GuardHomeTab`: `_buildNotificationBell()` → `Stack` + `Positioned` red circle with count, `fetchUnreadCount()` in `initState`, refreshes on return from `NotificationScreen(isGuard: true)`
  - `ServiceSelectionScreen` (hirer): same pattern, navigates to `NotificationScreen(isGuard: false)`
  - `DashboardScreen`: `Consumer<NotificationProvider>` wraps bell icon for badge
- `main.dart`: `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>` registered in `MultiProvider` — recreates with `NotificationService(auth.apiClient)` when auth changes
- i18n: `NotificationStrings` in `app_strings.dart` — `appBarTitle`, `readAll`, `emptyTitle`, `emptySubtitle`, `justNow`, `minutesAgo`, `hoursAgo`, `daysAgo`, `weeksAgo`, `loadError`

**GPS Tracking (Mobile → Backend):**
- **TrackingService** (`tracking_service.dart`): WebSocket + GPS streaming
  - Uses `IOWebSocketChannel.connect(uri, headers: {'Authorization': 'Bearer $token'})` — Bearer token for mobile WS auth
  - Converts `API_URL` from `http://` → `ws://` for WebSocket endpoint `/ws/track`
  - GPS: `Geolocator.getPositionStream(accuracy: high, distanceFilter: 10m)` — streams only when moved ≥10m
  - Sends `GpsUpdate` JSON: `{"lat", "lng", "accuracy", "heading", "speed", "assignment_id": null}`
  - GPS stream starts **only after** WebSocket connected (`_isConnected == true`) — never before
  - Auto-reconnect with exponential backoff (2s, 4s, 6s, 8s, 10s), max 5 retries
  - Reconnect cleans up old `_wsSub` before creating new one (prevents orphaned listeners)
  - Reconnect restarts GPS stream after successful WS reconnect
- **TrackingProvider** (`tracking_provider.dart`): `ChangeNotifier` state management
  - States: `isOnline` (toggle), `isConnecting`, `isConnected` (WS), `lastPosition`, `error`
  - `toggle()` → `goOnline()` / `goOffline()` — wired to `GuardHomeTab` switch
  - Permission errors auto-revert toggle to OFF
- **main.dart**: `ChangeNotifierProvider(create: (_) => TrackingProvider(TrackingService()))` registered in `MultiProvider`
- **GuardHomeTab**: `context.watch<TrackingProvider>()` replaces local `_isReady` state; shows GPS accuracy when online

**Unified SecureGuard Header Pattern (Flutter Mobile):**
- All guard-side screens (4 tabs + 4 detail screens) and hirer profile settings use the same green header design:
  - `Container` with `AppColors.primary` background, `BorderRadius.vertical(bottom: Radius.circular(32))`, `EdgeInsets.fromLTRB(12, 60, 24, 30)` padding
  - Top row: back button (where applicable) + shield icon (white alpha 0.2 bg, rounded 12) + "SecureGuard" title (bold 20 white) + subtitle (13 white alpha 0.9) + optional action icons
  - Screens with tabs (jobs, income, work history): embed `TabBar`/sub-tab navigation inside the green header using `Colors.white.withValues(alpha: 0.15)` pill container, white selected indicator, `AppColors.primary` selected text color
  - Manual top padding (60px) instead of `SafeArea` — provides status bar clearance on all devices
  - Guard home tab header: back arrow → `RoleSelectionScreen(phone)`, greeting text with `authProvider.fullName`, notification bell
  - Detail screens (profile_settings, ratings_reviews, contact_support, work_history): green header + back arrow + shield icon + title
- ❌ ห้ามใช้ `AppBar` หรือ `AppColors.deepBlue` ใน guard/hirer screens — ใช้ custom `Container` header ด้วย `AppColors.primary` เท่านั้น

**Web Admin Map (Reverse Geocoding):**
- `reverseGeocode()` in `lib/api.ts` — Nominatim reverse geocode with ~500m grid cache (capped at 500 entries)
- `batchReverseGeocode()` — deduplicates by grid key, 200ms delay between requests (Nominatim rate limit)
- `MapArea` uses `mapKey` prop to prevent Leaflet "container reused" error on fullscreen toggle

**Nginx Rate Limit:**
- `otp_limit` zone: 3 req/min per IP — applied to `location /auth/otp/`
- `auth_limit` zone: 5 req/s — applied to `location /auth/` (covers `/auth/register/otp`, `/auth/profile/guard`)

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

### Flutter Hot Keys (while `flutter run` is active)

| Key | Action |
|-----|--------|
| `r` | Hot reload (preserve state) |
| `R` | Hot restart (reset state) |
| `h` | List all interactive commands |
| `d` | Detach (leave app running, exit CLI) |
| `c` | Clear the screen |
| `q` | Quit (terminate app + CLI) |

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
subtle          = "2"
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
S3_PUBLIC_URL=http://localhost/minio-files  # Dev: Nginx proxy → MinIO. Production R2: omit (S3_ENDPOINT is already public)
CORS_ALLOWED_ORIGINS=http://localhost:3000
RUST_LOG=info

# OTP / SMS (INET Cheese Digital CSGAPI)
INET_SMS_USERNAME=<username จาก Cheese Digital>
INET_SMS_PASSWORD=<password จาก Cheese Digital>
INET_SMS_SENDER=<sender name ที่ลงทะเบียนกับ INET>
PHONE_VERIFY_TTL_MINUTES=10
DAILY_OTP_LIMIT=10
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
- ❌ ห้าม accept GPS coordinates โดยไม่ validate — ต้องตรวจ lat (-90..90), lng (-180..180), reject (0,0), accuracy/heading/speed ranges ผ่าน `GpsUpdate::validate()`
- ❌ ห้ามให้ non-guard roles (admin/customer) connect WebSocket GPS — `ws_handler` ต้องตรวจ `user.role == "guard"` ก่อน upgrade
- ❌ ห้าม store binary/image ใน PostgreSQL
- ❌ ห้าม expose MinIO/R2 bucket โดยตรง
- ❌ ห้าม accept ไฟล์ที่ไม่ใช่ image/jpeg, image/png, image/webp
- ❌ ห้ามเรียก fetch ตรงใน Frontend — ใช้ `lib/api.ts` (web) หรือ `ApiClient` (mobile) เท่านั้น
- ❌ ห้ามเก็บ JWT ใน localStorage/sessionStorage — ใช้ httpOnly cookie (web) หรือ FlutterSecureStorage (mobile) เท่านั้น
- ❌ ห้ามส่ง JWT token ใน WebSocket URL query params — Web ใช้ cookie auth, Mobile ใช้ Bearer header
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
- ❌ ห้าม return presigned URL ที่มี internal Docker host (`http://minio:9000`) ให้ client — ต้อง rewrite ด้วย `S3_PUBLIC_URL` ก่อนเสมอ (browser ไม่สามารถ resolve `minio` hostname ได้)
- ❌ ห้ามใช้ `audit_middleware` โดยไม่มี turbofish type — ต้องใช้ `audit_middleware::<Arc<AppState>>` เสมอ
- ❌ ห้ามใช้ HTTP status code เป็น `entity_type` ใน audit log — ต้อง derive จาก URL path segment แรก
- ❌ ห้ามใช้ `COUNT(*)` สำหรับ boolean existence check — ใช้ `EXISTS(SELECT 1 ...)` แทน
- ❌ ห้าม FCM config fallback เป็นค่า default (เช่น `"not-set"`) — ต้อง fail-fast ด้วย `AppError`
- ❌ ห้ามสร้าง service โดยไม่เพิ่ม audit middleware — ทุก service ต้องมี `audit_middleware` layer
- ❌ ห้ามเปรียบเทียบ OTP ด้วย `==` — ต้องใช้ `subtle::ConstantTimeEq` เพื่อป้องกัน timing side-channel
- ❌ ห้ามใช้ separate `EXISTS` + `SET` สำหรับ OTP rate limit — ต้องใช้ atomic `SET NX EX` (TOCTOU race)
- ❌ ห้ามใช้ `if count == 1` เพียงอย่างเดียวสำหรับ daily cap TTL — ต้องตรวจ `TTL` หลัง `INCR` เสมอ (crash-recovery)
- ❌ ห้ามทำ OTP attempt counter แบบ SELECT → UPDATE แยก — ต้อง atomic `UPDATE ... WHERE id = (SELECT ... FOR UPDATE)`
- ❌ ห้ามสร้าง `reqwest::Client` ใหม่ทุก SMS request — ต้องใช้ shared client จาก AppState (พร้อม timeout)
- ❌ ห้าม reuse phone_verified_token — ต้อง enforce single-use ด้วย `jti` + Redis `GETDEL`
- ❌ ห้าม reuse profile_token — ต้อง enforce single-use ด้วย `jti` + Redis `GETDEL` เหมือน phone_verified_token
- ❌ ห้ามออก access_token/refresh_token หรือ INSERT session ใน `register_with_otp()` — endpoint ต้อง return HTTP 202 พร้อม `RegisterWithOtpResponse` เท่านั้น (ไม่มี token)
- ❌ ห้ามใช้ plain `INSERT INTO auth.users` ใน `register_with_otp()` — **ต้องใช้ UPSERT** `ON CONFLICT (phone) DO UPDATE SET password_hash=EXCLUDED.password_hash, full_name=EXCLUDED.full_name, approval_status='pending', updated_at=NOW() WHERE auth.users.approval_status='pending'` + `fetch_optional` → None = phone registered with non-pending status → `AppError::Conflict("Please log in instead")`
- ❌ ห้าม accept ราคาติดลบใน service rates — `validate_prices()` ต้องตรวจ `min_price >= 0`, `max_price >= 0`, `base_fee >= 0`
- ❌ ห้าม accept `min_price > max_price` — ต้อง validate ทั้ง create และ update (update ต้อง merge กับค่าเดิมก่อน validate)
- ❌ ห้าม return inactive service rates จาก public GET endpoints — ต้อง filter `WHERE is_active = true` เสมอ
- ❌ ห้าม query `available-guards` โดยไม่ filter `recorded_at > NOW() - INTERVAL '30 minutes'` — guards ที่ offline (ไม่มี GPS update ภายใน 30 นาที) ต้องไม่แสดง
- ❌ ห้ามใช้ `acos()` โดยไม่ clamp ด้วย `LEAST(1.0, GREATEST(-1.0, ...))` ใน Haversine calculation — floating-point rounding อาจทำให้ค่าเกิน [-1,1] → NaN
- ❌ ห้ามให้ non-admin, non-owner assign guard — `assign_guard` handler ต้องตรวจ `request.customer_id == user.user_id` สำหรับ non-admin users
- ❌ ห้ามใช้ shared `_isLoading` flag ใน `BookingProvider` สำหรับ pricing — ต้องใช้ `_isLoadingRates` แยก (ป้องกัน cross-interference กับ guard/customer loading)
- ❌ ห้าม optimistic delete ใน web admin pricing — ต้อง reload list จาก API หลัง delete (`loadServiceRates()`)
- ❌ ห้าม upload ไฟล์ไปยัง S3/MinIO แบบ sequential loop — ใช้ `tokio::task::JoinSet` เพื่อ parallel upload เสมอ
- ❌ ห้าม validate magic bytes ก่อนตรวจ file size — ต้องตรวจ size ก่อนเสมอ (ป้องกัน large allocation ก่อน reject)
- ❌ ห้าม cast `response.data['field'] as String?` — ใช้ `raw is String ? raw : null` เพื่อป้องกัน crash
- ❌ ห้ามเรียก `registerWithOtp()` ใน `RoleSelectionScreen` หรือ `GuardRegistrationScreen` — ต้องเรียกใน `PinSetupScreen._finishSetup()` เท่านั้น (3-step flow: register ก่อน, เลือก role ทีหลัง)
- ❌ ห้ามเรียก `updateRole()` ใน `PinSetupScreen` หรือ `GuardRegistrationScreen` — ต้องเรียกใน `RoleSelectionScreen._onRoleTap()` เท่านั้น
- ❌ ห้าม `update_user_role()` SET role ใน DB ทั้ง guard และ customer path — ต้องแค่ SELECT verify + issue profile_token เท่านั้น → role จะถูก set ใน `submit_guard_profile()` / `submit_customer_profile()` หลัง save สำเร็จ (atomic, no partial state)
- ❌ ห้าม `submit_guard_profile()` สำเร็จโดยไม่ set role='guard' — ต้อง UPDATE role + `invalidate_user_cache()` หลัง UPSERT profile เสมอ
- ❌ ห้าม `submit_customer_profile()` สำเร็จโดยไม่ set role='customer' (เมื่อ role IS NULL) — ต้อง UPDATE role + `invalidate_user_cache()` หลัง UPSERT profile เสมอ
- ❌ ห้ามใช้ profile_token ข้าม purpose — guard token ใช้กับ `submit_customer_profile()` ไม่ได้ และในทางกลับกัน (`decode_profile_token(expected_purpose)` ตรวจ purpose)
- ❌ ห้ามส่ง `phoneVerifiedToken` ไปยัง `RoleSelectionScreen` — token ถูก consume ใน `PinSetupScreen` แล้ว, ส่งแค่ `phone`
- ❌ ห้าม navigate จาก `OtpVerificationScreen` ไป `SetPasswordScreen` — ต้อง navigate ไป `PinSetupScreen` โดยตรง (SetPasswordScreen ถูกลบออกจาก flow หลักแล้ว)
- ❌ ห้าม navigate จาก `OtpVerificationScreen` ไป `PinSetupScreen` ถ้า `pinService.isPinSet == true` — returning user ต้อง skip PinSetup → ลอง registerWithOtp(storedPinHash) → auto-login หรือ PinLoginScreen
- ❌ ห้ามแสดง `PinLockScreen` โดยตรวจเฉพาะ `pinService.isPinSet` — ต้องตรวจ `auth.status == AuthStatus.authenticated` ก่อนเสมอ (iOS Keychain persist ข้าม reinstall)
- ❌ ห้าม navigate จาก `PinLockScreen` ไป dashboard ตรง — ต้องไป `RoleSelectionScreen(phone)` เสมอ เพื่อให้ user เลือก role (guard/customer) ทุกครั้งหลัง unlock
- ❌ ห้าม `await fetchProfile()` ใน `PinLockScreen._navigateToApp()` — ต้อง fire-and-forget เท่านั้น (ป้องกัน 10s+ freeze ถ้า backend ช้า/ล่ม)
- ❌ ห้าม fallback เป็น `unauthenticated` ใน `checkAuthStatus()` เมื่อ `fetchProfile()` fail แต่ tokens ยังอยู่ — ต้อง treat เป็น `authenticated` (network timeout ≠ invalid tokens)
- ❌ ห้าม merge `customer_profiles.full_name` เข้ากับ `users.full_name` ใน backend `get_profile()` — ต้อง return แยกเป็น `full_name` (guard) + `customer_full_name` (customer)
- ❌ ห้ามแสดง `auth.fullName` ตรงใน Hirer screens — ต้องใช้ `auth.customerFullName ?? auth.fullName` เพื่อแสดงชื่อ customer ที่ถูกต้อง
- ❌ ห้าม root-level screens (RoleSelectionScreen, HirerDashboardScreen, GuardDashboardScreen, CustomerRegistrationScreen) ไม่มี `PopScope(canPop: false)` — ต้อง wrap เสมอเพื่อป้องกัน iOS swipe-back black screen
- ❌ ห้ามใช้ `Navigator.pop()` ใน screens ที่ navigate มาด้วย `pushAndRemoveUntil` — ต้องใช้ `pushAndRemoveUntil` หรือ `pushReplacement` ไปหน้าที่ถูกต้องแทน (เช่น ServiceSelectionScreen back → RoleSelectionScreen)
- ❌ ห้ามใช้ `http://10.0.2.2` เป็น default URL สำหรับ iOS Simulator — ต้อง auto-detect ด้วย `Platform.isIOS` → `localhost`, `Platform.isAndroid` → `10.0.2.2`
- ❌ ห้ามบังคับ authenticated user ลงทะเบียนใหม่ใน `RoleSelectionScreen._onRoleTap()` — ถ้า `auth.status == authenticated` ต้องตรวจ `customerApprovalStatus` ก่อน route (approved→dashboard, pending→pending screen, null→registration)
- ❌ ห้ามใช้ `auth.role != 'customer'` เป็น gate ของ `HirerDashboardScreen` — ต้องใช้ `auth.customerApprovalStatus != 'approved'` เพราะ guard ที่เพิ่ม customer profile ยังมี `role='guard'` ใน `auth.users`
- ❌ ห้ามใช้ `authApi.listUsers({ role: 'customer' })` สำหรับหน้า customers — ต้องใช้ `authApi.listCustomerApplicants({ approval_status: 'approved' })` เพราะ guard ที่เพิ่ม customer profile ไม่มี `role='customer'` ใน `auth.users`
- ❌ ห้ามใช้ `authApi.updateApprovalStatus()` สำหรับ customer applicants — ต้องใช้ `authApi.updateCustomerApproval()` ซึ่ง update `customer_profiles.approval_status` (ไม่ใช่ `users.approval_status`)
- ❌ ห้ามใช้ `sqlx::query!` (compile-time macro) ใน `spawn_notification()` ของ booking service — ต้องใช้ `sqlx::query` (runtime) เพราะ notification schema types ไม่ได้อยู่ใน booking crate
- ❌ ห้าม block response path ด้วย notification INSERT — ต้องใช้ `tokio::spawn` (fire-and-forget) เสมอสำหรับ `spawn_notification()`
- ❌ ห้ามลงทะเบียน notification routes `{id}/read` ก่อน `unread-count` / `read-all` — Axum จะ match `unread-count` เป็น `{id}` ถ้าลำดับผิด
- ❌ ห้าม `review_completion()` สำเร็จโดยไม่ส่ง notification ให้ guard — approve ต้อง trigger "งานเสร็จสมบูรณ์" notification
- ❌ ห้าม `submit_review()` สำเร็จโดยไม่ส่ง notification ให้ guard — ต้อง trigger "คะแนนรีวิวใหม่" notification
- ❌ ห้ามใช้ placeholder ratings ใน `list_available_guards()` — ต้อง JOIN `reviews.guard_reviews` ด้วย `AVG(overall_rating)` + `COUNT(*)` สำหรับ real ratings

### Web Admin (Next.js)
- ❌ ห้าม hardcode ข้อความภาษาในหน้า — ต้องใช้ `t.xxx` จาก `useLanguage()` เสมอ
- ❌ ห้ามเพิ่ม translation เฉพาะภาษาเดียว — ต้องเพิ่มทั้ง `th` และ `en` ใน `lib/i18n.ts`
- ❌ ห้ามใช้ icon library อื่นนอกจาก **lucide-react**
- ❌ ห้ามสร้างหน้าใหม่โดยไม่เพิ่มใน Sidebar navigation (`components/Sidebar.tsx`)
- ❌ ห้ามมี `/members` route — ถูกรวมเข้า `/applicants` แล้ว (ใช้ tabs แบ่ง guard/customer)
- ❌ ห้าม import Leaflet components โดยไม่ใช้ `dynamic(() => import(...), { ssr: false })` — Leaflet ต้องการ DOM
- ❌ ห้ามแสดงหน้า map โดยไม่ตรวจ role — ต้อง gate ด้วย `useAuth()` (admin/customer เท่านั้น)
- ❌ ห้าม duplicate `DisplayGuard` type — ใช้จาก `map/types.ts` เท่านั้น
- ❌ ห้ามใช้ `tile.openstreetmap.org` ใน production — ต้องเปลี่ยนเป็น commercial tile provider (Mapbox/Maptiler)
- ❌ ห้ามสร้าง `L.DivIcon` ใหม่ทุก render — ใช้ module-level icon cache
- ❌ ห้าม mount `<Popup>` ทุก `<Marker>` — ใช้ conditional render เฉพาะ selected guard

### Flutter Mobile
- ❌ ห้ามเก็บ JWT tokens หรือ PIN ใน `SharedPreferences` — ใช้ `FlutterSecureStorage` เท่านั้น
- ❌ ห้ามเก็บ plaintext PIN — ต้อง hash ด้วย SHA-256 ก่อน store
- ❌ ห้าม hardcode OTP ในโค้ด — ต้องส่งผ่าน API (`AuthService.verifyOtp()`)
- ❌ ห้ามเรียก API ตรงโดยไม่ผ่าน `ApiClient` — ต้องใช้ Dio interceptor ที่ attach Bearer token อัตโนมัติ
- ❌ ห้าม parse token refresh response ด้วย `response.data['access_token']` ตรง — backend ใช้ ApiResponse wrapper ต้อง parse `response.data['data']['access_token']` เสมอ
- ❌ ห้ามเช็ค auth state แยกในแต่ละ screen — ใช้ `AuthProvider` ผ่าน Provider
- ❌ ห้าม navigate ตรงหลัง login โดยไม่ validate credentials กับ backend ก่อน
- ❌ ห้าม expose bank account number ใน UI ที่ไม่จำเป็น — input ต้อง mask, ปิด autocorrect/suggestions
- ❌ ห้ามเก็บ bank account number เต็มใน SharedPreferences — ต้อง mask (เห็นเฉพาะ 4 หลักสุดท้าย) ก่อน `savePendingProfile()`; full number ส่งไป backend เท่านั้น
- ❌ ห้าม simulate file picking (`_simulatePickFile`) — ต้องใช้ `image_picker` จริง (`ImagePicker().pickImage()`) สำหรับ document upload
- ❌ ห้ามเรียก `isPendingApproval()` + `isRegistered()` แบบ sequential ใน `_onRoleTap()` — ต้องใช้ `Future.wait([...])` parallel เสมอ
- ❌ ห้าม import `latlong2` แบบ full — ต้องใช้ `show LatLng` เพื่อหลีกเลี่ยง conflict กับ `dart:ui.Path`
- ❌ ห้ามแสดงหน้า map โดยไม่ตรวจ role — ต้อง gate ด้วย `AuthProvider` (admin/customer เท่านั้น)
- ❌ ห้าม set `AuthStatus.authenticated` หลัง `registerWithOtp()` — ต้อง set `AuthStatus.pendingApproval` เท่านั้น ห้ามเก็บ token ที่ registration
- ❌ ห้าม navigate ไปหน้า dashboard หรือ PinSetupScreen หลัง registration — ต้องไป `RegistrationPendingScreen` เสมอ (ยกเว้น authenticated user ที่เพิ่ม profile ใหม่ → กลับ dashboard)
- ❌ ห้ามเรียก `setPendingApproval()` สำหรับ authenticated user — ต้องตรวจ `authProvider.isAuthenticated` ก่อน; ถ้า authenticated แล้วห้าม override auth state ด้วย pending flag (จะทำให้ tokens หาย + app แสดง PhoneInputScreen หลัง restart)
- ❌ ห้าม `checkAuthStatus()` เช็ค `isPendingApproval()` ก่อน access token — ต้องเช็ค token ก่อนเสมอ เพราะ pending flag อาจเป็น stale จากการเพิ่ม profile ใหม่ของ authenticated user
- ❌ ห้ามใช้ `AuthService.isRegistered('guard')` เพื่อตรวจสอบว่าควรแสดง Dashboard — ใช้ `context.watch<AuthProvider>().isAuthenticated` แทน (SharedPreferences key อาจไม่ถูก set ในทุก flow)
- ❌ ห้ามใช้ hardcoded mock data ใน Dashboard screens (ชื่อ, avatar, รหัส) — ใช้ `AuthProvider.fullName`, `AuthProvider.phone`, `AuthProvider.avatarUrl` จาก `GET /auth/me`
- ❌ ห้าม login ด้วย email-based endpoint จาก mobile — ใช้ `POST /auth/login/phone` (phone + PIN hash) เท่านั้น
- ❌ ห้าม start GPS stream ก่อน WebSocket connected — `_startGpsStream()` เรียกเฉพาะเมื่อ `_isConnected == true`
- ❌ ห้ามสร้าง WS listener ใหม่โดยไม่ cancel อันเก่า — `_connectWebSocket()` ต้อง `await _wsSub?.cancel()` ก่อนเสมอ (ป้องกัน orphaned subscriptions)
- ❌ ห้ามใช้ local state (`_isReady`) สำหรับ guard online toggle — ใช้ `context.watch<TrackingProvider>().isOnline` เท่านั้น
- ❌ ห้ามใช้ `AppBar` widget หรือ `AppColors.deepBlue` ใน guard/hirer screens — ใช้ custom `Container` header ด้วย `AppColors.primary` + `BorderRadius.vertical(bottom: Radius.circular(32))` เท่านั้น (unified SecureGuard header pattern)
- ❌ ห้ามใช้ `SafeArea` ใน screens ที่มี green header — ใช้ manual top padding (`EdgeInsets.fromLTRB(12, 60, 24, 30)`) แทน
- ❌ ห้ามใช้ shared `_isLoadingGuards` flag ร่วมกับ `_isLoading` หรือ `_isLoadingRates` — ต้องแยก flag สำหรับ available guards loading
- ❌ ห้ามให้ non-owner customer assign guard ไปยัง request ของคนอื่น — backend `assign_guard` ตรวจ `request.customer_id == user.user_id` สำหรับ non-admin
- ❌ ห้าม `list_conversations` ใช้ `sender_id` เพื่อ determine ชื่อคู่สนทนา — ต้องใช้ `acting_role` query param (`?role=guard|customer`) + JOIN ผ่าน `booking.guard_requests` + `booking.assignments` เพื่อ resolve ชื่อ guard/customer ที่ถูกต้อง (same user อาจเป็นทั้ง guard และ customer)
- ❌ ห้าม determine message alignment ด้วย `sender_id == userId` — ต้องใช้ `sender_role == actingRole` เพราะ same user สามารถส่งข้อความเป็นทั้ง guard และ customer ในคนละ conversation
- ❌ ห้ามส่งข้อความผ่าน chat WebSocket โดยไม่มี `sender_role` — ต้องส่ง `sender_role` (`'guard'` / `'customer'`) เสมอเพื่อให้ role-based alignment ทำงานถูกต้อง
- ❌ ห้าม `ChatListScreen` / `ChatScreen` ไม่รับ `actingRole` param — ต้องส่ง `actingRole` จาก dashboard ที่เรียก (guard dashboard → `'guard'`, hirer dashboard → `'customer'`) เพื่อให้ name resolution, message alignment, และ unread count ทำงานถูกต้อง
- ❌ ห้ามใช้ mock/hardcoded data ใน `NotificationScreen` — ต้องใช้ `NotificationProvider` ที่ fetch จาก API จริง
- ❌ ห้ามแสดง bell icon บน dashboard โดยไม่มี unread badge — ต้อง `fetchUnreadCount()` ใน `initState` + แสดง red badge ด้วย `Stack` + `Positioned` เมื่อ `unreadCount > 0`
- ❌ ห้ามใช้ `ChangeNotifierProvider` สำหรับ `NotificationProvider` — ต้องใช้ `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>` เพื่อ recreate เมื่อ auth เปลี่ยน (token ใหม่)
- ❌ ห้ามให้ send message หรือ call ใน `ChatScreen` เมื่อ `request_status` เป็น `completed` หรือ `cancelled` — ต้อง pass `readOnly: true` จาก `ChatListScreen` → `ChatScreen` เพื่อ disable input + hide call button
- ❌ ห้ามแสดงพิกัดดิบ (e.g., "13.756300, 100.501800") ใน booking address field — ต้อง reverse geocode ผ่าน Nominatim แล้วแสดงชื่อสถานที่ (road/suburb/district) แทน; `_lat`/`_lng` เก็บค่าพิกัดจริงแยก
- ❌ ห้าม `_MapPickerSheet` return แค่ `LatLng` — ต้อง return record type `({LatLng latLng, String? displayName})` เพื่อส่งชื่อสถานที่กลับไปยัง booking screen