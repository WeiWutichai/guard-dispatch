use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::Utc;
use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use shared::auth::encode_jwt;
use shared::config::JwtConfig;
use shared::error::AppError;

use crate::models::{
    AuthResponse, LoginRequest, RegisterRequest, SessionRow, UpdateProfileRequest, UserResponse,
    UserRow,
};

const USER_CACHE_TTL_SECS: u64 = 3600; // 1 hour
const REFRESH_TOKEN_DAYS: i64 = 30;

fn hash_password(password: &str) -> Result<String, AppError> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    argon2
        .hash_password(password.as_bytes(), &salt)
        .map(|h| h.to_string())
        .map_err(|e| AppError::Internal(format!("Failed to hash password: {e}")))
}

fn verify_password(password: &str, hash: &str) -> Result<bool, AppError> {
    let parsed_hash = PasswordHash::new(hash)
        .map_err(|e| AppError::Internal(format!("Invalid password hash: {e}")))?;
    Ok(Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok())
}

fn user_cache_key(user_id: &Uuid) -> String {
    format!("user:{user_id}")
}

async fn cache_user(
    redis: &redis::Client,
    user: &UserResponse,
) -> Result<(), AppError> {
    let mut conn = redis
        .get_multiplexed_async_connection()
        .await
        .map_err(AppError::Redis)?;
    let json = serde_json::to_string(user)
        .map_err(|e| AppError::Internal(format!("Failed to serialize user: {e}")))?;
    let key = user_cache_key(&user.id);
    conn.set_ex::<_, _, ()>(&key, &json, USER_CACHE_TTL_SECS)
        .await
        .map_err(AppError::Redis)?;
    Ok(())
}

async fn get_cached_user(
    redis: &redis::Client,
    user_id: &Uuid,
) -> Result<Option<UserResponse>, AppError> {
    let mut conn = redis
        .get_multiplexed_async_connection()
        .await
        .map_err(AppError::Redis)?;
    let key = user_cache_key(user_id);
    let cached: Option<String> = conn.get(&key).await.map_err(AppError::Redis)?;
    match cached {
        Some(json) => {
            let user: UserResponse = serde_json::from_str(&json)
                .map_err(|e| AppError::Internal(format!("Failed to deserialize cached user: {e}")))?;
            Ok(Some(user))
        }
        None => Ok(None),
    }
}

async fn invalidate_user_cache(
    redis: &redis::Client,
    user_id: &Uuid,
) -> Result<(), AppError> {
    let mut conn = redis
        .get_multiplexed_async_connection()
        .await
        .map_err(AppError::Redis)?;
    let key = user_cache_key(user_id);
    conn.del::<_, ()>(&key).await.map_err(AppError::Redis)?;
    Ok(())
}

// =============================================================================
// Register
// =============================================================================

pub async fn register(
    db: &PgPool,
    req: RegisterRequest,
) -> Result<UserResponse, AppError> {
    if req.email.is_empty() || req.password.is_empty() || req.full_name.is_empty() || req.phone.is_empty() {
        return Err(AppError::BadRequest("All fields are required".to_string()));
    }

    if req.password.len() < 8 {
        return Err(AppError::BadRequest(
            "Password must be at least 8 characters".to_string(),
        ));
    }

    let password_hash = hash_password(&req.password)?;
    let role_str = req.role.to_string();

    let row = sqlx::query_as::<_, UserRow>(
        r#"
        INSERT INTO auth.users (email, phone, password_hash, full_name, role)
        VALUES ($1, $2, $3, $4, $5::user_role)
        RETURNING id, email, phone, password_hash, full_name, role, avatar_url, is_active, created_at, updated_at
        "#,
    )
    .bind(&req.email)
    .bind(&req.phone)
    .bind(&password_hash)
    .bind(&req.full_name)
    .bind(&role_str)
    .fetch_one(db)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(ref db_err) if db_err.constraint().is_some() => {
            AppError::Conflict("Email or phone already exists".to_string())
        }
        other => AppError::Database(other),
    })?;

    Ok(UserResponse::from(row))
}

// =============================================================================
// Login
// =============================================================================

pub async fn login(
    db: &PgPool,
    redis: &redis::Client,
    jwt_config: &JwtConfig,
    req: LoginRequest,
    ip_address: Option<String>,
    device_info: Option<String>,
) -> Result<AuthResponse, AppError> {
    let user = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, created_at, updated_at
        FROM auth.users
        WHERE email = $1
        "#,
    )
    .bind(&req.email)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::Unauthorized("Invalid email or password".to_string()))?;

    if !user.is_active {
        return Err(AppError::Forbidden("Account is deactivated".to_string()));
    }

    let valid = verify_password(&req.password, &user.password_hash)?;
    if !valid {
        return Err(AppError::Unauthorized("Invalid email or password".to_string()));
    }

    let access_token = encode_jwt(
        user.id,
        &user.role.to_string(),
        &jwt_config.secret,
        jwt_config.expiry_hours,
    )?;

    let refresh_token = Uuid::new_v4().to_string();
    let expires_at = Utc::now() + chrono::TimeDelta::days(REFRESH_TOKEN_DAYS);

    sqlx::query(
        r#"
        INSERT INTO auth.sessions (user_id, refresh_token, device_info, ip_address, expires_at)
        VALUES ($1, $2, $3, $4::inet, $5)
        "#,
    )
    .bind(user.id)
    .bind(&refresh_token)
    .bind(&device_info)
    .bind(&ip_address)
    .bind(expires_at)
    .execute(db)
    .await?;

    let user_response = UserResponse::from(user);
    cache_user(redis, &user_response).await?;

    Ok(AuthResponse {
        access_token,
        refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: jwt_config.expiry_hours * 3600,
    })
}

// =============================================================================
// Refresh Token
// =============================================================================

pub async fn refresh_token(
    db: &PgPool,
    redis: &redis::Client,
    jwt_config: &JwtConfig,
    refresh_token: &str,
) -> Result<AuthResponse, AppError> {
    let session = sqlx::query_as::<_, SessionRow>(
        r#"
        SELECT id, user_id, refresh_token, expires_at
        FROM auth.sessions
        WHERE refresh_token = $1
        "#,
    )
    .bind(refresh_token)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::Unauthorized("Invalid refresh token".to_string()))?;

    if session.expires_at < Utc::now() {
        sqlx::query("DELETE FROM auth.sessions WHERE id = $1")
            .bind(session.id)
            .execute(db)
            .await?;
        return Err(AppError::Unauthorized("Refresh token expired".to_string()));
    }

    let user = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, created_at, updated_at
        FROM auth.users
        WHERE id = $1
        "#,
    )
    .bind(session.user_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    if !user.is_active {
        return Err(AppError::Forbidden("Account is deactivated".to_string()));
    }

    let access_token = encode_jwt(
        user.id,
        &user.role.to_string(),
        &jwt_config.secret,
        jwt_config.expiry_hours,
    )?;

    let new_refresh_token = Uuid::new_v4().to_string();
    let new_expires_at = Utc::now() + chrono::TimeDelta::days(REFRESH_TOKEN_DAYS);

    sqlx::query(
        r#"
        UPDATE auth.sessions
        SET refresh_token = $1, expires_at = $2
        WHERE id = $3
        "#,
    )
    .bind(&new_refresh_token)
    .bind(new_expires_at)
    .bind(session.id)
    .execute(db)
    .await?;

    let user_response = UserResponse::from(user);
    cache_user(redis, &user_response).await?;

    Ok(AuthResponse {
        access_token,
        refresh_token: new_refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: jwt_config.expiry_hours * 3600,
    })
}

// =============================================================================
// Get Profile
// =============================================================================

pub async fn get_profile(
    db: &PgPool,
    redis: &redis::Client,
    user_id: Uuid,
) -> Result<UserResponse, AppError> {
    if let Some(cached) = get_cached_user(redis, &user_id).await? {
        return Ok(cached);
    }

    let user = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, created_at, updated_at
        FROM auth.users
        WHERE id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    let response = UserResponse::from(user);
    cache_user(redis, &response).await?;

    Ok(response)
}

// =============================================================================
// Update Profile
// =============================================================================

pub async fn update_profile(
    db: &PgPool,
    redis: &redis::Client,
    user_id: Uuid,
    req: UpdateProfileRequest,
) -> Result<UserResponse, AppError> {
    if req.full_name.is_none() && req.phone.is_none() && req.avatar_url.is_none() {
        return Err(AppError::BadRequest(
            "At least one field must be provided".to_string(),
        ));
    }

    let user = sqlx::query_as::<_, UserRow>(
        r#"
        UPDATE auth.users
        SET full_name  = COALESCE($2, full_name),
            phone      = COALESCE($3, phone),
            avatar_url = COALESCE($4, avatar_url)
        WHERE id = $1
        RETURNING id, email, phone, password_hash, full_name, role, avatar_url, is_active, created_at, updated_at
        "#,
    )
    .bind(user_id)
    .bind(&req.full_name)
    .bind(&req.phone)
    .bind(&req.avatar_url)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    let response = UserResponse::from(user);

    invalidate_user_cache(redis, &user_id).await?;
    cache_user(redis, &response).await?;

    Ok(response)
}

// =============================================================================
// Logout
// =============================================================================

pub async fn logout(
    db: &PgPool,
    redis: &redis::Client,
    user_id: Uuid,
) -> Result<(), AppError> {
    sqlx::query("DELETE FROM auth.sessions WHERE user_id = $1")
        .bind(user_id)
        .execute(db)
        .await?;

    invalidate_user_cache(redis, &user_id).await?;

    Ok(())
}
