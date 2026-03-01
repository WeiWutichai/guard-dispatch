# Login / เข้าสู่ระบบ

## Route
`/login`

## Purpose / วัตถุประสงค์
Admin authentication page providing email and password login with bilingual language switching. Establishes secure session using httpOnly cookies for JWT token storage.

หน้าเข้าสู่ระบบสำหรับผู้ดูแลด้วยอีเมลและรหัสผ่าน พร้อมสลับภาษาไทย-อังกฤษ สร้างเซสชันที่ปลอดภัยโดยใช้ httpOnly cookies สำหรับเก็บ JWT token

## UI Components
- Login form:
  - Email input field with validation
  - Password input field with show/hide toggle
  - Submit button
- Language switcher (Thai / English) in header or form area
- Error message display for invalid credentials
- Loading state on submit button during authentication

## Data Source
- `authApi.login()` -- API connected to auth service

## User Actions
- Enter email and password credentials
- Toggle password visibility
- Submit login form
- Switch display language between Thai and English

## i18n Keys
`t.login.*`

## Related Backend Service
- **Auth Service** (port 3001) -- authentication via `/auth/login` endpoint

## Status
API Connected

## Notes
- Login sets 3 cookies on successful authentication:
  - `access_token`: httpOnly, Secure, SameSite=Lax, Path=/
  - `refresh_token`: httpOnly, Secure, SameSite=Lax, Path=/auth
  - `logged_in`: non-httpOnly, Secure, SameSite=Lax, value "1" (marker for frontend auth state check)
- JWT tokens are never stored in localStorage or sessionStorage (project security rule)
- Login error messages do not reveal whether an email exists in the system (prevents user enumeration)
- Rate limited at Nginx layer: 5 requests per second for auth endpoints
- Password verification uses Argon2 hashing in `spawn_blocking` on the backend
- Failed login attempts are recorded in the audit schema
- The `/auth/login` and `/auth/register` endpoints are exempt from JWT validation middleware
