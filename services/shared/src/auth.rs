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

/// Build a Set-Cookie header value for an httpOnly, Secure, SameSite=Lax cookie.
pub fn build_cookie(name: &str, value: &str, max_age_secs: i64, path: &str) -> String {
    format!(
        "{name}={value}; HttpOnly; Secure; SameSite=Lax; Path={path}; Max-Age={max_age_secs}"
    )
}

/// Build a Set-Cookie header to clear/expire a cookie.
pub fn build_clear_cookie(name: &str, path: &str) -> String {
    format!(
        "{name}=; HttpOnly; Secure; SameSite=Lax; Path={path}; Max-Age=0"
    )
}

/// Cookie names used for auth tokens.
pub const ACCESS_TOKEN_COOKIE: &str = "access_token";
pub const REFRESH_TOKEN_COOKIE: &str = "refresh_token";

/// Extract a named cookie value from a Cookie header string.
fn extract_cookie_value<'a>(cookie_header: &'a str, name: &str) -> Option<&'a str> {
    cookie_header
        .split(';')
        .map(|s| s.trim())
        .find_map(|pair| {
            let (key, value) = pair.split_once('=')?;
            if key.trim() == name {
                Some(value.trim())
            } else {
                None
            }
        })
}

/// Axum extractor that validates JWT from:
/// 1. Authorization: Bearer <token> header (for mobile/API clients)
/// 2. access_token cookie (for web browser clients)
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
        // Strategy 1: Authorization: Bearer <token> header
        let token = if let Some(auth_header) = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
        {
            auth_header
                .strip_prefix("Bearer ")
                .map(|t| t.to_string())
        } else {
            None
        };

        // Strategy 2: access_token cookie
        let token = token.or_else(|| {
            parts
                .headers
                .get("Cookie")
                .and_then(|v| v.to_str().ok())
                .and_then(|cookies| extract_cookie_value(cookies, ACCESS_TOKEN_COOKIE))
                .map(|t| t.to_string())
        });

        let token = token.ok_or_else(|| {
            AppError::Unauthorized("Missing authentication token".to_string())
        })?;

        let claims = decode_jwt(&token, state.jwt_secret())?;

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
