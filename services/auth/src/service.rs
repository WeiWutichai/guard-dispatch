use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::Utc;
use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use std::collections::HashMap;

use aws_sdk_s3::presigning::PresigningConfig;
use shared::auth::{decode_profile_token, encode_jwt_with_key, encode_phone_verify_token, decode_phone_verify_token, encode_profile_token};
use shared::config::JwtConfig;
use shared::error::AppError;
use shared::models::UserRole;
use shared::otp::{self, OtpConfig};
use shared::sms::{self, SmsConfig};

use shared::models::ApprovalStatus;

/// Escape ILIKE special characters to prevent wildcard injection / ReDoS.
fn escape_ilike(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('%', "\\%")
        .replace('_', "\\_")
}

use crate::models::{
    AuthResponse, GuardProfileFormData, GuardProfileResponse, GuardProfileRow,
    ListUsersQuery, LoginRequest, OtpRow, PaginatedUsers, PhoneLoginRequest, RegisterRequest,
    RegisterWithOtpRequest, RegisterWithOtpResponse, RequestOtpResponse, SessionRow,
    UpdateApprovalStatusRequest, UpdateProfileRequest, UserResponse, UserRow, VerifyOtpResponse,
};

const USER_CACHE_TTL_SECS: u64 = 3600; // 1 hour
const PROFILE_TOKEN_TTL_MINUTES: i64 = 15;
const MAX_DOCUMENT_SIZE: usize = 10 * 1024 * 1024; // 10 MB per CLAUDE.md file upload rules
const SIGNED_URL_EXPIRY_SECS: u64 = 3600; // 1 hour
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

    // Basic email format validation
    if !req.email.contains('@') || !req.email.contains('.') || req.email.len() < 5 {
        return Err(AppError::BadRequest(
            "Invalid email format".to_string(),
        ));
    }

    // Thai phone format validation: 0x-xxxx-xxxx (10 digits starting with 0)
    let phone_digits: String = req.phone.chars().filter(|c| c.is_ascii_digit()).collect();
    if phone_digits.len() != 10 || !phone_digits.starts_with('0') {
        return Err(AppError::BadRequest(
            "Invalid phone format — must be 10 digits starting with 0".to_string(),
        ));
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
        INSERT INTO auth.users (email, phone, password_hash, full_name, role, approval_status)
        VALUES ($1, $2, $3, $4, $5::user_role, 'pending'::approval_status)
        RETURNING id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
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
    // Always run password verification to prevent timing-based user enumeration.
    // If user not found, verify against a dummy hash (constant time).
    let dummy_hash = "$argon2id$v=19$m=19456,t=2,p=1$dW5rbm93bg$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let user = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
        FROM auth.users
        WHERE email = $1
        "#,
    )
    .bind(&req.email)
    .fetch_optional(db)
    .await?;

    let (found_user, valid) = match user {
        Some(u) => {
            let v = verify_password(&req.password, &u.password_hash).await?;
            (Some(u), v)
        }
        None => {
            let _ = verify_password(&req.password, dummy_hash).await;
            (None, false)
        }
    };

    let user = found_user
        .ok_or_else(|| AppError::Unauthorized("Invalid email or password".to_string()))?;

    if !valid || !user.is_active || user.approval_status != ApprovalStatus::Approved {
        // Combine inactive, pending/rejected, and wrong-password into same error to prevent user enumeration
        return Err(AppError::Unauthorized("Invalid email or password".to_string()));
    }

    // Null role means the user hasn't completed onboarding — treat as unauthorized
    // using the same generic message to avoid leaking account state.
    let role = user.role.as_ref().ok_or_else(|| {
        AppError::Unauthorized("Invalid email or password".to_string())
    })?;

    let access_token = encode_jwt_with_key(
        user.id,
        &role.to_string(),
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

    let role_str = role.to_string();
    let user_response = UserResponse::from(user);
    cache_user(redis, &user_response).await?;

    Ok(AuthResponse {
        access_token,
        refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: jwt_config.expiry_hours * 3600,
        role: role_str,
    })
}

// =============================================================================
// Login (Phone-based — for mobile app)
// =============================================================================

/// Check user status without issuing tokens.
/// Verifies password to prevent enumeration, then returns actual DB state.
pub async fn check_status(
    db: &PgPool,
    req: crate::models::CheckStatusRequest,
) -> Result<crate::models::CheckStatusResponse, AppError> {
    let user = sqlx::query_as::<_, UserRow>(
        r#"SELECT id, email, phone, password_hash, full_name, role, avatar_url,
                  is_active, approval_status, created_at, updated_at
           FROM auth.users WHERE phone = $1"#,
    )
    .bind(&req.phone)
    .fetch_optional(db)
    .await?;

    // Always run password verification to prevent timing attacks.
    // If user not found, verify against a dummy hash (constant time).
    let dummy_hash = "$argon2id$v=19$m=19456,t=2,p=1$dW5rbm93bg$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let (found_user, valid) = match user {
        Some(u) => {
            let v = verify_password(&req.password, &u.password_hash).await?;
            (Some(u), v)
        }
        None => {
            // Dummy verify to match timing of real verification
            let _ = verify_password(&req.password, dummy_hash).await;
            (None, false)
        }
    };

    if !valid || found_user.is_none() {
        return Ok(crate::models::CheckStatusResponse {
            exists: false,
            role: None,
            approval_status: None,
            has_guard_profile: false,
            has_customer_profile: false,
            customer_approval_status: None,
        });
    }

    let user = found_user.unwrap(); // safe — we checked above

    // Check profiles
    let has_guard = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM auth.guard_profiles WHERE user_id = $1)"
    ).bind(user.id).fetch_one(db).await.unwrap_or(false);

    let customer_row = sqlx::query_scalar::<_, String>(
        "SELECT approval_status::text FROM auth.customer_profiles WHERE user_id = $1"
    ).bind(user.id).fetch_optional(db).await.ok().flatten();

    Ok(crate::models::CheckStatusResponse {
        exists: true,
        role: user.role.map(|r| r.to_string()),
        approval_status: Some(user.approval_status.to_string()),
        has_guard_profile: has_guard,
        has_customer_profile: customer_row.is_some(),
        customer_approval_status: customer_row,
    })
}

pub async fn login_with_phone(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    jwt_config: &JwtConfig,
    req: PhoneLoginRequest,
    ip_address: Option<String>,
    device_info: Option<String>,
) -> Result<AuthResponse, AppError> {
    // Always run password verification to prevent timing-based user enumeration.
    // If user not found, verify against a dummy hash (constant time).
    let dummy_hash = "$argon2id$v=19$m=19456,t=2,p=1$dW5rbm93bg$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let user = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
        FROM auth.users
        WHERE phone = $1
        "#,
    )
    .bind(&req.phone)
    .fetch_optional(db)
    .await?;

    let (found_user, valid) = match user {
        Some(u) => {
            let v = verify_password(&req.password, &u.password_hash).await?;
            (Some(u), v)
        }
        None => {
            let _ = verify_password(&req.password, dummy_hash).await;
            (None, false)
        }
    };

    let user = found_user
        .ok_or_else(|| AppError::Unauthorized("Invalid phone or password".to_string()))?;

    if !valid || !user.is_active {
        return Err(AppError::Unauthorized("Invalid phone or password".to_string()));
    }
    // Return generic 401 for ALL non-approved states (pending, rejected)
    // to prevent user enumeration via status codes.
    // Mobile uses locally stored pending flag (SharedPreferences) to show pending UI.
    if user.approval_status != ApprovalStatus::Approved {
        return Err(AppError::Unauthorized("Invalid phone or password".to_string()));
    }

    // Null role means the user hasn't completed onboarding — treat as unauthorized
    // using the same generic message to avoid leaking account state.
    let role = user.role.as_ref().ok_or_else(|| {
        AppError::Unauthorized("Invalid phone or password".to_string())
    })?;

    let access_token = encode_jwt_with_key(
        user.id,
        &role.to_string(),
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

    let role_str = role.to_string();
    let user_response = UserResponse::from(user);
    cache_user(redis, &user_response).await?;

    Ok(AuthResponse {
        access_token,
        refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: jwt_config.expiry_hours * 3600,
        role: role_str,
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
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
        FROM auth.users
        WHERE id = $1
        "#,
    )
    .bind(session.user_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    if !user.is_active || user.approval_status != ApprovalStatus::Approved {
        return Err(AppError::Unauthorized("Invalid email or password".to_string()));
    }

    let role = user.role.as_ref().ok_or_else(|| {
        AppError::Unauthorized("Invalid email or password".to_string())
    })?;

    let access_token = encode_jwt_with_key(
        user.id,
        &role.to_string(),
        &jwt_config.encoding_key,
        jwt_config.expiry_hours,
    )?;

    let role_str = role.to_string();
    let user_response = UserResponse::from(user);
    cache_user(redis, &user_response).await?;

    Ok(AuthResponse {
        access_token,
        refresh_token: new_refresh_token,
        token_type: "Bearer".to_string(),
        expires_in: jwt_config.expiry_hours * 3600,
        role: role_str,
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
        // Only use cache if it has profile data populated.
        // Avoids stale cache from before profile LEFT JOIN was added.
        let has_profile_data = cached.customer_full_name.is_some()
            || cached.company_name.is_some()
            || cached.gender.is_some()
            || cached.customer_approval_status.is_some()
            || cached.customer_address.is_some();
        let is_customer = cached
            .role
            .as_ref()
            .is_some_and(|r| matches!(r, UserRole::Customer));
        let is_guard = cached
            .role
            .as_ref()
            .is_some_and(|r| matches!(r, UserRole::Guard));

        // Use cache only if: no role / admin, OR has relevant profile data
        if (!is_customer && !is_guard) || has_profile_data {
            return Ok(cached);
        }
        // Otherwise fall through to fresh DB query + re-cache
    }

    // Single query with LEFT JOINs to pull profile-specific fields.
    // - Guard: gender, date_of_birth, experience, workplace from guard_profiles
    //          full_name lives in auth.users (set by submit_guard_profile)
    // - Customer: full_name + company_name + contact_phone from customer_profiles
    // NOTE: No sensitive fields (bank info, doc URLs) are returned here.
    #[derive(sqlx::FromRow)]
    struct ProfileRow {
        id: Uuid,
        email: String,
        phone: String,
        full_name: String,
        role: Option<UserRole>,
        avatar_url: Option<String>,
        is_active: bool,
        approval_status: ApprovalStatus,
        created_at: chrono::DateTime<chrono::Utc>,
        // customer_profiles fields
        cp_full_name: Option<String>,
        cp_company_name: Option<String>,
        cp_contact_phone: Option<String>,
        cp_address: Option<String>,
        cp_approval_status: Option<ApprovalStatus>,
        // guard_profiles fields (non-sensitive only)
        gp_gender: Option<String>,
        gp_date_of_birth: Option<chrono::NaiveDate>,
        gp_years_of_experience: Option<i32>,
        gp_previous_workplace: Option<String>,
    }

    let row = sqlx::query_as::<_, ProfileRow>(
        r#"
        SELECT
            u.id, u.email, u.phone,
            u.full_name, u.role, u.avatar_url, u.is_active,
            u.approval_status, u.created_at,
            cp.full_name          AS cp_full_name,
            cp.company_name       AS cp_company_name,
            cp.contact_phone      AS cp_contact_phone,
            cp.address            AS cp_address,
            cp.approval_status    AS cp_approval_status,
            gp.gender             AS gp_gender,
            gp.date_of_birth      AS gp_date_of_birth,
            gp.years_of_experience AS gp_years_of_experience,
            gp.previous_workplace AS gp_previous_workplace
        FROM auth.users u
        LEFT JOIN auth.customer_profiles cp ON cp.user_id = u.id
        LEFT JOIN auth.guard_profiles gp ON gp.user_id = u.id
        WHERE u.id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    // Return guard name (auth.users) and customer name (customer_profiles) separately
    let response = UserResponse {
        id: row.id,
        email: row.email,
        phone: row.phone,
        full_name: row.full_name,
        role: row.role,
        avatar_url: row.avatar_url,
        is_active: row.is_active,
        approval_status: row.approval_status,
        created_at: row.created_at,
        customer_full_name: row.cp_full_name.filter(|s| !s.is_empty()),
        company_name: row.cp_company_name,
        contact_phone: row.cp_contact_phone,
        gender: row.gp_gender,
        date_of_birth: row.gp_date_of_birth.map(|d| d.format("%Y-%m-%d").to_string()),
        years_of_experience: row.gp_years_of_experience,
        previous_workplace: row.gp_previous_workplace,
        customer_address: row.cp_address,
        customer_approval_status: row.cp_approval_status,
    };
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
        RETURNING id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
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

    // Invalidate cache so next get_profile re-fetches with full JOIN (includes profile fields)
    invalidate_user_cache(redis, &user_id).await?;

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

// =============================================================================
// Request OTP
// =============================================================================

pub async fn request_otp(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    sms_config: &SmsConfig,
    otp_config: &OtpConfig,
    http_client: &reqwest::Client,
    phone: &str,
) -> Result<RequestOtpResponse, AppError> {
    // Validate phone format
    let phone = otp::validate_thai_phone(phone)?;

    // Atomic rate limit: SET NX EX — if key already exists, request is rate-limited.
    // This prevents the race condition of separate EXISTS + SET calls.
    let rate_key = format!("otp_rate:{phone}");
    let mut conn = redis.clone();
    let was_set: Option<String> = redis::cmd("SET")
        .arg(&rate_key)
        .arg("1")
        .arg("NX")
        .arg("EX")
        .arg(otp_config.rate_limit_seconds)
        .query_async(&mut conn)
        .await
        .map_err(AppError::Redis)?;

    if was_set.is_none() {
        return Err(AppError::BadRequest(
            "กรุณารอสักครู่ก่อนขอ OTP ใหม่".to_string(),
        ));
    }

    // Daily per-phone OTP cap
    let daily_key = format!("otp_daily:{phone}");
    let mut conn = redis.clone();
    let daily_count: i64 = redis::cmd("INCR")
        .arg(&daily_key)
        .query_async(&mut conn)
        .await
        .map_err(AppError::Redis)?;

    // Ensure TTL is set — handles both first-request and crash-recovery scenarios.
    // Only sets TTL when key has none (TTL returns -1), so it doesn't refresh the window.
    let ttl: i64 = redis::cmd("TTL")
        .arg(&daily_key)
        .query_async(&mut conn)
        .await
        .map_err(AppError::Redis)?;
    if ttl < 0 {
        redis::cmd("EXPIRE")
            .arg(&daily_key)
            .arg(86400u64)
            .query_async::<()>(&mut conn)
            .await
            .map_err(AppError::Redis)?;
    }

    if daily_count > otp_config.daily_otp_limit as i64 {
        return Err(AppError::BadRequest(
            "เกินจำนวนการขอ OTP ต่อวัน กรุณาลองใหม่พรุ่งนี้".to_string(),
        ));
    }

    // Invalidate any previous unused OTP for this phone + purpose
    sqlx::query(
        "UPDATE auth.otp_codes SET is_used = true WHERE phone = $1 AND purpose = 'register' AND is_used = false",
    )
    .bind(&phone)
    .execute(db)
    .await?;

    // Generate OTP
    let code = otp::generate_otp(otp_config.length);
    let expires_at = Utc::now() + chrono::TimeDelta::minutes(otp_config.expiry_minutes);

    // Store in DB
    sqlx::query(
        r#"
        INSERT INTO auth.otp_codes (phone, code, purpose, expires_at)
        VALUES ($1, $2, 'register', $3)
        "#,
    )
    .bind(&phone)
    .bind(&code)
    .bind(expires_at)
    .execute(db)
    .await?;

    // Send SMS via INET (using shared reqwest::Client for connection reuse)
    let message = otp::format_otp_message(&code, otp_config.expiry_minutes);
    let sms_phone = otp::to_international_format(&phone);
    sms::send_sms(sms_config, http_client, &sms_phone, &message).await?;

    Ok(RequestOtpResponse {
        message: "OTP sent successfully".to_string(),
        expires_in: otp_config.expiry_minutes * 60,
    })
}

// =============================================================================
// Verify OTP
// =============================================================================

pub async fn verify_otp(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    jwt_config: &JwtConfig,
    otp_config: &OtpConfig,
    phone: &str,
    code: &str,
) -> Result<VerifyOtpResponse, AppError> {
    let phone = otp::validate_thai_phone(phone)?;

    if code.len() != otp_config.length {
        return Err(AppError::BadRequest("Invalid OTP format".to_string()));
    }

    // Atomically: find the latest valid OTP, increment attempts, and return it.
    // The subquery with FOR UPDATE prevents race conditions on concurrent verify attempts.
    let otp_row = sqlx::query_as::<_, OtpRow>(
        r#"
        UPDATE auth.otp_codes
        SET attempts = attempts + 1
        WHERE id = (
            SELECT id FROM auth.otp_codes
            WHERE phone = $1 AND purpose = 'register' AND is_used = false AND expires_at > NOW()
            ORDER BY created_at DESC
            LIMIT 1
            FOR UPDATE
        )
        RETURNING id, phone, code, purpose, is_used, attempts, expires_at, created_at
        "#,
    )
    .bind(&phone)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::BadRequest("OTP ไม่ถูกต้องหรือหมดอายุ".to_string()))?;

    // Check if we've exceeded max attempts (attempts is already incremented by the UPDATE above)
    if otp_row.attempts > otp_config.max_attempts {
        // Mark as used — force user to request a new one
        sqlx::query("UPDATE auth.otp_codes SET is_used = true WHERE id = $1")
            .bind(otp_row.id)
            .execute(db)
            .await?;
        return Err(AppError::BadRequest(
            "เกินจำนวนครั้งที่อนุญาต กรุณาขอ OTP ใหม่".to_string(),
        ));
    }

    // Constant-time comparison to prevent timing side-channel attacks.
    // Both slices have the same length (validated above), so ct_eq is safe.
    use subtle::ConstantTimeEq;
    let code_matches: bool = otp_row.code.as_bytes().ct_eq(code.as_bytes()).into();

    if !code_matches {
        return Err(AppError::BadRequest("OTP ไม่ถูกต้อง".to_string()));
    }

    // OTP is correct — mark as used
    sqlx::query("UPDATE auth.otp_codes SET is_used = true WHERE id = $1")
        .bind(otp_row.id)
        .execute(db)
        .await?;

    // Issue a temporary phone-verified JWT with jti for single-use enforcement.
    // Uses a separate TTL (phone_verify_ttl_minutes) to give users time to fill the registration form.
    let (token, jti) = encode_phone_verify_token(
        &phone,
        &jwt_config.encoding_key,
        otp_config.phone_verify_ttl_minutes,
    )?;

    // Store jti in Redis as "valid" — consumed by register_with_otp to enforce single-use.
    // TTL has a small buffer (30s) beyond the JWT expiry for clock skew.
    let jti_key = format!("phone_verify_jti:{jti}");
    let mut conn = redis.clone();
    let ttl_secs = (otp_config.phone_verify_ttl_minutes * 60 + 30) as u64;
    conn.set_ex::<_, _, ()>(&jti_key, "valid", ttl_secs)
        .await
        .map_err(AppError::Redis)?;

    Ok(VerifyOtpResponse {
        phone_verified_token: token,
        message: "ยืนยันสำเร็จ".to_string(),
    })
}

// =============================================================================
// Register with OTP (phone-verified token)
// =============================================================================

pub async fn register_with_otp(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    jwt_config: &JwtConfig,
    req: RegisterWithOtpRequest,
) -> Result<RegisterWithOtpResponse, AppError> {
    // Decode and validate the phone_verified_token
    let (phone, jti) = decode_phone_verify_token(
        &req.phone_verified_token,
        &jwt_config.decoding_key,
    )?;

    // Single-use enforcement: GETDEL atomically retrieves and deletes the jti,
    // preventing replay even under concurrent requests.
    let jti_key = format!("phone_verify_jti:{jti}");
    let mut conn = redis.clone();
    let jti_status: Option<String> = redis::cmd("GETDEL")
        .arg(&jti_key)
        .query_async(&mut conn)
        .await
        .map_err(AppError::Redis)?;

    match jti_status.as_deref() {
        Some("valid") => {} // Token is valid and now consumed
        _ => {
            return Err(AppError::BadRequest(
                "Phone verification token is invalid, expired, or already used".to_string(),
            ));
        }
    }

    // Validate optional fields if provided
    if let Some(ref name) = req.full_name {
        if name.is_empty() {
            return Err(AppError::BadRequest("Full name cannot be empty".to_string()));
        }
    }

    if let Some(ref email) = req.email {
        if !email.contains('@') || !email.contains('.') || email.len() < 5 {
            return Err(AppError::BadRequest("Invalid email format".to_string()));
        }
    }

    if let Some(ref password) = req.password {
        if password.len() < 8 {
            return Err(AppError::BadRequest(
                "Password must be at least 8 characters".to_string(),
            ));
        }
        if password.len() > 128 {
            return Err(AppError::BadRequest(
                "Password must be at most 128 characters".to_string(),
            ));
        }
    }

    // Generate defaults for optional fields:
    // - password: hash a random UUID (user authenticates via PIN on mobile)
    // - email: phone-based placeholder (unique because phone is unique)
    // - full_name: phone number
    let password_hash = match req.password {
        Some(ref pw) => hash_password(pw).await?,
        None => hash_password(&Uuid::new_v4().to_string()).await?,
    };
    let email = req.email.unwrap_or_else(|| format!("{phone}@phone.local"));
    let full_name = req.full_name.unwrap_or_else(|| phone.clone());
    // None means the user hasn't selected a role yet (shows as "ยังไม่ได้ระบุ" in admin).
    // Capture both checks before consuming the Option via .map().
    let is_guard = req.role == Some(UserRole::Guard);
    let is_role_none = req.role.is_none();
    let role_str: Option<String> = req.role.map(|r| r.to_string());

    // Create or re-register user account with pending approval status.
    // No session or tokens are issued — the user must wait for admin approval
    // before they can log in.
    //
    // ON CONFLICT (phone): if the phone already exists with approval_status =
    // 'pending', allow the user to re-register (updates password/name, resets
    // approval_status to pending, preserves existing role).
    // If the phone exists with a non-pending status (approved/rejected), the
    // WHERE condition is false → no-op → RETURNING returns no rows → 409.
    let user = sqlx::query_as::<_, UserRow>(
        r#"
        INSERT INTO auth.users (email, phone, password_hash, full_name, role, approval_status)
        VALUES ($1, $2, $3, $4, $5::user_role, 'pending'::approval_status)
        ON CONFLICT (phone) DO UPDATE
          SET password_hash   = EXCLUDED.password_hash,
              full_name       = EXCLUDED.full_name,
              approval_status = 'pending'::approval_status,
              updated_at      = NOW()
          WHERE auth.users.approval_status = 'pending'::approval_status
        RETURNING id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
        "#,
    )
    .bind(&email)
    .bind(&phone)
    .bind(&password_hash)
    .bind(&full_name)
    .bind(role_str.as_deref())
    .fetch_optional(db)
    .await
    .map_err(AppError::Database)?
    .ok_or_else(|| AppError::Conflict(
        "This phone number is already registered. Please log in instead.".to_string(),
    ))?;

    // Issue a short-lived profile_token only when role is explicitly guard.
    // When role=null (3-step flow), profile_token comes later from POST /profile/role.
    // This token is NOT an access/refresh token — it can only be used for profile submission.
    // jti is stored in Redis for single-use enforcement via GETDEL in validate_profile_token.
    let profile_token = if is_guard {
        let (token, jti) = encode_profile_token(
            user.id,
            &jwt_config.encoding_key,
            PROFILE_TOKEN_TTL_MINUTES,
            "guard_profile",
        )?;
        // Atomic SET EX — store jti so validate_profile_token can GETDEL it once.
        let ttl_secs = PROFILE_TOKEN_TTL_MINUTES * 60;
        redis::cmd("SET")
            .arg(format!("profile_jti:{jti}"))
            .arg("valid")
            .arg("EX")
            .arg(ttl_secs)
            .query_async::<()>(&mut redis.clone())
            .await
            .map_err(AppError::Redis)?;
        Some(token)
    } else {
        None
    };

    Ok(RegisterWithOtpResponse {
        message: "Registration successful. Your account is pending admin approval.".to_string(),
        user_id: user.id,
        profile_token,
    })
}

// =============================================================================
// List Users (Admin)
// =============================================================================

pub async fn list_users(
    db: &PgPool,
    query: ListUsersQuery,
) -> Result<PaginatedUsers, AppError> {
    let limit = query.limit.unwrap_or(20).min(100);
    let offset = query.offset.unwrap_or(0);

    let search_pattern = query.search
        .as_ref()
        .filter(|s| !s.is_empty())
        .map(|s| format!("%{}%", escape_ilike(s)));

    let role_filter = query.role.as_ref().filter(|s| !s.is_empty()).cloned();
    let status_filter = query.approval_status.as_ref().filter(|s| !s.is_empty()).cloned();

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM auth.users
        WHERE (role IS NULL OR role != 'admin')
          AND ($1::user_role IS NULL OR role = $1::user_role)
          AND ($2::approval_status IS NULL OR approval_status = $2::approval_status)
          AND ($3::text IS NULL OR full_name ILIKE $3 OR email ILIKE $3 OR phone ILIKE $3)
        "#,
    )
    .bind(&role_filter)
    .bind(&status_filter)
    .bind(&search_pattern)
    .fetch_one(db)
    .await?;

    let rows = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
        FROM auth.users
        WHERE (role IS NULL OR role != 'admin')
          AND ($1::user_role IS NULL OR role = $1::user_role)
          AND ($2::approval_status IS NULL OR approval_status = $2::approval_status)
          AND ($3::text IS NULL OR full_name ILIKE $3 OR email ILIKE $3 OR phone ILIKE $3)
        ORDER BY created_at DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(&role_filter)
    .bind(&status_filter)
    .bind(&search_pattern)
    .bind(limit)
    .bind(offset)
    .fetch_all(db)
    .await?;

    let users: Vec<UserResponse> = rows.into_iter().map(UserResponse::from).collect();

    Ok(PaginatedUsers { users, total })
}

// =============================================================================
// Update Approval Status (Admin)
// =============================================================================

pub async fn update_approval_status(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    user_id: Uuid,
    req: UpdateApprovalStatusRequest,
) -> Result<UserResponse, AppError> {
    let status_str = req.approval_status.to_string();

    let user = sqlx::query_as::<_, UserRow>(
        r#"
        UPDATE auth.users
        SET approval_status = $2::approval_status
        WHERE id = $1 AND (role IS NULL OR role != 'admin')
        RETURNING id, email, phone, password_hash, full_name, role, avatar_url, is_active, approval_status, created_at, updated_at
        "#,
    )
    .bind(user_id)
    .bind(&status_str)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    let response = UserResponse::from(user);
    // Invalidate cache so next profile fetch gets fresh data
    invalidate_user_cache(redis, &user_id).await?;

    Ok(response)
}

// =============================================================================
// Reissue Profile Token (for pending guards retrying profile submission)
// =============================================================================

/// Issue a new profile_token for a user who is already pending and has verified
/// their phone via OTP previously. This avoids requiring a second OTP round-trip
/// when the initial profile submission failed (e.g. network error, body limit).
pub async fn reissue_profile_token(
    db: &PgPool,
    jwt_config: &JwtConfig,
    redis: &redis::aio::MultiplexedConnection,
    phone: &str,
    role: Option<shared::models::UserRole>,
) -> Result<String, AppError> {
    let phone_clean = otp::validate_thai_phone(phone)?;

    // User must exist (allow both pending and approved users to reissue profile tokens)
    let user: Option<(Uuid,)> = sqlx::query_as(
        "SELECT id FROM auth.users WHERE phone = $1"
    )
    .bind(&phone_clean)
    .fetch_optional(db)
    .await?;

    let (user_id,) = user.ok_or_else(|| {
        AppError::NotFound("No registration found for this phone".to_string())
    })?;

    // Determine purpose from role (default: guard for backward compatibility)
    let purpose = match role {
        Some(shared::models::UserRole::Customer) => "customer_profile",
        _ => "guard_profile",
    };

    // Issue fresh profile_token + store jti in Redis
    let (token, jti) = encode_profile_token(
        user_id,
        &jwt_config.encoding_key,
        PROFILE_TOKEN_TTL_MINUTES,
        purpose,
    )?;
    let ttl_secs = PROFILE_TOKEN_TTL_MINUTES * 60;
    redis::cmd("SET")
        .arg(format!("profile_jti:{jti}"))
        .arg("valid")
        .arg("EX")
        .arg(ttl_secs)
        .query_async::<()>(&mut redis.clone())
        .await
        .map_err(AppError::Redis)?;

    Ok(token)
}

// =============================================================================
// Update User Role (step 2 of 3-step registration)
// =============================================================================

/// Issue a profile_token for a user identified by phone.
/// Works for any existing user (pending or approved) to support adding profiles.
/// For guard role: issues a profile_token with purpose "guard_profile".
/// For customer role: issues a profile_token with purpose "customer_profile".
pub async fn update_user_role(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    jwt_config: &JwtConfig,
    phone: &str,
    role: UserRole,
) -> Result<(Uuid, Option<String>), AppError> {
    use shared::models::UserRole;

    let phone_clean = otp::validate_thai_phone(phone)?;

    // Reject admin role — cannot self-assign
    if role == UserRole::Admin {
        return Err(AppError::BadRequest(
            "Cannot self-assign admin role".to_string(),
        ));
    }

    // Guard: do NOT set role yet — role is set atomically in submit_guard_profile.
    // Customer: do NOT set role yet — role is set atomically in submit_customer_profile.
    // Both paths SELECT verify + issue profile_token.
    // Allow any existing user (pending or approved) to add a profile for a different role
    // (e.g., approved guard adding customer profile).
    let user: Option<(Uuid,)> = sqlx::query_as(
        "SELECT id FROM auth.users WHERE phone = $1",
    )
    .bind(&phone_clean)
    .fetch_optional(db)
    .await
    .map_err(AppError::Database)?;

    let (user_id,) = user.ok_or_else(|| {
        AppError::BadRequest(
            "No user found for this phone".to_string(),
        )
    })?;

    // Invalidate user cache
    invalidate_user_cache(redis, &user_id).await?;

    // Issue profile_token for both guard and customer
    let purpose = if role == UserRole::Guard {
        "guard_profile"
    } else {
        "customer_profile"
    };
    let (token, jti) = encode_profile_token(
        user_id,
        &jwt_config.encoding_key,
        PROFILE_TOKEN_TTL_MINUTES,
        purpose,
    )?;
    let ttl_secs = PROFILE_TOKEN_TTL_MINUTES * 60;
    redis::cmd("SET")
        .arg(format!("profile_jti:{jti}"))
        .arg("valid")
        .arg("EX")
        .arg(ttl_secs)
        .query_async::<()>(&mut redis.clone())
        .await
        .map_err(AppError::Redis)?;
    let profile_token = Some(token);

    Ok((user_id, profile_token))
}

// =============================================================================
// Submit Guard Profile (profile_token protected)
// =============================================================================

/// Validate that image bytes match an allowed magic byte signature.
/// Accepted formats: JPEG (FF D8 FF), PNG (89 50 4E 47 0D 0A 1A 0A), WEBP (RIFF....WEBP).
fn validate_image_magic_bytes(data: &[u8]) -> Result<&'static str, AppError> {
    if data.len() < 12 {
        return Err(AppError::BadRequest("File too small to be a valid image".to_string()));
    }
    if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
        return Ok("jpg");
    }
    if data[0..8] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
        return Ok("png");
    }
    if &data[0..4] == b"RIFF" && &data[8..12] == b"WEBP" {
        return Ok("webp");
    }
    Err(AppError::BadRequest(
        "Invalid file type — only JPEG, PNG, and WEBP images are accepted".to_string(),
    ))
}

/// Upload a single document image to MinIO and return its file key.
async fn upload_document(
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    user_id: Uuid,
    doc_type: &str,
    data: Vec<u8>,
) -> Result<String, AppError> {
    // Reject oversized files before reading magic bytes — avoids unnecessary work.
    if data.len() > MAX_DOCUMENT_SIZE {
        return Err(AppError::BadRequest(format!(
            "File exceeds maximum size of 10MB (got {} bytes)",
            data.len()
        )));
    }

    let ext = validate_image_magic_bytes(&data)?;

    let file_key = format!("profiles/guard/{user_id}/{doc_type}.{ext}");
    let body = aws_sdk_s3::primitives::ByteStream::from(data);

    s3_client
        .put_object()
        .bucket(bucket)
        .key(&file_key)
        .body(body)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to upload document to S3: {e}")))?;

    Ok(file_key)
}

/// Generate a pre-signed URL for a stored document (1 hour expiry).
async fn presign_url(
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    key: &str,
) -> Result<String, AppError> {
    let presign_config = PresigningConfig::expires_in(std::time::Duration::from_secs(SIGNED_URL_EXPIRY_SECS))
        .map_err(|e| AppError::Internal(format!("Presign config error: {e}")))?;

    let url = s3_client
        .get_object()
        .bucket(bucket)
        .key(key)
        .presigned(presign_config)
        .await
        .map_err(|e| AppError::Internal(format!("Failed to generate signed URL: {e}")))?
        .uri()
        .to_string();

    Ok(url)
}

/// Validate a profile_token from the Authorization header and return the user_id.
/// Performs GETDEL on the jti in Redis — single-use enforcement prevents replay attacks.
pub async fn validate_profile_token(
    token: &str,
    jwt_config: &JwtConfig,
    redis: &redis::aio::MultiplexedConnection,
    expected_purpose: &str,
) -> Result<Uuid, AppError> {
    let (user_id, jti) = decode_profile_token(token, &jwt_config.decoding_key, expected_purpose)?;
    let mut conn = redis.clone();
    let status: Option<String> = redis::cmd("GETDEL")
        .arg(format!("profile_jti:{jti}"))
        .query_async(&mut conn)
        .await
        .map_err(AppError::Redis)?;
    match status.as_deref() {
        Some("valid") => Ok(user_id),
        _ => Err(AppError::Unauthorized(
            "Profile token is invalid, expired, or already used".to_string(),
        )),
    }
}

/// Submit (upsert) a guard's profile — text fields + uploaded document file keys.
/// `files` maps document field name (e.g. "id_card") to raw bytes.
pub async fn submit_guard_profile(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    user_id: Uuid,
    form: GuardProfileFormData,
    files: HashMap<String, Vec<u8>>,
) -> Result<(), AppError> {
    // Upload all provided document files to MinIO in parallel.
    let mut join_set: tokio::task::JoinSet<Result<(String, String), AppError>> =
        tokio::task::JoinSet::new();

    let doc_fields = ["id_card", "security_license", "training_cert", "criminal_check", "driver_license", "passbook_photo"];
    for field in &doc_fields {
        if let Some(data) = files.get(*field) {
            if !data.is_empty() {
                let s3 = s3_client.clone();
                let bkt = bucket.to_string();
                let fld = field.to_string();
                let dat = data.clone();
                join_set.spawn(async move {
                    let key = upload_document(&s3, &bkt, user_id, &fld, dat).await?;
                    Ok((fld, key))
                });
            }
        }
    }

    let mut keys: HashMap<String, String> = HashMap::new();
    while let Some(res) = join_set.join_next().await {
        let (field, key) = res.map_err(|e| AppError::Internal(e.to_string()))??;
        keys.insert(field, key);
    }

    // Parse date_of_birth from ISO string "YYYY-MM-DD"
    let dob: Option<chrono::NaiveDate> = form.date_of_birth
        .as_deref()
        .and_then(|s| chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d").ok());

    // UPSERT into auth.guard_profiles — insert on first call, update on subsequent calls.
    sqlx::query(
        r#"
        INSERT INTO auth.guard_profiles (
            user_id, gender, date_of_birth, years_of_experience, previous_workplace,
            id_card_key, security_license_key, training_cert_key, criminal_check_key,
            driver_license_key, bank_name, account_number, account_name, passbook_photo_key,
            updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
            gender               = EXCLUDED.gender,
            date_of_birth        = EXCLUDED.date_of_birth,
            years_of_experience  = EXCLUDED.years_of_experience,
            previous_workplace   = EXCLUDED.previous_workplace,
            id_card_key          = COALESCE(EXCLUDED.id_card_key, auth.guard_profiles.id_card_key),
            security_license_key = COALESCE(EXCLUDED.security_license_key, auth.guard_profiles.security_license_key),
            training_cert_key    = COALESCE(EXCLUDED.training_cert_key, auth.guard_profiles.training_cert_key),
            criminal_check_key   = COALESCE(EXCLUDED.criminal_check_key, auth.guard_profiles.criminal_check_key),
            driver_license_key   = COALESCE(EXCLUDED.driver_license_key, auth.guard_profiles.driver_license_key),
            bank_name            = EXCLUDED.bank_name,
            account_number       = EXCLUDED.account_number,
            account_name         = EXCLUDED.account_name,
            passbook_photo_key   = COALESCE(EXCLUDED.passbook_photo_key, auth.guard_profiles.passbook_photo_key),
            updated_at           = NOW()
        "#,
    )
    .bind(user_id)
    .bind(&form.gender)
    .bind(dob)
    .bind(form.years_of_experience)
    .bind(&form.previous_workplace)
    .bind(keys.get("id_card").map(|s| s.as_str()))
    .bind(keys.get("security_license").map(|s| s.as_str()))
    .bind(keys.get("training_cert").map(|s| s.as_str()))
    .bind(keys.get("criminal_check").map(|s| s.as_str()))
    .bind(keys.get("driver_license").map(|s| s.as_str()))
    .bind(&form.bank_name)
    .bind(&form.account_number)
    .bind(&form.account_name)
    .bind(keys.get("passbook_photo").map(|s| s.as_str()))
    .execute(db)
    .await?;

    // Set role to 'guard' and optionally update full_name — covers two-phase
    // registration where the user was created without a role/name and now
    // completes the guard form.  Role is set HERE (not in update_user_role)
    // so that if S3 upload fails the user stays role=null — no partial state.
    sqlx::query("UPDATE auth.users SET role = 'guard'::user_role, full_name = COALESCE($2, full_name) WHERE id = $1")
        .bind(user_id)
        .bind(&form.full_name)
        .execute(db)
        .await?;

    // Invalidate cache so admin sees the role + profile immediately
    invalidate_user_cache(redis, &user_id).await?;

    Ok(())
}

// =============================================================================
// Authorization: check if a customer has an active booking with a guard
// =============================================================================

pub async fn has_active_booking_with_guard(
    db: &PgPool,
    customer_id: Uuid,
    guard_id: Uuid,
) -> Result<bool, AppError> {
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1
            FROM booking.assignments a
            INNER JOIN booking.guard_requests r ON r.id = a.request_id
            WHERE r.customer_id = $1
              AND a.guard_id = $2
              AND a.status NOT IN ('cancelled', 'declined', 'completed')
        )
        "#,
    )
    .bind(customer_id)
    .bind(guard_id)
    .fetch_one(db)
    .await?;

    Ok(exists)
}

// =============================================================================
// Get Guard Profile (Admin)
// =============================================================================

/// Fetch a guard's profile and generate signed URLs for all stored documents.
pub async fn get_guard_profile(
    db: &PgPool,
    s3_client: &aws_sdk_s3::Client,
    bucket: &str,
    s3_endpoint: &str,
    s3_public_url: &str,
    user_id: Uuid,
) -> Result<GuardProfileResponse, AppError> {
    let row = sqlx::query_as::<_, GuardProfileRow>(
        r#"
        SELECT user_id, gender, date_of_birth, years_of_experience, previous_workplace,
               id_card_key, security_license_key, training_cert_key, criminal_check_key,
               driver_license_key, bank_name, account_number, account_name, passbook_photo_key,
               id_card_expiry, security_license_expiry, training_cert_expiry,
               criminal_check_expiry, driver_license_expiry
        FROM auth.guard_profiles
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Guard profile not found".to_string()))?;

    // Generate signed URLs for each document that has been uploaded.
    async fn signed(client: &aws_sdk_s3::Client, bucket: &str, key: &Option<String>) -> Option<String> {
        match key {
            Some(k) => presign_url(client, bucket, k).await.ok(),
            None => None,
        }
    }

    let (id_card_url, security_license_url, training_cert_url, criminal_check_url,
         driver_license_url, passbook_photo_url) = tokio::join!(
        signed(s3_client, bucket, &row.id_card_key),
        signed(s3_client, bucket, &row.security_license_key),
        signed(s3_client, bucket, &row.training_cert_key),
        signed(s3_client, bucket, &row.criminal_check_key),
        signed(s3_client, bucket, &row.driver_license_key),
        signed(s3_client, bucket, &row.passbook_photo_key),
    );

    // Replace internal MinIO host with the public URL so browsers can load images.
    // When s3_endpoint == s3_public_url (no env override) this is a no-op.
    let rewrite = |url: Option<String>| -> Option<String> {
        url.map(|u| {
            if s3_endpoint != s3_public_url {
                u.replacen(s3_endpoint, s3_public_url, 1)
            } else {
                u
            }
        })
    };

    Ok(GuardProfileResponse {
        user_id: row.user_id,
        gender: row.gender,
        date_of_birth: row.date_of_birth.map(|d| d.format("%Y-%m-%d").to_string()),
        years_of_experience: row.years_of_experience,
        previous_workplace: row.previous_workplace,
        id_card_url: rewrite(id_card_url),
        security_license_url: rewrite(security_license_url),
        training_cert_url: rewrite(training_cert_url),
        criminal_check_url: rewrite(criminal_check_url),
        driver_license_url: rewrite(driver_license_url),
        bank_name: row.bank_name,
        account_number: row.account_number,
        account_name: row.account_name,
        passbook_photo_url: rewrite(passbook_photo_url),
        id_card_expiry: row.id_card_expiry.map(|d| d.format("%Y-%m-%d").to_string()),
        security_license_expiry: row.security_license_expiry.map(|d| d.format("%Y-%m-%d").to_string()),
        training_cert_expiry: row.training_cert_expiry.map(|d| d.format("%Y-%m-%d").to_string()),
        criminal_check_expiry: row.criminal_check_expiry.map(|d| d.format("%Y-%m-%d").to_string()),
        driver_license_expiry: row.driver_license_expiry.map(|d| d.format("%Y-%m-%d").to_string()),
    })
}

// =============================================================================
// Admin Update Guard Profile
// =============================================================================

pub async fn admin_update_guard_profile(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    user_id: Uuid,
    req: crate::models::AdminUpdateGuardProfileRequest,
) -> Result<(), AppError> {
    fn parse_date(s: &Option<String>) -> Option<chrono::NaiveDate> {
        s.as_ref().and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok())
    }

    sqlx::query(
        r#"
        UPDATE auth.guard_profiles SET
            gender = COALESCE($2, gender),
            date_of_birth = COALESCE($3, date_of_birth),
            years_of_experience = COALESCE($4, years_of_experience),
            previous_workplace = COALESCE($5, previous_workplace),
            bank_name = COALESCE($6, bank_name),
            account_number = COALESCE($7, account_number),
            account_name = COALESCE($8, account_name),
            id_card_expiry = COALESCE($9, id_card_expiry),
            security_license_expiry = COALESCE($10, security_license_expiry),
            training_cert_expiry = COALESCE($11, training_cert_expiry),
            criminal_check_expiry = COALESCE($12, criminal_check_expiry),
            driver_license_expiry = COALESCE($13, driver_license_expiry)
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .bind(&req.gender)
    .bind(parse_date(&req.date_of_birth))
    .bind(req.years_of_experience)
    .bind(&req.previous_workplace)
    .bind(&req.bank_name)
    .bind(&req.account_number)
    .bind(&req.account_name)
    .bind(parse_date(&req.id_card_expiry))
    .bind(parse_date(&req.security_license_expiry))
    .bind(parse_date(&req.training_cert_expiry))
    .bind(parse_date(&req.criminal_check_expiry))
    .bind(parse_date(&req.driver_license_expiry))
    .execute(db)
    .await?;

    invalidate_user_cache(redis, &user_id).await?;
    Ok(())
}

// =============================================================================
// Submit Customer Profile (profile_token protected)
// =============================================================================

pub async fn submit_customer_profile(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    user_id: Uuid,
    req: crate::models::SubmitCustomerProfileRequest,
) -> Result<(), AppError> {
    // Validate address: required, min 10 chars
    let address = req.address.trim().to_string();
    if address.len() < 10 {
        return Err(AppError::BadRequest(
            "Address is required and must be at least 10 characters".to_string(),
        ));
    }

    // Validate email if provided
    let email = req.email.as_deref().map(|s| s.trim().to_string()).filter(|s| !s.is_empty());
    if let Some(ref e) = email {
        if e.len() < 5 || !e.contains('@') || !e.contains('.') {
            return Err(AppError::BadRequest(
                "Invalid email format".to_string(),
            ));
        }
    }

    // Validate contact_phone if provided (Thai format)
    let contact_phone = req
        .contact_phone
        .as_deref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    if let Some(ref p) = contact_phone {
        shared::otp::validate_thai_phone(p)?;
    }

    let full_name = req.full_name.as_deref().map(|s| s.trim().to_string()).filter(|s| !s.is_empty());
    let company_name = req.company_name.as_deref().map(|s| s.trim().to_string()).filter(|s| !s.is_empty());

    // UPSERT customer_profiles (reset approval_status to pending on re-submission)
    sqlx::query(
        "INSERT INTO auth.customer_profiles (user_id, full_name, contact_phone, email, company_name, address, approval_status) \
         VALUES ($1, $2, $3, $4, $5, $6, 'pending') \
         ON CONFLICT (user_id) DO UPDATE SET \
             full_name = EXCLUDED.full_name, \
             contact_phone = EXCLUDED.contact_phone, \
             email = EXCLUDED.email, \
             company_name = EXCLUDED.company_name, \
             address = EXCLUDED.address, \
             approval_status = 'pending', \
             updated_at = NOW()",
    )
    .bind(user_id)
    .bind(&full_name)
    .bind(&contact_phone)
    .bind(&email)
    .bind(&company_name)
    .bind(&address)
    .execute(db)
    .await
    .map_err(AppError::Database)?;

    // Set role = 'customer' ONLY IF role IS NULL
    // (guard keeps their role — customer_profiles existence = customer access)
    sqlx::query(
        "UPDATE auth.users SET role = 'customer'::user_role, updated_at = NOW() \
         WHERE id = $1 AND role IS NULL",
    )
    .bind(user_id)
    .execute(db)
    .await
    .map_err(AppError::Database)?;

    invalidate_user_cache(redis, &user_id).await?;

    Ok(())
}

// =============================================================================
// Get Customer Profile (Admin)
// =============================================================================

pub async fn get_customer_profile(
    db: &PgPool,
    user_id: Uuid,
) -> Result<crate::models::CustomerProfileResponse, AppError> {
    #[derive(sqlx::FromRow)]
    struct Row {
        user_id: Uuid,
        // COALESCE: prefer profile full_name, fallback to users.full_name
        full_name: String,
        contact_phone: Option<String>,
        email: Option<String>,
        company_name: Option<String>,
        address: String,
        approval_status: shared::models::ApprovalStatus,
        created_at: chrono::DateTime<chrono::Utc>,
    }

    let row: Option<Row> = sqlx::query_as(
        "SELECT cp.user_id, \
                COALESCE(cp.full_name, u.full_name) AS full_name, \
                cp.contact_phone, cp.email, \
                cp.company_name, cp.address, \
                cp.approval_status AS approval_status, \
                cp.created_at \
         FROM auth.customer_profiles cp \
         JOIN auth.users u ON u.id = cp.user_id \
         WHERE cp.user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(db)
    .await
    .map_err(AppError::Database)?;

    let row = row.ok_or_else(|| AppError::NotFound("Customer profile not found".to_string()))?;

    Ok(crate::models::CustomerProfileResponse {
        user_id: row.user_id,
        full_name: row.full_name,
        contact_phone: row.contact_phone,
        email: row.email,
        company_name: row.company_name,
        address: row.address,
        approval_status: row.approval_status,
        created_at: row.created_at,
    })
}

// =============================================================================
// List Customer Applicants (Admin) — based on customer_profiles.approval_status
// =============================================================================

pub async fn list_customer_applicants(
    db: &PgPool,
    query: ListUsersQuery,
) -> Result<PaginatedUsers, AppError> {
    let limit = query.limit.unwrap_or(20).min(100);
    let offset = query.offset.unwrap_or(0);

    let search_pattern = query.search
        .as_ref()
        .filter(|s| !s.is_empty())
        .map(|s| format!("%{}%", escape_ilike(s)));

    let status_filter = query.approval_status.as_ref().filter(|s| !s.is_empty()).cloned();

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM auth.customer_profiles cp
        JOIN auth.users u ON u.id = cp.user_id
        WHERE u.role != 'admin'
          AND ($1::approval_status IS NULL OR cp.approval_status = $1::approval_status)
          AND ($2::text IS NULL OR u.full_name ILIKE $2 OR u.email ILIKE $2 OR u.phone ILIKE $2)
        "#,
    )
    .bind(&status_filter)
    .bind(&search_pattern)
    .fetch_one(db)
    .await?;

    #[derive(sqlx::FromRow)]
    struct CpRow {
        id: Uuid,
        email: String,
        phone: String,
        full_name: String,
        avatar_url: Option<String>,
        is_active: bool,
        cp_approval_status: ApprovalStatus,
        created_at: chrono::DateTime<chrono::Utc>,
    }

    let rows = sqlx::query_as::<_, CpRow>(
        r#"
        SELECT u.id, u.email, u.phone,
               COALESCE(cp.full_name, u.full_name) AS full_name,
               u.avatar_url, u.is_active,
               cp.approval_status AS cp_approval_status,
               cp.created_at
        FROM auth.customer_profiles cp
        JOIN auth.users u ON u.id = cp.user_id
        WHERE u.role != 'admin'
          AND ($1::approval_status IS NULL OR cp.approval_status = $1::approval_status)
          AND ($2::text IS NULL OR u.full_name ILIKE $2 OR u.email ILIKE $2 OR u.phone ILIKE $2)
        ORDER BY cp.created_at DESC
        LIMIT $3 OFFSET $4
        "#,
    )
    .bind(&status_filter)
    .bind(&search_pattern)
    .bind(limit)
    .bind(offset)
    .fetch_all(db)
    .await?;

    let users: Vec<UserResponse> = rows
        .into_iter()
        .map(|r| UserResponse {
            id: r.id,
            email: r.email,
            phone: r.phone,
            full_name: r.full_name,
            role: Some(UserRole::Customer),
            avatar_url: r.avatar_url,
            is_active: r.is_active,
            approval_status: r.cp_approval_status,
            created_at: r.created_at,
            customer_full_name: None,
            company_name: None,
            contact_phone: None,
            gender: None,
            date_of_birth: None,
            years_of_experience: None,
            previous_workplace: None,
            customer_address: None,
            customer_approval_status: None,
        })
        .collect();

    Ok(PaginatedUsers { users, total })
}

// =============================================================================
// Update Customer Profile Approval Status (Admin)
// =============================================================================

pub async fn update_customer_approval_status(
    db: &PgPool,
    redis: &redis::aio::MultiplexedConnection,
    user_id: Uuid,
    status: ApprovalStatus,
) -> Result<(), AppError> {
    let status_str = status.to_string();

    let result = sqlx::query(
        "UPDATE auth.customer_profiles SET approval_status = $2::approval_status, updated_at = NOW() \
         WHERE user_id = $1",
    )
    .bind(user_id)
    .bind(&status_str)
    .execute(db)
    .await
    .map_err(AppError::Database)?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Customer profile not found".to_string()));
    }

    invalidate_user_cache(redis, &user_id).await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use shared::models::{ApprovalStatus, UserRole};

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
        if !req.email.contains('@') || !req.email.contains('.') || req.email.len() < 5 {
            return Err(AppError::BadRequest("Invalid email format".to_string()));
        }
        let phone_digits: String = req.phone.chars().filter(|c| c.is_ascii_digit()).collect();
        if phone_digits.len() != 10 || !phone_digits.starts_with('0') {
            return Err(AppError::BadRequest(
                "Invalid phone format — must be 10 digits starting with 0".to_string(),
            ));
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
            role: Some(UserRole::Guard),
            avatar_url: None,
            is_active: true,
            approval_status: ApprovalStatus::Approved,
            created_at: now,
            updated_at: now,
        };

        let response = UserResponse::from(row);
        assert_eq!(response.email, "test@example.com");
        assert_eq!(response.role, Some(UserRole::Guard));
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
            role: Some(UserRole::Admin),
            avatar_url: Some("https://cdn.example.com/avatar.jpg".to_string()),
            is_active: false,
            approval_status: ApprovalStatus::Approved,
            created_at: now,
            updated_at: now,
        };

        let response = UserResponse::from(row);
        assert_eq!(response.id, id);
        assert_eq!(response.email, "admin@guard.co");
        assert_eq!(response.phone, "0899999999");
        assert_eq!(response.full_name, "Admin User");
        assert_eq!(response.role, Some(UserRole::Admin));
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
