use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use shared::models::UserRole;
use utoipa::ToSchema;
use uuid::Uuid;

// =============================================================================
// Request DTOs
// =============================================================================

#[derive(Debug, Deserialize, ToSchema)]
pub struct RegisterRequest {
    pub email: String,
    pub phone: String,
    pub password: String,
    pub full_name: String,
    #[serde(default = "default_role")]
    pub role: UserRole,
}

fn default_role() -> UserRole {
    UserRole::Customer
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct RefreshRequest {
    #[serde(default)]
    pub refresh_token: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateProfileRequest {
    pub full_name: Option<String>,
    pub phone: Option<String>,
    pub avatar_url: Option<String>,
}

// =============================================================================
// Response DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct AuthResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in: i64,
}

#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: String,
    pub phone: String,
    pub full_name: String,
    pub role: UserRole,
    pub avatar_url: Option<String>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
}

// =============================================================================
// Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct UserRow {
    pub id: Uuid,
    pub email: String,
    pub phone: String,
    pub password_hash: String,
    pub full_name: String,
    pub role: UserRole,
    pub avatar_url: Option<String>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<UserRow> for UserResponse {
    fn from(row: UserRow) -> Self {
        Self {
            id: row.id,
            email: row.email,
            phone: row.phone,
            full_name: row.full_name,
            role: row.role,
            avatar_url: row.avatar_url,
            is_active: row.is_active,
            created_at: row.created_at,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct SessionRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
}
