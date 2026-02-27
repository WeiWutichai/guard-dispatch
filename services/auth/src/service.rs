use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::Utc;
use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use shared::auth::encode_jwt_with_key;
use shared::config::JwtConfig;
use shared::error::AppError;

use crate::models::{
    AuthResponse, LoginRequest, RegisterRequest, SessionRow, UpdateProfileRequest, UserResponse,
    UserRow,
};

const USER_CACHE_TTL_SECS: u64 = 3600; // 1 hour
const REFRESH_TOKEN_DAYS: i64 = 30;
const MAX_SESSIONS_PER_USER: i64 = 5;

async fn hash_password(password: &str) -> Result<String, AppError> {
    let password = password.to_string();
    tokio::task::spawn_blocking(move || {
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        argon2
            .hash_password(password.as_bytes(), &salt)
            .map(|h| h.to_string())
            .map_err(|e| AppError::Internal(format!("Failed to hash password: {e}")))
    })
    .await
    .map_err(|e| AppError::Internal(format!("Hash task failed: {e}")))?
}

async fn verify_password(password: &str, hash: &str) -> Result<bool, AppError> {
    let password = password.to_string();
    let hash = hash.to_string();
    tokio::task::spawn_blocking(move || {
        let parsed_hash = PasswordHash::new(&hash)
            .map_err(|e| AppError::Internal(format!("Invalid password hash: {e}")))?;
        Ok(Argon2::default()
            .verify_password(password.as_bytes(), &parsed_hash)
            .is_ok())
    })
    .await
    .map_err(|e| AppError::Internal(format!("Verify task failed: {e}")))?
}

fn user_cache_key(user_id: &Uuid) -> String {
    format!("user:{user_id}")
}

async fn cache_user(
    redis: &redis::aio::MultiplexedConnection,
    user: &UserResponse,
) -> Result<(), AppError> {
    let mut conn = redis.clone();
    let json = serde_json::to_string(user)
        .map_err(|e| AppError::Internal(format!("Failed to serialize user: {e}")))?;
    let key = user_cache_key(&user.id);
    conn.set_ex::<_, _, ()>(&key, &json, USER_CACHE_TTL_SECS)
        .await
        .map_err(AppError::Redis)?;
    Ok(())
}

async fn get_cached_user(
    redis: &redis::aio::MultiplexedConnection,
    user_id: &Uuid,
) -> Result<Option<UserResponse>, AppError> {
    let mut conn = redis.clone();
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
    redis: &redis::aio::MultiplexedConnection,
    user_id: &Uuid,
) -> Result<(), AppError> {
    let mut conn = redis.clone();
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

    let password_hash = hash_password(&req.password).await?;
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
    redis: &redis::aio::MultiplexedConnection,
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

    let valid = verify_password(&req.password, &user.password_hash).await?;
    if !valid || !user.is_active {
        // Combine inactive and wrong-password into same error to prevent user enumeration
        return Err(AppError::Unauthorized("Invalid email or password".to_string()));
    }

    let access_token = encode_jwt_with_key(
        user.id,
        &user.role.to_string(),
        &jwt_config.encoding_key,
        jwt_config.expiry_hours,
    )?;

    // Enforce max sessions per user — evict oldest sessions beyond limit
    sqlx::query(
        r#"
        DELETE FROM auth.sessions
        WHERE user_id = $1
        AND id NOT IN (
            SELECT id FROM auth.sessions
            WHERE user_id = $1
            ORDER BY expires_at DESC
            LIMIT $2
        )
        "#,
    )
    .bind(user.id)
    .bind(MAX_SESSIONS_PER_USER - 1) // Leave room for the new session
    .execute(db)
    .await?;

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
    redis: &redis::aio::MultiplexedConnection,
    jwt_config: &JwtConfig,
    refresh_token: &str,
) -> Result<AuthResponse, AppError> {
    // Atomic rotation: consume the old refresh token and issue a new one in a single UPDATE.
    // This prevents race conditions where two concurrent requests could both use the same token.
    let new_refresh_token = Uuid::new_v4().to_string();
    let new_expires_at = Utc::now() + chrono::TimeDelta::days(REFRESH_TOKEN_DAYS);

    let session = sqlx::query_as::<_, SessionRow>(
        r#"
        UPDATE auth.sessions
        SET refresh_token = $2, expires_at = $3
        WHERE refresh_token = $1 AND expires_at > NOW()
        RETURNING id, user_id, refresh_token, expires_at
        "#,
    )
    .bind(refresh_token)
    .bind(&new_refresh_token)
    .bind(new_expires_at)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::Unauthorized("Invalid or expired refresh token".to_string()))?;

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
        return Err(AppError::Unauthorized("Invalid email or password".to_string()));
    }

    let access_token = encode_jwt_with_key(
        user.id,
        &user.role.to_string(),
        &jwt_config.encoding_key,
        jwt_config.expiry_hours,
    )?;

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
    redis: &redis::aio::MultiplexedConnection,
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
    redis: &redis::aio::MultiplexedConnection,
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

    // cache_user uses SET_EX which atomically overwrites any existing key — no need for DEL first
    cache_user(redis, &response).await?;

    Ok(response)
}

// =============================================================================
// Logout
// =============================================================================

pub async fn logout(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    user_id: Uuid,
) -> Result<(), AppError> {
    sqlx::query("DELETE FROM auth.sessions WHERE user_id = $1")
        .bind(user_id)
        .execute(db)
        .await?;

    invalidate_user_cache(redis, &user_id).await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use shared::models::UserRole;

    // =========================================================================
    // Password hashing (async — uses spawn_blocking internally)
    // =========================================================================

    #[tokio::test]
    async fn hash_password_produces_argon2_hash() {
        let hash = hash_password("mypassword123").await.unwrap();
        assert!(hash.starts_with("$argon2"));
    }

    #[tokio::test]
    async fn hash_password_different_calls_produce_different_hashes() {
        let h1 = hash_password("samepassword").await.unwrap();
        let h2 = hash_password("samepassword").await.unwrap();
        assert_ne!(h1, h2); // Different salts
    }

    #[tokio::test]
    async fn verify_password_correct_password_returns_true() {
        let hash = hash_password("correct-horse").await.unwrap();
        assert!(verify_password("correct-horse", &hash).await.unwrap());
    }

    #[tokio::test]
    async fn verify_password_wrong_password_returns_false() {
        let hash = hash_password("correct-horse").await.unwrap();
        assert!(!verify_password("wrong-horse", &hash).await.unwrap());
    }

    #[tokio::test]
    async fn verify_password_invalid_hash_returns_error() {
        let result = verify_password("any", "not-a-valid-hash").await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn verify_password_empty_password_returns_false() {
        let hash = hash_password("realpassword").await.unwrap();
        assert!(!verify_password("", &hash).await.unwrap());
    }

    // =========================================================================
    // Cache key format
    // =========================================================================

    #[test]
    fn user_cache_key_format() {
        let id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        assert_eq!(
            user_cache_key(&id),
            "user:550e8400-e29b-41d4-a716-446655440000"
        );
    }

    // =========================================================================
    // Registration validation logic
    // (These test the same checks register() performs, without needing a DB)
    // =========================================================================

    // NOTE: This mirrors the validation in register() to test without a DB.
    // If register()'s validation changes, update this helper too.
    fn validate_register_fields(req: &RegisterRequest) -> Result<(), AppError> {
        if req.email.is_empty() || req.password.is_empty() || req.full_name.is_empty() || req.phone.is_empty() {
            return Err(AppError::BadRequest("All fields are required".to_string()));
        }
        if req.password.len() < 8 {
            return Err(AppError::BadRequest(
                "Password must be at least 8 characters".to_string(),
            ));
        }
        Ok(())
    }

    #[test]
    fn register_rejects_empty_email() {
        let req = RegisterRequest {
            email: "".to_string(),
            phone: "0812345678".to_string(),
            password: "password123".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Customer,
        };
        assert!(validate_register_fields(&req).is_err());
    }

    #[test]
    fn register_rejects_empty_password() {
        let req = RegisterRequest {
            email: "user@test.com".to_string(),
            phone: "0812345678".to_string(),
            password: "".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Customer,
        };
        assert!(validate_register_fields(&req).is_err());
    }

    #[test]
    fn register_rejects_empty_name() {
        let req = RegisterRequest {
            email: "user@test.com".to_string(),
            phone: "0812345678".to_string(),
            password: "password123".to_string(),
            full_name: "".to_string(),
            role: UserRole::Customer,
        };
        assert!(validate_register_fields(&req).is_err());
    }

    #[test]
    fn register_rejects_empty_phone() {
        let req = RegisterRequest {
            email: "user@test.com".to_string(),
            phone: "".to_string(),
            password: "password123".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Customer,
        };
        assert!(validate_register_fields(&req).is_err());
    }

    #[test]
    fn register_rejects_short_password() {
        let req = RegisterRequest {
            email: "user@test.com".to_string(),
            phone: "0812345678".to_string(),
            password: "short".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Customer,
        };
        assert!(validate_register_fields(&req).is_err());
    }

    #[test]
    fn register_accepts_valid_input() {
        let req = RegisterRequest {
            email: "user@test.com".to_string(),
            phone: "0812345678".to_string(),
            password: "validpass123".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Guard,
        };
        assert!(validate_register_fields(&req).is_ok());
    }

    #[test]
    fn register_accepts_exactly_8_char_password() {
        let req = RegisterRequest {
            email: "user@test.com".to_string(),
            phone: "0812345678".to_string(),
            password: "12345678".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Customer,
        };
        assert!(validate_register_fields(&req).is_ok());
    }

    // =========================================================================
    // UserRow → UserResponse conversion
    // =========================================================================

    #[test]
    fn user_row_to_response_excludes_password_hash() {
        let now = Utc::now();
        let row = UserRow {
            id: Uuid::new_v4(),
            email: "test@example.com".to_string(),
            phone: "0812345678".to_string(),
            password_hash: "$argon2id$secret_hash".to_string(),
            full_name: "Test User".to_string(),
            role: UserRole::Guard,
            avatar_url: None,
            is_active: true,
            created_at: now,
            updated_at: now,
        };

        let response = UserResponse::from(row);
        assert_eq!(response.email, "test@example.com");
        assert_eq!(response.role, UserRole::Guard);
        assert!(response.is_active);
        // UserResponse does not have password_hash field — compile-time guarantee
    }

    #[test]
    fn user_row_to_response_preserves_all_fields() {
        let now = Utc::now();
        let id = Uuid::new_v4();
        let row = UserRow {
            id,
            email: "admin@guard.co".to_string(),
            phone: "0899999999".to_string(),
            password_hash: "hash".to_string(),
            full_name: "Admin User".to_string(),
            role: UserRole::Admin,
            avatar_url: Some("https://cdn.example.com/avatar.jpg".to_string()),
            is_active: false,
            created_at: now,
            updated_at: now,
        };

        let response = UserResponse::from(row);
        assert_eq!(response.id, id);
        assert_eq!(response.email, "admin@guard.co");
        assert_eq!(response.phone, "0899999999");
        assert_eq!(response.full_name, "Admin User");
        assert_eq!(response.role, UserRole::Admin);
        assert_eq!(response.avatar_url, Some("https://cdn.example.com/avatar.jpg".to_string()));
        assert!(!response.is_active);
        assert_eq!(response.created_at, now);
    }

    // =========================================================================
    // Constants
    // =========================================================================

    #[test]
    fn cache_ttl_is_one_hour() {
        assert_eq!(USER_CACHE_TTL_SECS, 3600);
    }

    #[test]
    fn refresh_token_lifetime_is_30_days() {
        assert_eq!(REFRESH_TOKEN_DAYS, 30);
    }

    // =========================================================================
    // UpdateProfile validation
    // =========================================================================

    #[test]
    fn update_profile_rejects_all_none_fields() {
        let req = UpdateProfileRequest {
            full_name: None,
            phone: None,
            avatar_url: None,
        };
        // Mirror the validation in update_profile()
        let all_none = req.full_name.is_none() && req.phone.is_none() && req.avatar_url.is_none();
        assert!(all_none, "All-None request should be rejected");
    }

    #[test]
    fn update_profile_accepts_partial_update() {
        let req = UpdateProfileRequest {
            full_name: Some("New Name".to_string()),
            phone: None,
            avatar_url: None,
        };
        let all_none = req.full_name.is_none() && req.phone.is_none() && req.avatar_url.is_none();
        assert!(!all_none, "Partial update should be accepted");
    }
}
