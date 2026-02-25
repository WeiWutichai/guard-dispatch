-- =============================================================================
-- Migration 001: Auth Schema
-- Creates user_role enum, auth.users, auth.sessions
-- =============================================================================

CREATE TYPE user_role AS ENUM ('admin', 'customer', 'guard');

CREATE SCHEMA IF NOT EXISTS auth;

-- Users table
CREATE TABLE auth.users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT UNIQUE NOT NULL,
    phone         TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name     TEXT NOT NULL,
    role          user_role NOT NULL DEFAULT 'customer',
    avatar_url    TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON auth.users(email);
CREATE INDEX idx_users_phone ON auth.users(phone);
CREATE INDEX idx_users_role ON auth.users(role);

-- Sessions table (refresh tokens)
CREATE TABLE auth.sessions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    refresh_token TEXT UNIQUE NOT NULL,
    device_info   TEXT,
    ip_address    INET,
    expires_at    TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON auth.sessions(user_id);
CREATE INDEX idx_sessions_refresh_token ON auth.sessions(refresh_token);
CREATE INDEX idx_sessions_expires_at ON auth.sessions(expires_at);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
