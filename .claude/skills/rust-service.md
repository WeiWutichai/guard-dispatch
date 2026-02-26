---
name: rust-service
description: Use this skill when creating new Rust Axum endpoints, handlers, services, or modules in the guard-dispatch backend. Triggers include: "สร้าง endpoint", "เพิ่ม route", "สร้าง handler", "add API", "implement service", or any Rust backend development task.
---

# Rust Service Skill — Guard Dispatch

## Stack ที่ใช้
- **Framework:** Axum 0.8 — route syntax `/{id}` ไม่ใช่ `:id`
- **Async:** Tokio
- **DB:** SQLx 0.8 + compile-time macros เท่านั้น
- **Cache:** Redis
- **Auth:** JWT (jsonwebtoken)

## โครงสร้าง Service

```
services/{name}/src/
├── main.rs          ← server setup, router
├── routes.rs        ← route definitions
├── handlers/        ← request handlers
│   ├── mod.rs
│   └── {name}.rs
├── models/          ← data structs
│   ├── mod.rs
│   └── {name}.rs
├── db/              ← database queries
│   ├── mod.rs
│   └── {name}.rs
└── error.rs         ← AppError type
```

## Template: main.rs
```rust
use axum::{Router, routing::get};
use sqlx::PgPool;
use std::net::SocketAddr;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub redis: redis::Client,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::init();

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL required");
    let db = PgPool::connect(&database_url).await.expect("DB connect failed");

    let redis_url = std::env::var("REDIS_CACHE_URL").expect("REDIS_CACHE_URL required");
    let redis = redis::Client::open(redis_url).expect("Redis connect failed");

    let state = AppState { db, redis };

    let app = Router::new()
        .route("/health", get(health_check))
        .merge(routes::router(state));

    let addr = SocketAddr::from(([0, 0, 0, 0], 3001));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health_check() -> &'static str { "ok" }
```

## Template: error.rs
```rust
use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use serde_json::json;

#[derive(Debug)]
pub enum AppError {
    NotFound(String),
    Unauthorized,
    BadRequest(String),
    Internal(String),
    Database(sqlx::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::NotFound(msg)    => (StatusCode::NOT_FOUND, msg),
            AppError::Unauthorized     => (StatusCode::UNAUTHORIZED, "Unauthorized".into()),
            AppError::BadRequest(msg)  => (StatusCode::BAD_REQUEST, msg),
            AppError::Internal(msg)    => (StatusCode::INTERNAL_SERVER_ERROR, msg),
            AppError::Database(_)      => (StatusCode::INTERNAL_SERVER_ERROR, "Database error".into()),
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(e: sqlx::Error) -> Self { AppError::Database(e) }
}
```

## Template: Handler
```rust
use axum::{extract::{Path, State}, Json};
use uuid::Uuid;
use crate::{AppState, error::AppError};

// GET /{id}
pub async fn get_by_id(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<MyModel>, AppError> {
    let row = sqlx::query_as!(
        MyModel,
        "SELECT * FROM schema.table WHERE id = $1",
        id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("id {} not found", id)))?;

    Ok(Json(row))
}

// POST /
pub async fn create(
    State(state): State<AppState>,
    Json(payload): Json<CreateRequest>,
) -> Result<Json<MyModel>, AppError> {
    // validate
    if payload.field.is_empty() {
        return Err(AppError::BadRequest("field cannot be empty".into()));
    }

    let row = sqlx::query_as!(
        MyModel,
        "INSERT INTO schema.table (field) VALUES ($1) RETURNING *",
        payload.field
    )
    .fetch_one(&state.db)
    .await?;

    Ok(Json(row))
}
```

## JWT Validation Middleware
```rust
use axum::{extract::FromRequestParts, http::request::Parts};
use jsonwebtoken::{decode, DecodingKey, Validation};

#[derive(Debug, serde::Deserialize)]
pub struct Claims {
    pub sub: String,  // user_id
    pub role: String,
    pub exp: usize,
}

pub struct AuthUser(pub Claims);

#[axum::async_trait]
impl<S: Send + Sync> FromRequestParts<S> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, AppError> {
        let token = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or(AppError::Unauthorized)?;

        let secret = std::env::var("JWT_SECRET").expect("JWT_SECRET required");
        let claims = decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret.as_bytes()),
            &Validation::default(),
        )
        .map_err(|_| AppError::Unauthorized)?
        .claims;

        Ok(AuthUser(claims))
    }
}
```

## กฎที่ต้องทำตามเสมอ
- ห้ามใช้ `.unwrap()` — ใช้ `?` หรือ `.map_err()` เสมอ
- ทุก handler ต้อง return `Result<_, AppError>`
- ใช้ `query!` หรือ `query_as!` เท่านั้น ห้าม raw string query
- ทุก service ต้อง stateless — session เก็บใน Redis
- Route syntax: `/{id}` ไม่ใช่ `:id`
