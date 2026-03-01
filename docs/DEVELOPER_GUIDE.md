# Developer Guide -- Security Guard Dispatch System

# (คู่มือนักพัฒนา -- ระบบเรียก รปภ.)

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Prerequisites and Tool Versions](#2-prerequisites-and-tool-versions)
3. [Repository Setup](#3-repository-setup)
4. [Running Services](#4-running-services)
5. [Coding Conventions](#5-coding-conventions)
6. [Adding a New API Endpoint](#6-adding-a-new-api-endpoint)
7. [Adding a New Web Admin Page](#7-adding-a-new-web-admin-page)
8. [Adding a New Mobile Screen](#8-adding-a-new-mobile-screen)
9. [Database Migrations](#9-database-migrations)
10. [File Upload Guidelines](#10-file-upload-guidelines)
11. [WebSocket Development](#11-websocket-development)
12. [Security Checklist](#12-security-checklist)
13. [Testing](#13-testing)
14. [Docker and Deployment](#14-docker-and-deployment)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Introduction

This guide covers everything you need to develop, test, and deploy the Security Guard
Dispatch System (ระบบเรียก รปภ.). It is intended for backend engineers, frontend
developers, and mobile developers working within this monorepo.

คู่มือนี้ครอบคลุมทุกขั้นตอนที่จำเป็นสำหรับการพัฒนา ทดสอบ และ deploy ระบบเรียก รปภ.
เหมาะสำหรับนักพัฒนาทั้ง backend, frontend และ mobile ที่ทำงานภายใน monorepo นี้

The system is a real-time, city/country-scale platform supporting GPS tracking,
push notifications, video/audio calls, and chat with image attachments. The
architecture follows a microservices pattern with 6 Rust services, 1 Node.js
service (MediaSoup), a Next.js web admin, and a Flutter mobile app -- all
orchestrated via Docker Compose behind an Nginx reverse proxy.

For the full system architecture and all coding rules, refer to `CLAUDE.md` at the
repository root. This guide provides practical, step-by-step workflows built on
top of those rules.

---

## 2. Prerequisites and Tool Versions

Install the following tools before working on this project:

| Tool               | Version         | Notes                                      |
|--------------------|-----------------|--------------------------------------------|
| Rust               | Latest stable   | Install via `rustup`                       |
| Cargo              | (bundled)       | Comes with Rust                            |
| Node.js            | 20+             | Required for MediaSoup and web-admin       |
| npm                | (bundled)       | Comes with Node.js                         |
| Flutter            | 3.x             | For mobile app development                 |
| Dart               | (bundled)       | Comes with Flutter                         |
| Docker             | 24+             | Container runtime                          |
| Docker Compose     | v2+             | Orchestration (bundled with Docker Desktop)|
| sqlx-cli           | Latest          | Database migration tool                    |
| mc (MinIO Client)  | Latest          | Optional -- for manual bucket management   |

### Installing sqlx-cli

```bash
cargo install sqlx-cli --features postgres
```

This provides the `sqlx` command for running and creating migrations with
compile-time query checking.

### Installing MinIO Client (optional)

```bash
# macOS
brew install minio/stable/mc

# Linux
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc && sudo mv mc /usr/local/bin/
```

---

## 3. Repository Setup

### Clone and Configure

```bash
git clone <repo-url>
cd guard-dispatch
cp .env.example .env
```

Open `.env` and review the values. Key variables to verify:

- `DATABASE_URL` -- PostgreSQL connection string
- `REDIS_PASSWORD` -- Must match the password used in `REDIS_CACHE_URL` and `REDIS_PUBSUB_URL`
- `JWT_SECRET` -- Use a strong random string, minimum 64 characters
- `S3_ACCESS_KEY` / `S3_SECRET_KEY` -- MinIO credentials (do NOT use default `minioadmin`)
- `FCM_SERVER_KEY` / `FCM_PROJECT_ID` -- Firebase credentials for push notifications

### Start All Containers

```bash
docker compose up -d
```

This starts all 12 containers: nginx-gateway, web-admin, 5 Rust services,
mediasoup-server, postgres-db, redis-cache, redis-pubsub, and minio.

### Wait for Health Checks and Verify

```bash
docker compose ps
```

All containers should show `healthy` or `running` status. PostgreSQL and Redis
have built-in health checks; services depend on them via `condition: service_healthy`.

### Create the MinIO Bucket (first-time only)

The MinIO container starts empty. You must create the file storage bucket:

```bash
# Configure mc alias (adjust credentials to match your .env)
mc alias set local http://localhost:9000 <S3_ACCESS_KEY> <S3_SECRET_KEY>

# Create the bucket
mc mb local/guard-dispatch-files
```

If MinIO ports are not exposed to host (production config), exec into the container:

```bash
docker exec -it minio mc mb /data/guard-dispatch-files
```

---

## 4. Running Services

### Option A: All via Docker (Recommended)

```bash
docker compose up -d
```

This is the recommended approach. All services, databases, and infrastructure
start together with correct networking. The Nginx gateway is accessible at
`http://localhost:80`.

### Option B: Individual Rust Service (Local Development)

If you want faster iteration on a single service, you can run it locally while
keeping infrastructure in Docker:

```bash
# Start only infrastructure
docker compose up -d postgres-db redis-cache redis-pubsub minio

# Run a specific Rust service (e.g., auth)
# Requires DATABASE_URL pointing to localhost (adjust .env or export)
export DATABASE_URL=postgresql://guard_user:guard_pass@localhost:5432/guard_dispatch_db
cargo run -p auth
```

Note: When running services locally, you need to expose the database port
temporarily or connect via Docker network. The standard Docker Compose config
does not expose infrastructure ports to host for security.

### Option C: Web Admin Development

```bash
cd frontend/web
npm install
npm run dev
```

The dev server starts at `http://localhost:3000`. In development mode, there is
no basePath prefix. The production Docker build uses basePath `/pguard-app`
(configured via `NEXT_PUBLIC_BASE_PATH`).

### Option D: Flutter Mobile Development

```bash
cd frontend/mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:80
```

### Device URL Table

When running the Flutter app, the API URL depends on the target device:

| Device              | API_URL                    | Notes                                    |
|---------------------|----------------------------|------------------------------------------|
| Android Emulator    | `http://10.0.2.2:80`      | 10.0.2.2 maps to host machine localhost  |
| iOS Simulator       | `http://localhost:80`      | Simulator shares host network            |
| Physical Device     | `http://<LAN_IP>:80`      | Use your machine's LAN IP address        |

Example for physical device:

```bash
flutter run --dart-define=API_URL=http://192.168.1.100:80
```

---

## 5. Coding Conventions

### 5.1 Rust Backend

(กฎการเขียนโค้ด Rust -- ต้องปฏิบัติตามอย่างเคร่งครัด)

**Axum 0.8 Route Syntax**

Always use `/{id}` syntax for path parameters, never `:id`:

```rust
// Correct
Router::new().route("/{id}", get(get_item))

// Wrong -- this is the old Axum syntax
Router::new().route("/:id", get(get_item))
```

**SQLx Compile-Time Macros Only**

Use `query!` and `query_as!` exclusively. Never use raw string queries:

```rust
// Correct
let user = sqlx::query_as!(User, "SELECT * FROM auth.users WHERE id = $1", user_id)
    .fetch_optional(&pool)
    .await?;

// Wrong -- raw string query without compile-time checking
let user = sqlx::query("SELECT * FROM auth.users WHERE id = $1")
    .bind(user_id)
    .fetch_optional(&pool)
    .await?;
```

**Error Handling**

Every function must return `Result<T, AppError>`. Never use `.unwrap()` in
production code:

```rust
// Correct
let config = std::env::var("JWT_SECRET")
    .map_err(|_| AppError::Internal("JWT_SECRET not set".into()))?;

// Wrong
let config = std::env::var("JWT_SECRET").unwrap();
```

**Stateless Services**

All session data and shared state must be stored in Redis. Services must not
keep session information in memory.

**Password Hashing**

Argon2 is CPU-intensive and must run inside `spawn_blocking()` to avoid blocking
the async runtime:

```rust
let hash = tokio::task::spawn_blocking(move || {
    argon2::hash_encoded(password.as_bytes(), &salt, &config)
}).await??;
```

**JWT Key Caching**

Use pre-computed keys from `JwtConfig` stored in AppState:

```rust
// Correct -- uses cached keys
let token = encode_jwt_with_key(&claims, &state.jwt_config.encoding_key)?;
let claims = decode_jwt_with_key(&token, &state.jwt_config.decoding_key)?;

// Wrong -- creates new keys every request
let token = encode_jwt(&claims, &secret)?;
```

The `HasJwtSecret` trait's `decoding_key()` method must return a reference
(`&DecodingKey`), not an owned value, for zero-copy performance.

**Redis Connection Pattern**

Store `redis::aio::MultiplexedConnection` in AppState. Clone it for each
operation (cloning is cheap -- it shares the underlying connection):

```rust
// In handler
let mut conn = state.redis_conn.clone();
redis::cmd("GET").arg(&key).query_async(&mut conn).await?;
```

Never call `get_multiplexed_tokio_connection()` per request.

**Cache Updates**

Use `SET_EX` for atomic cache overwrite. Never do a separate `DEL` then `SET_EX`:

```rust
// Correct -- atomic overwrite
redis::cmd("SET").arg(&key).arg(&value).arg("EX").arg(3600)
    .query_async(&mut conn).await?;

// Wrong -- race condition between DEL and SET
redis::cmd("DEL").arg(&key).query_async(&mut conn).await?;
redis::cmd("SET").arg(&key).arg(&value).arg("EX").arg(3600)
    .query_async(&mut conn).await?;
```

**Concurrent I/O**

Use `tokio::join!` for independent database and Redis operations:

```rust
let (db_result, cache_result) = tokio::join!(
    save_to_db(&pool, &data),
    update_cache(&mut conn, &data)
);
```

**Audit Middleware**

Always use the turbofish type annotation when applying audit middleware:

```rust
// Correct
.layer(middleware::from_fn_with_state(
    state.clone(),
    audit_middleware::<Arc<AppState>>
))

// Wrong -- missing turbofish
.layer(middleware::from_fn_with_state(state.clone(), audit_middleware))
```

**CORS**

Always use the shared CORS builder. Never use `CorsLayer::permissive()`:

```rust
// Correct
let cors = shared::config::build_cors_layer();

// Wrong
let cors = CorsLayer::permissive();
```

**Boolean Existence Checks**

Use `SELECT EXISTS(SELECT 1 ...)` instead of `SELECT COUNT(*)`:

```rust
// Correct
let exists = sqlx::query_scalar!(
    "SELECT EXISTS(SELECT 1 FROM booking.assignments WHERE request_id = $1 AND guard_id = $2)",
    request_id, guard_id
).fetch_one(&pool).await?;

// Wrong -- scans all matching rows
let count = sqlx::query_scalar!(
    "SELECT COUNT(*) FROM booking.assignments WHERE request_id = $1 AND guard_id = $2",
    request_id, guard_id
).fetch_one(&pool).await?;
```

---

### 5.2 Next.js Web Admin

(กฎการเขียนโค้ด Next.js -- ใช้ i18n ทุกหน้า ห้าม hardcode ภาษา)

**Internationalization**

Always use the `useLanguage()` hook for all displayed text. Never hardcode
Thai or English strings directly in components:

```tsx
// Correct
const { t } = useLanguage();
return <h1>{t.dashboard.title}</h1>;

// Wrong -- hardcoded string
return <h1>แดชบอร์ด</h1>;
```

**Translations**

All translation keys live in `lib/i18n.ts`. When adding new text, always add
both `th` and `en` entries:

```typescript
// In lib/i18n.ts
export const translations = {
  th: {
    myPage: {
      title: "หัวข้อหน้า",
      description: "คำอธิบาย",
    },
  },
  en: {
    myPage: {
      title: "Page Title",
      description: "Description",
    },
  },
};
```

**Conditional ClassNames**

Use `cn()` from `@/lib/utils` (clsx + tailwind-merge):

```tsx
import { cn } from "@/lib/utils";

<div className={cn("p-4 rounded-lg", isActive && "bg-blue-500")} />
```

**Icons**

Use `lucide-react` exclusively. Do not import from any other icon library:

```tsx
import { Shield, MapPin, Users } from "lucide-react";
```

**API Calls**

Route all backend calls through `lib/api.ts`. Never use `fetch()` directly:

```tsx
// Correct
import { api } from "@/lib/api";
const data = await api.get("/booking/requests");

// Wrong
const data = await fetch("/booking/requests");
```

**Authentication**

Auth state is managed by `AuthProvider` using cookie-based sessions. Never store
JWT tokens in localStorage or sessionStorage.

**Sidebar Navigation**

When creating a new page, you must add it to the navigation array in
`components/Sidebar.tsx`. The sidebar currently has 14 items.

---

### 5.3 Flutter Mobile

(กฎการเขียนโค้ด Flutter -- ใช้ Provider pattern, เก็บ token ใน SecureStorage)

**State Management**

Use the Provider pattern with `ChangeNotifierProvider`. The app wraps providers
in `MultiProvider` at `main.dart`:

```dart
// Access auth state
final auth = context.read<AuthProvider>();
final isLoggedIn = context.watch<AuthProvider>().isAuthenticated;
```

**API Client**

Always use `ApiClient` (Dio-based) with the built-in JWT interceptor. Never call
HTTP APIs directly:

```dart
// Correct
final response = await apiClient.get('/booking/requests');

// Wrong -- bypasses JWT interceptor
final response = await Dio().get('http://..../booking/requests');
```

The interceptor automatically:
- Attaches the Bearer token from FlutterSecureStorage
- Refreshes expired tokens and retries failed requests on 401
- Skips auth for public endpoints (`/auth/login`, `/auth/register`)

**Secure Storage**

Use `FlutterSecureStorage` for all sensitive data (JWT tokens, PIN hashes).
`SharedPreferences` is only permitted for non-sensitive preferences like language
selection or onboarding flags:

```dart
// Correct -- tokens in secure storage
final storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: token);

// Wrong -- tokens in shared preferences
final prefs = await SharedPreferences.getInstance();
prefs.setString('access_token', token);  // INSECURE
```

**PIN Security**

Always hash PINs with SHA-256 before storing:

```dart
import 'package:crypto/crypto.dart';
final hashedPin = sha256.convert(utf8.encode(pin)).toString();
await secureStorage.write(key: 'pin_hash', value: hashedPin);
```

**Bilingual Support**

Use `LanguageProvider.of(context).isThai` for conditional language rendering.
String resources are defined in `l10n/` files.

---

## 6. Adding a New API Endpoint

Follow these steps to add a new endpoint to any Rust service. This example
assumes you are adding an endpoint to the booking service.

(ขั้นตอนเพิ่ม endpoint ใหม่ -- ทำตามลำดับเพื่อให้ครบทุกส่วน)

### Step 1: Define Model Structs

In `models.rs`, add your request/response structs with the required derives:

```rust
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct CreateItemRequest {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ItemResponse {
    pub id: uuid::Uuid,
    pub name: String,
    pub description: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}
```

### Step 2: Write Business Logic

In `service.rs`, implement the core logic returning `Result<T, AppError>`:

```rust
pub async fn create_item(
    pool: &sqlx::PgPool,
    req: CreateItemRequest,
) -> Result<ItemResponse, AppError> {
    let item = sqlx::query_as!(
        ItemResponse,
        r#"INSERT INTO booking.items (name, description)
           VALUES ($1, $2)
           RETURNING id, name, description, created_at"#,
        req.name,
        req.description,
    )
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::Internal(format!("Failed to create item: {}", e)))?;

    Ok(item)
}
```

### Step 3: Create the Handler

In `handlers.rs`, extract `State`, `AuthUser`, and `Json`:

```rust
#[utoipa::path(
    post,
    path = "/items",
    request_body = CreateItemRequest,
    responses(
        (status = 201, description = "Item created", body = ItemResponse),
        (status = 400, description = "Invalid input"),
        (status = 401, description = "Unauthorized"),
    ),
    security(("bearer_auth" = []))
)]
pub async fn create_item_handler(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<CreateItemRequest>,
) -> Result<Json<ItemResponse>, AppError> {
    // Authorization check -- never ignore the user parameter
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".into()));
    }

    let item = service::create_item(&state.db_pool, req).await?;
    Ok(Json(item))
}
```

### Step 4: Register the Route

In `main.rs`, add the route to the service router:

```rust
let app = Router::new()
    .route("/items", post(handlers::create_item_handler))
    // ... existing routes
    .with_state(state.clone())
    .layer(middleware::from_fn_with_state(
        state.clone(),
        audit_middleware::<Arc<AppState>>
    ));
```

### Step 5: Update OpenAPI Annotations

The `#[utoipa::path(...)]` annotation on the handler (Step 3) defines the
endpoint metadata. Make sure the `path` matches the registered route.

### Step 6: Update OpenApi Derive Paths

In `main.rs`, add the handler to the `#[derive(OpenApi)]` paths list:

```rust
#[derive(OpenApi)]
#[openapi(
    paths(
        handlers::create_item_handler,
        // ... existing handlers
    ),
    components(schemas(CreateItemRequest, ItemResponse)),
    modifiers(&SecurityAddon),
)]
struct ApiDoc;
```

### Step 7: Verify

Audit middleware is applied at the router level (Step 4), so it automatically
covers the new route. No additional configuration is needed.

Start the service and visit `http://localhost:<port>/docs` to confirm the
endpoint appears in Swagger UI.

---

## 7. Adding a New Web Admin Page

(ขั้นตอนเพิ่มหน้าใหม่ใน Web Admin -- อย่าลืม i18n และ Sidebar)

### Step 1: Create the Page File

Create a new directory and `page.tsx` under the dashboard route group:

```
frontend/web/app/(dashboard)/my-page/page.tsx
```

```tsx
"use client";

import { useLanguage } from "@/components/LanguageProvider";
import { cn } from "@/lib/utils";
import { FileText } from "lucide-react";

export default function MyPage() {
  const { t } = useLanguage();

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-3">
        <FileText className="h-6 w-6 text-blue-600" />
        <h1 className="text-2xl font-bold">{t.myPage.title}</h1>
      </div>
      <p className="text-slate-600">{t.myPage.description}</p>
    </div>
  );
}
```

### Step 2: Add i18n Keys

In `lib/i18n.ts`, add both Thai and English translations:

```typescript
// Inside the th object
myPage: {
  title: "หน้าของฉัน",
  description: "คำอธิบายหน้านี้",
},

// Inside the en object
myPage: {
  title: "My Page",
  description: "Description for this page",
},
```

Update the `TranslationStructure` type definition to include the new keys.

### Step 3: Add to Sidebar Navigation

In `components/Sidebar.tsx`, add an entry to the navigation array:

```tsx
{
  name: t.sidebar.myPage,  // Add this key to i18n as well
  href: "/my-page",
  icon: FileText,
},
```

### Step 4: Use Standard Patterns

Follow these UI conventions:
- Use `useLanguage()` for all displayed text
- Use `cn()` for conditional classNames
- Use only `lucide-react` icons
- Use `lib/api.ts` for all backend calls
- Use `AuthProvider` for auth state

---

## 8. Adding a New Mobile Screen

(ขั้นตอนเพิ่มหน้าจอใหม่ใน Flutter -- ใช้ Provider และ ApiClient)

### Step 1: Create the Screen File

Create a new file under the screens directory:

```
frontend/mobile/lib/screens/my_screen.dart
```

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Use LanguageProvider for bilingual support

    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

### Step 2: Add Localized Strings

Add string entries in the `l10n/` language files for both Thai and English.

### Step 3: Wire Navigation

Connect the screen from its parent using `Navigator.push()` or your routing
setup:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const MyScreen()),
);
```

### Step 4: Use ApiClient for API Calls

```dart
final apiClient = context.read<ApiClient>();
final response = await apiClient.get('/my-endpoint');
```

### Step 5: Bilingual Text

```dart
final isThai = LanguageProvider.of(context).isThai;
Text(isThai ? 'สวัสดี' : 'Hello');
```

---

## 9. Database Migrations

(การจัดการ migration -- ห้ามแก้ไขไฟล์ migration เดิมที่รันไปแล้ว)

### Current Migrations

The project uses sequential numbering. Existing migrations:

```
database/migrations/
  001_create_auth_schema.sql
  002_create_booking_schema.sql
  003_create_tracking_schema.sql
  004_create_notification_schema.sql
  005_create_chat_schema.sql
  006_create_audit_schema.sql
  007_add_booking_indexes.sql
```

### Creating a New Migration

```bash
sqlx migrate add description_here --source database/migrations
```

This creates a timestamped file. Rename it to follow the sequential pattern
(e.g., `008_add_new_table.sql`).

### Running Migrations

```bash
# Ensure DATABASE_URL is set
export DATABASE_URL=postgresql://guard_user:guard_pass@localhost:5432/guard_dispatch_db

# Run all pending migrations
sqlx migrate run --source database/migrations
```

In Docker, migrations run automatically on first PostgreSQL startup via the
`/docker-entrypoint-initdb.d` volume mount.

### Rules

- Use sequential numbering: 001, 002, 003, etc.
- Never modify an existing migration that has already been applied.
- Use `CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS` for safety.
- New tables must be placed in the appropriate schema (`auth`, `booking`,
  `tracking`, `notification`, `chat`, `audit`).
- Always include appropriate indexes for columns used in WHERE clauses and joins.

---

## 10. File Upload Guidelines

(กฎการ upload ไฟล์ -- ต้อง validate ทั้ง MIME type และ magic bytes)

### Constraints

- Maximum file size: **10 MB** per file
- Allowed formats: **JPEG, PNG, WEBP** only
- Storage: MinIO (development) or Cloudflare R2 (production)
- Database: Store only URL/file_key -- never store binary data in PostgreSQL

### Magic Bytes Validation

You must validate file content by checking magic bytes. Do not trust the
client-provided Content-Type header alone:

| Format | Magic Bytes                              | Hex Values                       |
|--------|------------------------------------------|----------------------------------|
| JPEG   | First 3 bytes                            | `FF D8 FF`                       |
| PNG    | First 8 bytes                            | `89 50 4E 47 0D 0A 1A 0A`       |
| WEBP   | Bytes 0-3 = `RIFF`, bytes 8-11 = `WEBP` | `52 49 46 46 .... 57 45 42 50`   |

Example validation in Rust:

```rust
fn validate_magic_bytes(data: &[u8]) -> Result<&'static str, AppError> {
    if data.len() >= 3 && data[..3] == [0xFF, 0xD8, 0xFF] {
        Ok("jpeg")
    } else if data.len() >= 8 && data[..8] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
        Ok("png")
    } else if data.len() >= 12 && &data[..4] == b"RIFF" && &data[8..12] == b"WEBP" {
        Ok("webp")
    } else {
        Err(AppError::BadRequest("Unsupported file format".into()))
    }
}
```

### Signed URLs

All file access must use signed URLs with a 1-hour expiry. Never expose the
MinIO/R2 bucket directly.

### File Key Format

```
chat/{conversation_id}/{uuid}.{ext}
```

Example: `chat/550e8400-e29b-41d4-a716-446655440000/a1b2c3d4.jpeg`

---

## 11. WebSocket Development

(การพัฒนา WebSocket -- ห้ามส่ง token หรือ sensitive data ใน URL)

### GPS Tracking

- Endpoint: `ws://localhost/ws/track`
- Purpose: Real-time GPS location updates from guards
- Send: `GpsUpdate` JSON (latitude, longitude, timestamp)
- Receive: Acknowledgment message
- Performance target: < 3 seconds latency

### Chat

- Endpoint: `ws://localhost/ws/chat`
- Purpose: Real-time messaging between guards, customers, and admins
- Send: `IncomingChatMessage` JSON
- Receive: `OutgoingChatMessage` JSON
- Performance target: < 1 second delivery

### Authentication

WebSocket connections authenticate via cookies, which are sent automatically
during the HTTP upgrade handshake. This approach:

- Works with the existing httpOnly cookie setup
- Avoids exposing tokens in URL query parameters (which appear in logs)
- Requires same-origin or correctly configured SameSite cookie settings

**Never send JWT tokens in WebSocket URL query parameters.**

### Sensitive Data After Connect

Sensitive identifiers like `conversation_id` must be sent as a message after the
WebSocket connection is established. Never include them in the URL:

```javascript
// Correct -- send conversation_id as first message
const ws = new WebSocket("ws://localhost/ws/chat");
ws.onopen = () => {
  ws.send(JSON.stringify({ action: "join", conversation_id: "abc-123" }));
};

// Wrong -- conversation_id in URL
const ws = new WebSocket("ws://localhost/ws/chat?conversation_id=abc-123");
```

---

## 12. Security Checklist

(รายการตรวจสอบความปลอดภัย -- ต้องปฏิบัติตามทุกข้อก่อน merge)

### JWT and Authentication

- JWT validation is required on all endpoints except `/auth/login` and `/auth/register`
- Cookie configuration:
  - `access_token`: httpOnly, Secure, SameSite=Lax, Path=/
  - `refresh_token`: httpOnly, Secure, SameSite=Lax, Path=/auth
  - `logged_in`: Secure (non-httpOnly), SameSite=Lax -- marker cookie for frontend
- Refresh token rotation must be atomic (single UPDATE...WHERE...RETURNING query)
- Session limit: maximum 5 sessions per user; evict oldest when exceeded
- Login error messages must not reveal whether an email exists in the system

### CORS

- Use `shared::config::build_cors_layer()` exclusively
- Never use `CorsLayer::permissive()`
- Origins are read from `CORS_ALLOWED_ORIGINS` environment variable (comma-separated)
- Default for development: `http://localhost:3000`

### Redis Security

- Both Redis instances (cache and pubsub) must be password-protected
- Never log Redis URLs containing passwords in plaintext -- use `redact_redis_url()`
- Store `MultiplexedConnection` in AppState; never reconnect per request

### Audit Logging

- Audit middleware must be present on all 5 Rust services (auth, booking, tracking, notification, chat)
- `entity_type` is derived from the first URL path segment (e.g., `/auth/login` -> `"auth"`)
- Never use HTTP status codes as entity_type
- Audit log persistence is fire-and-forget via `tokio::spawn` -- never block the response
- IP address: prefer `X-Real-IP`, fallback to rightmost `X-Forwarded-For` entry

### Authorization (IDOR Prevention)

- Every data-access endpoint must perform authorization checks
- Never use `_user: AuthUser` (ignoring the user) on endpoints that access user-specific data
- Tracking: guards access only their own location; admins/customers access all
- Booking: verify the user is the owner, assigned guard, or admin
- Chat: non-admin users must be participants; admins bypass the check
- Use `EXISTS(SELECT 1 ...)` for boolean permission checks

### FCM Configuration

- `FcmConfig::from_env()` must fail-fast with `AppError` if environment variables are missing
- Never fallback to default values like `"not-set"`

### Network Isolation

- Only the Nginx container exposes ports to the host (80/443)
- All other services use `expose` (internal only) in Docker Compose
- Database, Redis, and MinIO are never directly accessible from outside Docker

### Docker Security

- All Dockerfiles must use a non-root user (`appuser`) in the runtime stage
- Binaries must be stripped in the runtime stage to reduce image size
- MinIO credentials must be set via environment variables (never use default `minioadmin`)

---

## 13. Testing

### Rust Tests

```bash
# Run all workspace tests
cargo test --workspace

# Run tests for a specific service
cargo test -p auth
cargo test -p booking
cargo test -p tracking
cargo test -p notification
cargo test -p chat
cargo test -p shared

# Run tests with output visible
cargo test --workspace -- --nocapture

# Run a specific test by name
cargo test -p auth test_login_success
```

### SQLx Prepare (for CI/offline mode)

When running tests in CI or without a live database, prepare the query metadata:

```bash
# With DATABASE_URL pointing to a running PostgreSQL instance
cargo sqlx prepare --workspace
```

This generates `.sqlx/` metadata files that enable compile-time query checking
without a live database connection.

### Flutter Tests

```bash
cd frontend/mobile
flutter test

# Run a specific test file
flutter test test/auth_test.dart

# Run with coverage
flutter test --coverage
```

### Web Admin Tests

```bash
cd frontend/web
npm test

# Run in watch mode
npm test -- --watch
```

---

## 14. Docker and Deployment

### Development Environment

```bash
# Start all services
docker compose up -d

# View logs for a specific service
docker compose logs -f rust-auth

# Restart a single service after code changes
docker compose up -d --build rust-auth

# Stop everything
docker compose down

# Stop and remove volumes (full reset)
docker compose down -v
```

### Production Environment

The production setup uses a separate overlay file:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Key production differences:
- Web admin builds with basePath `/pguard-app` (via `NEXT_PUBLIC_BASE_PATH`)
- Nginx configured with SSL certificates
- MinIO replaced by Cloudflare R2 (change `S3_ENDPOINT`)
- Stricter resource limits

### Dockerfile Standards

All Rust service Dockerfiles follow these rules:
- Multi-stage builds (builder stage + minimal runtime stage)
- Non-root user (`appuser`) in the runtime stage
- Stripped binaries to reduce image size
- No default credentials

Example runtime stage pattern:

```dockerfile
FROM debian:bookworm-slim
RUN adduser --disabled-password --gecos '' appuser
COPY --from=builder /app/target/release/service /usr/local/bin/service
RUN strip /usr/local/bin/service
USER appuser
CMD ["service"]
```

### CI/CD

The project uses GitHub Actions:

- `.github/workflows/ci.yml` -- Runs on every push and pull request:
  - Rust: `cargo check`, `cargo clippy`, `cargo test`
  - Web: `npm ci`, `npm run build`, `npm test`
  - Flutter: `flutter test`

- `.github/workflows/deploy.yml` -- Auto-deploys on merge to `main`:
  - Builds Docker images
  - Pushes to container registry
  - Deploys to production

### Branch Strategy

| Branch       | Purpose                          | Deploy Target |
|-------------|----------------------------------|---------------|
| `main`      | Production (protected, auto-deploy) | Production   |
| `develop`   | Integration branch               | Staging       |
| `feature/*` | Individual features              | None          |
| `hotfix/*`  | Urgent production fixes          | Production    |

---

## 15. Troubleshooting

### "SQLx offline mode" or Compile Errors in CI

SQLx compile-time macros require either a live database or prepared metadata.

**Fix:** Run `cargo sqlx prepare --workspace` with `DATABASE_URL` pointing to a
running PostgreSQL instance, then commit the `.sqlx/` directory.

### "Redis connection refused"

Redis requires password authentication. The most common cause is a mismatch
between the password in `.env` and the Redis container configuration.

**Fix:** Verify that `REDIS_PASSWORD` in `.env` matches the password embedded in
`REDIS_CACHE_URL` and `REDIS_PUBSUB_URL`. Restart Redis containers after changes.

### "MinIO bucket not found" or "NoSuchBucket"

The MinIO container starts with no buckets. The chat service will fail to upload
files until the bucket exists.

**Fix:** Create the bucket manually:

```bash
docker exec -it minio mc mb /data/guard-dispatch-files
```

Or using the mc client from your host (if ports are exposed):

```bash
mc alias set local http://localhost:9000 <access-key> <secret-key>
mc mb local/guard-dispatch-files
```

### "CORS error" in Browser Console

The browser blocks requests when the origin does not match the allowed list.

**Fix:** Check that `CORS_ALLOWED_ORIGINS` in `.env` includes your frontend URL.
For development, this should be `http://localhost:3000`. Multiple origins can be
comma-separated: `http://localhost:3000,https://yourdomain.com`

### "Cookie not sent on WebSocket upgrade"

WebSocket connections may not include cookies if the connection crosses origins
or the SameSite policy blocks them.

**Fix:** Ensure the WebSocket endpoint is on the same origin as the frontend
(both served through Nginx on port 80/443). Verify that cookies are set with
`SameSite=Lax` (not `Strict`, which blocks WebSocket upgrades from some contexts).

### "Argon2 panic" or Async Runtime Blocked

Argon2 password hashing is CPU-intensive. Running it directly in an async context
will block the Tokio runtime and may cause timeouts or panics.

**Fix:** Wrap Argon2 operations in `tokio::task::spawn_blocking()`:

```rust
let hash = tokio::task::spawn_blocking(move || {
    hash_password(&password)
}).await??;
```

### "Audit middleware type error" or Trait Bound Issues

The audit middleware requires explicit type annotation because `HasJwtSecret` is
implemented for both `AppState` and `Arc<T>`.

**Fix:** Add the turbofish type annotation:

```rust
middleware::from_fn_with_state(
    state.clone(),
    audit_middleware::<Arc<AppState>>
)
```

### "FCM configuration error" at Startup

The notification service fails fast if Firebase credentials are missing.

**Fix:** Set `FCM_SERVER_KEY` and `FCM_PROJECT_ID` in `.env`. These are required
and the service will not start without them.

### Swagger UI Returns 404

Each service serves Swagger UI at `/docs` on its internal port.

**Fix:** Access directly via the service port during development:

- Auth: `http://localhost:3001/docs`
- Booking: `http://localhost:3002/docs`
- Tracking: `http://localhost:3003/docs`
- Notification: `http://localhost:3004/docs`
- Chat: `http://localhost:3006/docs`

Through Nginx, Swagger is available at `/auth/docs`, `/booking/docs`, etc.

### Container Health Check Failures

If services fail to start because dependencies are unhealthy:

```bash
# Check container status and health
docker compose ps

# View health check logs
docker inspect --format='{{json .State.Health}}' postgres-db | jq

# Check individual service logs
docker compose logs postgres-db
docker compose logs redis-cache
```

Common causes: incorrect passwords in `.env`, port conflicts, or insufficient
Docker memory allocation.

---

## Appendix: Service Port Reference

| Service             | Internal Port | Swagger UI           | Protocol       |
|---------------------|---------------|----------------------|----------------|
| nginx-gateway       | 80 / 443      | --                   | HTTP / HTTPS   |
| web-admin           | 3000          | --                   | HTTP           |
| rust-auth           | 3001          | /docs                | HTTP           |
| rust-booking        | 3002          | /docs                | HTTP           |
| rust-tracking       | 3003          | /docs                | HTTP + WS      |
| rust-notification   | 3004          | /docs                | HTTP           |
| mediasoup-server    | 3005          | --                   | HTTP + UDP     |
| rust-chat           | 3006          | /docs                | HTTP + WS      |
| postgres-db         | 5432          | --                   | PostgreSQL     |
| redis-cache         | 6379          | --                   | Redis          |
| redis-pubsub        | 6379          | --                   | Redis          |
| minio               | 9000 / 9001   | --                   | S3 / Console   |

---

## Appendix: Database Schema Overview

```
PostgreSQL: guard_dispatch_db
|
+-- schema: auth         -- users, sessions, roles
+-- schema: booking      -- requests, assignments, status tracking
+-- schema: tracking     -- GPS locations, location history
+-- schema: notification -- push notification logs, templates
+-- schema: chat         -- messages, conversations, attachment metadata
+-- schema: audit        -- action logs for all services
```

Each Rust service connects to the same PostgreSQL instance but operates within
its own schema. Cross-schema queries should be avoided; use service-to-service
communication instead.

---

## Appendix: Performance Targets

| Operation              | Target Latency  |
|------------------------|-----------------|
| Push notification      | < 1 second      |
| GPS update (critical)  | < 3 seconds     |
| API response           | < 200 ms        |
| Chat message delivery  | < 1 second      |

These targets apply under normal load conditions. Monitor actual latencies via
structured logging (`tracing` crate) and Nginx access logs.
