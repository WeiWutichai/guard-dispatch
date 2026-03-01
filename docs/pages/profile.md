# Profile / โปรไฟล์

## Route
`/profile`

## Purpose / วัตถุประสงค์
Admin user profile management page for viewing and editing personal information, changing passwords, reviewing account activity, and managing active sessions. Connected to the auth service API.

หน้าจัดการโปรไฟล์ผู้ดูแลระบบสำหรับดูและแก้ไขข้อมูลส่วนตัว เปลี่ยนรหัสผ่าน ตรวจสอบกิจกรรมบัญชี และจัดการเซสชันที่ใช้งานอยู่ เชื่อมต่อกับ API ของ auth service

## UI Components
- Profile form: name, email, phone number with edit capability
- Avatar display and upload area
- Password change section: current password, new password, confirm password
- Activity log section: recent account actions with timestamps
- Session management section: list of active sessions with device info and sign-out buttons
- Save and cancel buttons with form validation

## Data Source
- `authApi.getProfile()` -- API connected, fetches current user profile
- `authApi.updateProfile()` -- API connected, saves profile changes
- Session data from auth service

## User Actions
- Edit profile fields (name, email, phone)
- Upload or change profile avatar
- Change password (requires current password)
- View recent account activity log
- Sign out individual active sessions
- Sign out all other sessions

## i18n Keys
`t.profile.*`

## Related Backend Service
- **Auth Service** (port 3001) -- profile CRUD, password change, session management via `/auth/*` endpoints

## Status
API Connected

## Notes
- Profile data fetched on page load via `authApi.getProfile()`
- Profile updates sent via `authApi.updateProfile()` with validation
- Password change uses Argon2 hashing on the backend (runs in `spawn_blocking` to avoid blocking async runtime)
- Session limit: maximum 5 sessions per user; oldest sessions are evicted when exceeded
- Avatar upload must follow file upload rules: JPEG/PNG/WEBP only, 10MB max, magic bytes validation
- Auth uses httpOnly cookies for JWT storage (not localStorage)
