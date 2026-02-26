---
name: pr-review
description: Use this skill when reviewing code, checking before merge, or doing a PR review. Triggers include: "review code", "ตรวจโค้ด", "check before merge", "PR review", "code review", "ดู PR", or any request to evaluate code quality.
---

# PR Review Skill — Guard Dispatch

## Checklist ก่อน Merge ทุกครั้ง

### 🦀 Rust
- [ ] ไม่มี `.unwrap()` ในโค้ดใหม่ — ใช้ `?` หรือ proper error handling
- [ ] ทุก handler return `Result<_, AppError>`
- [ ] ใช้ `query!` หรือ `query_as!` เท่านั้น ไม่มี raw string query
- [ ] Route syntax ใช้ `/{id}` ไม่ใช่ `:id`
- [ ] Axum version เป็น 0.8
- [ ] ไม่มี hardcoded credentials หรือ secrets
- [ ] `cargo clippy` ผ่าน — ไม่มี warnings ใหม่
- [ ] `cargo fmt` ผ่าน — format ถูกต้อง

### 🗄️ Database
- [ ] ไม่มีการแก้ไข migration file เก่า — มีแต่ file ใหม่
- [ ] ทุก migration มีทั้ง UP และ DOWN
- [ ] ทุก table ใหม่มี `id UUID`, `created_at`, `updated_at`
- [ ] Index ตั้งชื่อถูกต้อง: `idx_{schema}_{table}_{column}`
- [ ] `cargo sqlx prepare` รันแล้วหลังเพิ่ม query ใหม่

### 🔐 Security
- [ ] JWT validation ครอบทุก endpoint ยกเว้น `/auth/login` และ `/auth/register`
- [ ] ไม่มี binary/image เก็บใน PostgreSQL
- [ ] File upload validate mime_type แล้ว
- [ ] ใช้ Signed URL ไม่ expose bucket โดยตรง

### 🌐 Frontend (Next.js)
- [ ] ใช้ `lib/api.ts` ทุก API call — ไม่มี fetch ตรง
- [ ] ไม่มี hardcoded URL หรือ port
- [ ] Auth check ครอบทุกหน้าใน dashboard
- [ ] `npm run lint` ผ่าน — 0 errors

### 📦 General
- [ ] ไม่มีไฟล์ `.env` จริงใน commit (แค่ `.env.example`)
- [ ] `docker compose config` valid
- [ ] ไม่มี `console.log` หรือ `dbg!()` หลุดเข้ามา
- [ ] CLAUDE.md อัปเดตถ้า architecture เปลี่ยน

## วิธีรัน Review
```bash
# Rust
cargo clippy --workspace -- -D warnings
cargo fmt --check

# Frontend
cd frontend/web
npm run lint
npm run build

# Docker
docker compose config
```
