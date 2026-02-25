use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use chrono::Utc;
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::AppError;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JwtClaims {
    pub sub: Uuid,
    pub role: String,
    pub exp: i64,
    pub iat: i64,
}

pub fn encode_jwt(
    user_id: Uuid,
    role: &str,
    secret: &str,
    expiry_hours: i64,
) -> Result<String, AppError> {
    let now = Utc::now();
    let claims = JwtClaims {
        sub: user_id,
        role: role.to_string(),
        exp: (now + chrono::TimeDelta::hours(expiry_hours)).timestamp(),
        iat: now.timestamp(),
    };

    jsonwebtoken::encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|e| AppError::Internal(format!("Failed to encode JWT: {e}")))
}

pub fn decode_jwt(token: &str, secret: &str) -> Result<JwtClaims, AppError> {
    let token_data = jsonwebtoken::decode::<JwtClaims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|e| AppError::Unauthorized(format!("Invalid token: {e}")))?;

    Ok(token_data.claims)
}

/// Axum extractor that validates JWT from the Authorization header.
/// Usage: `async fn handler(user: AuthUser) -> ... { ... }`
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: Uuid,
    pub role: String,
}

impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync + HasJwtSecret,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AppError::Unauthorized("Missing Authorization header".to_string()))?;

        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or_else(|| AppError::Unauthorized("Invalid Authorization format".to_string()))?;

        let claims = decode_jwt(token, state.jwt_secret())?;

        Ok(AuthUser {
            user_id: claims.sub,
            role: claims.role,
        })
    }
}

/// Trait that AppState must implement to provide JWT secret for the AuthUser extractor.
pub trait HasJwtSecret {
    fn jwt_secret(&self) -> &str;
}

impl<T: HasJwtSecret> HasJwtSecret for std::sync::Arc<T> {
    fn jwt_secret(&self) -> &str {
        T::jwt_secret(self)
    }
}
