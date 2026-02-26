use axum::extract::State;
use axum::http::header::SET_COOKIE;
use axum::http::HeaderMap;
use axum::Json;
use std::sync::Arc;

use shared::auth::{
    build_clear_cookie, build_cookie, AuthUser, ACCESS_TOKEN_COOKIE, REFRESH_TOKEN_COOKIE,
};
use shared::error::AppError;
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

pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let user = crate::service::register(&state.db, req).await?;
    Ok(Json(ApiResponse::success(user)))
}

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

pub async fn get_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let profile = crate::service::get_profile(&state.db, &state.redis, user.user_id).await?;
    Ok(Json(ApiResponse::success(profile)))
}

pub async fn update_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<UpdateProfileRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let profile =
        crate::service::update_profile(&state.db, &state.redis, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(profile)))
}

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
