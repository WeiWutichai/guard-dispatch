use axum::extract::State;
use axum::http::header::SET_COOKIE;
use axum::http::HeaderMap;
use axum::Json;
use std::sync::Arc;

use shared::auth::{
    build_clear_cookie, build_cookie, AuthUser, ACCESS_TOKEN_COOKIE, REFRESH_TOKEN_COOKIE,
};
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    AuthResponse, LoginRequest, RefreshRequest, RegisterRequest, UpdateProfileRequest,
    UserResponse,
};
use crate::state::AppState;

/// Helper: build Set-Cookie headers for access + refresh tokens + logged_in marker.
fn auth_cookie_headers(auth: &AuthResponse) -> HeaderMap {
    let mut headers = HeaderMap::new();

    // Access token cookie — httpOnly, Secure
    let access_cookie = build_cookie(
        ACCESS_TOKEN_COOKIE,
        &auth.access_token,
        auth.expires_in,
        "/",
    );
    headers.append(SET_COOKIE, access_cookie.parse().expect("valid cookie"));

    // Refresh token cookie — httpOnly, Secure, restricted to /auth path
    let refresh_cookie = build_cookie(
        REFRESH_TOKEN_COOKIE,
        &auth.refresh_token,
        30 * 24 * 3600,
        "/auth",
    );
    headers.append(SET_COOKIE, refresh_cookie.parse().expect("valid cookie"));

    // Non-httpOnly marker cookie for the frontend to detect auth state
    // This does NOT contain any sensitive data — just "1"
    let marker_cookie = format!(
        "logged_in=1; SameSite=Lax; Path=/; Max-Age={}",
        auth.expires_in
    );
    headers.append(SET_COOKIE, marker_cookie.parse().expect("valid cookie"));

    headers
}

#[utoipa::path(
    post,
    path = "/register",
    tag = "Auth",
    request_body = RegisterRequest,
    responses(
        (status = 200, description = "User registered successfully", body = UserResponse),
        (status = 400, description = "Validation error", body = ErrorBody),
        (status = 409, description = "Email already exists", body = ErrorBody),
    ),
)]
pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let user = crate::service::register(&state.db, req).await?;
    Ok(Json(ApiResponse::success(user)))
}

#[utoipa::path(
    post,
    path = "/login",
    tag = "Auth",
    request_body = LoginRequest,
    responses(
        (status = 200, description = "Login successful, tokens returned", body = AuthResponse),
        (status = 401, description = "Invalid credentials", body = ErrorBody),
    ),
)]
pub async fn login(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<LoginRequest>,
) -> Result<(HeaderMap, Json<ApiResponse<AuthResponse>>), AppError> {
    let ip_address = headers
        .get("X-Real-IP")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());
    let device_info = headers
        .get("User-Agent")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let auth = crate::service::login(
        &state.db,
        &state.redis,
        &state.jwt_config,
        req,
        ip_address,
        device_info,
    )
    .await?;

    let cookie_headers = auth_cookie_headers(&auth);
    Ok((cookie_headers, Json(ApiResponse::success(auth))))
}

#[utoipa::path(
    post,
    path = "/refresh",
    tag = "Auth",
    request_body = RefreshRequest,
    responses(
        (status = 200, description = "Token refreshed successfully", body = AuthResponse),
        (status = 400, description = "Missing refresh token", body = ErrorBody),
        (status = 401, description = "Invalid or expired refresh token", body = ErrorBody),
    ),
)]
pub async fn refresh_token(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<RefreshRequest>,
) -> Result<(HeaderMap, Json<ApiResponse<AuthResponse>>), AppError> {
    // Accept refresh_token from body or cookie
    let refresh_tok = if req.refresh_token.is_empty() {
        // Try to read from cookie
        headers
            .get("Cookie")
            .and_then(|v| v.to_str().ok())
            .and_then(|cookies| {
                cookies
                    .split(';')
                    .map(|s| s.trim())
                    .find_map(|pair| {
                        let (key, value) = pair.split_once('=')?;
                        if key.trim() == REFRESH_TOKEN_COOKIE {
                            Some(value.trim().to_string())
                        } else {
                            None
                        }
                    })
            })
            .unwrap_or_default()
    } else {
        req.refresh_token.clone()
    };

    if refresh_tok.is_empty() {
        return Err(AppError::BadRequest("refresh_token is required".to_string()));
    }

    let auth = crate::service::refresh_token(
        &state.db,
        &state.redis,
        &state.jwt_config,
        &refresh_tok,
    )
    .await?;

    let cookie_headers = auth_cookie_headers(&auth);
    Ok((cookie_headers, Json(ApiResponse::success(auth))))
}

#[utoipa::path(
    get,
    path = "/me",
    tag = "Profile",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "User profile retrieved", body = UserResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn get_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let profile = crate::service::get_profile(&state.db, &state.redis, user.user_id).await?;
    Ok(Json(ApiResponse::success(profile)))
}

#[utoipa::path(
    put,
    path = "/me",
    tag = "Profile",
    security(("bearer" = [])),
    request_body = UpdateProfileRequest,
    responses(
        (status = 200, description = "Profile updated", body = UserResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn update_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<UpdateProfileRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let profile =
        crate::service::update_profile(&state.db, &state.redis, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(profile)))
}

#[utoipa::path(
    post,
    path = "/logout",
    tag = "Auth",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Logged out, cookies cleared"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn logout(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<(HeaderMap, Json<ApiResponse<()>>), AppError> {
    crate::service::logout(&state.db, &state.redis, user.user_id).await?;

    // Clear auth cookies
    let mut headers = HeaderMap::new();
    let clear_access = build_clear_cookie(ACCESS_TOKEN_COOKIE, "/");
    headers.append(SET_COOKIE, clear_access.parse().expect("valid cookie"));
    let clear_refresh = build_clear_cookie(REFRESH_TOKEN_COOKIE, "/auth");
    headers.append(SET_COOKIE, clear_refresh.parse().expect("valid cookie"));
    // Clear the logged_in marker cookie
    let clear_marker = "logged_in=; SameSite=Lax; Path=/; Max-Age=0".to_string();
    headers.append(SET_COOKIE, clear_marker.parse().expect("valid cookie"));

    Ok((headers, Json(ApiResponse::success(()))))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_auth_response() -> AuthResponse {
        AuthResponse {
            access_token: "access-jwt-token".to_string(),
            refresh_token: "refresh-uuid-token".to_string(),
            token_type: "Bearer".to_string(),
            expires_in: 86400, // 24 hours
        }
    }

    #[test]
    fn auth_cookie_headers_sets_three_cookies() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers.get_all(SET_COOKIE).iter().collect();
        assert_eq!(cookies.len(), 3);
    }

    #[test]
    fn auth_cookie_headers_access_token_is_httponly() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let access = cookies.iter().find(|c| c.starts_with("access_token=")).unwrap();
        assert!(access.contains("HttpOnly"), "access_token must be HttpOnly");
        assert!(access.contains("Secure"), "access_token must be Secure");
        assert!(access.contains("SameSite=Lax"), "access_token must be SameSite=Lax");
        assert!(access.contains("Path=/"), "access_token must have Path=/");
    }

    #[test]
    fn auth_cookie_headers_refresh_token_restricted_to_auth_path() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let refresh = cookies.iter().find(|c| c.starts_with("refresh_token=")).unwrap();
        assert!(refresh.contains("Path=/auth"), "refresh_token must have Path=/auth");
        assert!(refresh.contains("HttpOnly"));
        assert!(refresh.contains("Secure"));
    }

    #[test]
    fn auth_cookie_headers_logged_in_marker_is_not_httponly() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let marker = cookies.iter().find(|c| c.starts_with("logged_in=")).unwrap();
        assert!(!marker.contains("HttpOnly"), "logged_in must NOT be HttpOnly");
        assert!(marker.contains("logged_in=1"), "logged_in value must be '1'");
    }

    #[test]
    fn auth_cookie_headers_access_token_contains_jwt() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let access = cookies.iter().find(|c| c.starts_with("access_token=")).unwrap();
        assert!(access.contains("access-jwt-token"));
    }

    #[test]
    fn auth_cookie_headers_refresh_token_has_30_day_max_age() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let refresh = cookies.iter().find(|c| c.starts_with("refresh_token=")).unwrap();
        let expected_max_age = 30 * 24 * 3600;
        assert!(
            refresh.contains(&format!("Max-Age={expected_max_age}")),
            "refresh_token must have 30-day Max-Age"
        );
    }
}
