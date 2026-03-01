use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use chrono::Utc;
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::error::AppError;

#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
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
    let key = EncodingKey::from_secret(secret.as_bytes());
    encode_jwt_with_key(user_id, role, &key, expiry_hours)
}

/// Encode JWT using a pre-computed `EncodingKey` (cached in `JwtConfig`).
/// Avoids re-deriving the key on every call.
pub fn encode_jwt_with_key(
    user_id: Uuid,
    role: &str,
    key: &EncodingKey,
    expiry_hours: i64,
) -> Result<String, AppError> {
    let now = Utc::now();
    let claims = JwtClaims {
        sub: user_id,
        role: role.to_string(),
        exp: (now + chrono::TimeDelta::hours(expiry_hours)).timestamp(),
        iat: now.timestamp(),
    };

    jsonwebtoken::encode(&Header::default(), &claims, key)
        .map_err(|e| AppError::Internal(format!("Failed to encode JWT: {e}")))
}

pub fn decode_jwt(token: &str, secret: &str) -> Result<JwtClaims, AppError> {
    let key = DecodingKey::from_secret(secret.as_bytes());
    decode_jwt_with_key(token, &key)
}

/// Decode JWT using a pre-computed `DecodingKey` (cached in `JwtConfig`).
/// Avoids re-deriving the key on every call.
pub fn decode_jwt_with_key(token: &str, key: &DecodingKey) -> Result<JwtClaims, AppError> {
    let mut validation = Validation::default();
    // Require exp claim (already default), disable iss/aud for now
    // since we don't include them in the token yet. When adding
    // iss/aud to JwtClaims + encode, uncomment:
    // validation.set_issuer(&["guard-dispatch"]);
    // validation.set_audience(&["guard-dispatch"]);
    validation.validate_exp = true;

    let token_data = jsonwebtoken::decode::<JwtClaims>(token, key, &validation)
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
pub fn extract_cookie_value<'a>(cookie_header: &'a str, name: &str) -> Option<&'a str> {
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
#[derive(Debug, Clone, ToSchema)]
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

        let claims = decode_jwt_with_key(&token, state.decoding_key())?;

        Ok(AuthUser {
            user_id: claims.sub,
            role: claims.role,
        })
    }
}

/// Trait that AppState must implement to provide JWT secret for the AuthUser extractor.
pub trait HasJwtSecret {
    fn jwt_secret(&self) -> &str;

    /// Return a reference to a pre-computed `DecodingKey`.
    /// Implementors should store a cached `DecodingKey` in their state.
    fn decoding_key(&self) -> &DecodingKey;
}

impl<T: HasJwtSecret> HasJwtSecret for std::sync::Arc<T> {
    fn jwt_secret(&self) -> &str {
        T::jwt_secret(self)
    }

    fn decoding_key(&self) -> &DecodingKey {
        T::decoding_key(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::{header, Request};
    use std::sync::Arc;

    const TEST_SECRET: &str = "test-secret-key-at-least-64-chars-long-for-testing-purposes-only!!";

    // =========================================================================
    // JWT encode/decode
    // =========================================================================

    #[test]
    fn encode_then_decode_roundtrip() {
        let user_id = Uuid::new_v4();
        let token = encode_jwt(user_id, "admin", TEST_SECRET, 24).unwrap();
        let claims = decode_jwt(&token, TEST_SECRET).unwrap();
        assert_eq!(claims.sub, user_id);
        assert_eq!(claims.role, "admin");
    }

    #[test]
    fn decode_with_wrong_secret_fails() {
        let token = encode_jwt(Uuid::new_v4(), "guard", TEST_SECRET, 24).unwrap();
        let result = decode_jwt(&token, "wrong-secret");
        assert!(result.is_err());
    }

    #[test]
    fn decode_garbage_token_fails() {
        let result = decode_jwt("not.a.jwt", TEST_SECRET);
        assert!(result.is_err());
    }

    #[test]
    fn jwt_claims_contain_correct_role() {
        let user_id = Uuid::new_v4();
        let token = encode_jwt(user_id, "customer", TEST_SECRET, 1).unwrap();
        let claims = decode_jwt(&token, TEST_SECRET).unwrap();
        assert_eq!(claims.role, "customer");
    }

    #[test]
    fn jwt_expiry_is_set_correctly() {
        let user_id = Uuid::new_v4();
        let token = encode_jwt(user_id, "guard", TEST_SECRET, 24).unwrap();
        let claims = decode_jwt(&token, TEST_SECRET).unwrap();
        // exp should be roughly 24 hours from iat
        let diff = claims.exp - claims.iat;
        assert_eq!(diff, 24 * 3600);
    }

    #[test]
    fn jwt_iat_is_current_time() {
        let before = Utc::now().timestamp();
        let token = encode_jwt(Uuid::new_v4(), "admin", TEST_SECRET, 1).unwrap();
        let after = Utc::now().timestamp();
        let claims = decode_jwt(&token, TEST_SECRET).unwrap();
        assert!(claims.iat >= before && claims.iat <= after);
    }

    // =========================================================================
    // Cookie building
    // =========================================================================

    #[test]
    fn build_cookie_contains_required_attributes() {
        let cookie = build_cookie("access_token", "abc123", 3600, "/");
        assert!(cookie.contains("access_token=abc123"));
        assert!(cookie.contains("HttpOnly"));
        assert!(cookie.contains("Secure"));
        assert!(cookie.contains("SameSite=Lax"));
        assert!(cookie.contains("Path=/"));
        assert!(cookie.contains("Max-Age=3600"));
    }

    #[test]
    fn build_cookie_uses_custom_path() {
        let cookie = build_cookie("refresh_token", "xyz", 86400, "/auth");
        assert!(cookie.contains("Path=/auth"));
    }

    #[test]
    fn build_clear_cookie_sets_max_age_zero() {
        let cookie = build_clear_cookie("access_token", "/");
        assert!(cookie.contains("Max-Age=0"));
        assert!(cookie.contains("HttpOnly"));
        assert!(cookie.contains("Secure"));
    }

    // =========================================================================
    // Cookie extraction
    // =========================================================================

    #[test]
    fn extract_cookie_value_finds_named_cookie() {
        let header = "access_token=abc123; other=xyz";
        assert_eq!(extract_cookie_value(header, "access_token"), Some("abc123"));
    }

    #[test]
    fn extract_cookie_value_returns_none_for_missing() {
        let header = "other=xyz; another=123";
        assert_eq!(extract_cookie_value(header, "access_token"), None);
    }

    #[test]
    fn extract_cookie_value_handles_single_cookie() {
        let header = "access_token=mytoken";
        assert_eq!(extract_cookie_value(header, "access_token"), Some("mytoken"));
    }

    #[test]
    fn extract_cookie_value_handles_spaces() {
        let header = "  access_token = mytoken ; other = val  ";
        assert_eq!(extract_cookie_value(header, "access_token"), Some("mytoken"));
    }

    // =========================================================================
    // AuthUser extractor
    // =========================================================================

    struct TestState {
        jwt_secret: String,
        decoding_key: DecodingKey,
    }

    impl TestState {
        fn new(secret: &str) -> Self {
            Self {
                jwt_secret: secret.to_string(),
                decoding_key: DecodingKey::from_secret(secret.as_bytes()),
            }
        }
    }

    impl HasJwtSecret for TestState {
        fn jwt_secret(&self) -> &str {
            &self.jwt_secret
        }

        fn decoding_key(&self) -> &DecodingKey {
            &self.decoding_key
        }
    }

    #[tokio::test]
    async fn auth_user_extracts_from_bearer_header() {
        let state = Arc::new(TestState::new(TEST_SECRET));
        let user_id = Uuid::new_v4();
        let token = encode_jwt(user_id, "guard", TEST_SECRET, 24).unwrap();

        let mut request = Request::builder()
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(())
            .unwrap();

        let result =
            AuthUser::from_request_parts(&mut request.into_parts().0, &*state).await;
        let auth_user = result.unwrap();
        assert_eq!(auth_user.user_id, user_id);
        assert_eq!(auth_user.role, "guard");
    }

    #[tokio::test]
    async fn auth_user_extracts_from_cookie() {
        let state = Arc::new(TestState::new(TEST_SECRET));
        let user_id = Uuid::new_v4();
        let token = encode_jwt(user_id, "admin", TEST_SECRET, 24).unwrap();

        let mut request = Request::builder()
            .header(header::COOKIE, format!("access_token={token}; other=val"))
            .body(())
            .unwrap();

        let result =
            AuthUser::from_request_parts(&mut request.into_parts().0, &*state).await;
        let auth_user = result.unwrap();
        assert_eq!(auth_user.user_id, user_id);
        assert_eq!(auth_user.role, "admin");
    }

    #[tokio::test]
    async fn auth_user_prefers_bearer_over_cookie() {
        let state = Arc::new(TestState::new(TEST_SECRET));
        let bearer_id = Uuid::new_v4();
        let cookie_id = Uuid::new_v4();
        let bearer_token = encode_jwt(bearer_id, "guard", TEST_SECRET, 24).unwrap();
        let cookie_token = encode_jwt(cookie_id, "admin", TEST_SECRET, 24).unwrap();

        let mut request = Request::builder()
            .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
            .header(
                header::COOKIE,
                format!("access_token={cookie_token}"),
            )
            .body(())
            .unwrap();

        let result =
            AuthUser::from_request_parts(&mut request.into_parts().0, &*state).await;
        let auth_user = result.unwrap();
        assert_eq!(auth_user.user_id, bearer_id);
        assert_eq!(auth_user.role, "guard");
    }

    #[tokio::test]
    async fn auth_user_fails_with_no_token() {
        let state = Arc::new(TestState::new(TEST_SECRET));

        let mut request = Request::builder().body(()).unwrap();

        let result =
            AuthUser::from_request_parts(&mut request.into_parts().0, &*state).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn auth_user_fails_with_invalid_bearer() {
        let state = Arc::new(TestState::new(TEST_SECRET));

        let mut request = Request::builder()
            .header(header::AUTHORIZATION, "Bearer garbage.token.here")
            .body(())
            .unwrap();

        let result =
            AuthUser::from_request_parts(&mut request.into_parts().0, &*state).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn auth_user_fails_with_wrong_secret_cookie() {
        let state = Arc::new(TestState::new(TEST_SECRET));
        let token = encode_jwt(Uuid::new_v4(), "admin", "different-secret-key!!", 24).unwrap();

        let mut request = Request::builder()
            .header(header::COOKIE, format!("access_token={token}"))
            .body(())
            .unwrap();

        let result =
            AuthUser::from_request_parts(&mut request.into_parts().0, &*state).await;
        assert!(result.is_err());
    }

    #[test]
    fn has_jwt_secret_works_through_arc() {
        let state = Arc::new(TestState::new("my-secret"));
        assert_eq!(state.jwt_secret(), "my-secret");
    }
}
