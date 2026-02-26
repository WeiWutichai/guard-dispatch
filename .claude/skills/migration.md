---
name: migration
description: Use this skill when creating, modifying, or running database migrations for the guard-dispatch project. Triggers include: "สร้าง migration", "เพิ่ม schema", "add table", "alter table", "create schema", or any request involving database schema changes.
---

# Database Migration Skill — Guard Dispatch

## กฎเด็ดขาด
- ใช้ `sqlx migrate` เท่านั้น — ห้ามแก้ไข migration file เก่า
- ทุก migration ต้องมีทั้ง `up` และ `down`
- ห้าม run migration บน production โดยตรง
- ทุกครั้งต้อง run `cargo sqlx prepare` หลังสร้าง migration ใหม่

## โครงสร้าง Schema ของโปรเจกต์
```
PostgreSQL: guard_dispatch_db
├── schema: auth         (users, sessions, roles)
├── schema: booking      (requests, assignments, status)
├── schema: tracking     (locations, history)
├── schema: notification (logs, templates)
├── schema: chat         (messages, attachments)
└── schema: audit        (logs ทุก action)
```

## ขั้นตอนสร้าง Migration

### 1. สร้างไฟล์ migration
```bash
cd database
sqlx migrate add <ชื่อ>
# ตัวอย่าง: sqlx migrate add create_auth_schema
```

### 2. รูปแบบชื่อไฟล์ที่ถูกต้อง
```
database/migrations/
├── 001_create_schemas.sql
├── 002_create_auth_tables.sql
├── 003_create_booking_tables.sql
├── 004_create_tracking_tables.sql
├── 005_create_notification_tables.sql
├── 006_create_chat_tables.sql
└── 007_create_audit_tables.sql
```

### 3. Template migration file
```sql
-- Migration: create_auth_tables
-- Created: <date>

-- UP
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE auth.users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT UNIQUE NOT NULL,
  password    TEXT NOT NULL,  -- bcrypt hash
  role        TEXT NOT NULL DEFAULT 'user',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_auth_users_email ON auth.users(email);

-- DOWN
DROP TABLE IF EXISTS auth.users;
DROP SCHEMA IF EXISTS auth;
```

### 4. Common column patterns
```sql
-- UUID Primary Key (ใช้ทุก table)
id UUID PRIMARY KEY DEFAULT gen_random_uuid()

-- Timestamps (ใช้ทุก table)
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()

-- Foreign Key ไปหา users
user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE

-- Status fields
status TEXT NOT NULL DEFAULT 'pending'
  CHECK (status IN ('pending', 'active', 'completed', 'cancelled'))
```

### 5. หลังสร้าง migration
```bash
# รัน migration (local)
sqlx migrate run --database-url $DATABASE_URL

# Prepare offline query data
cargo sqlx prepare --workspace

# ตรวจสอบ
sqlx migrate info --database-url $DATABASE_URL
```

## ข้อควรระวัง
- ห้ามใช้ `SERIAL` หรือ `BIGSERIAL` — ใช้ `UUID` เสมอ
- ทุก table ต้องมี `created_at` และ `updated_at`
- ทุก index ต้องตั้งชื่อ `idx_{schema}_{table}_{column}`
- Foreign keys ต้องระบุ `ON DELETE` behavior เสมอ
