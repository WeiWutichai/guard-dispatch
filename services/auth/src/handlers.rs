use axum::extract::State;
use axum::Json;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::AppError;
use shared::models::ApiResponse;

use crate::models::{
    AuthResponse, LoginRequest, RefreshRequest, RegisterRequest, UpdateProfileRequest,
    UserResponse,
};
use crate::state::AppState;

pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let user = crate::service::register(&state.db, req).await?;
    Ok(Json(ApiResponse::success(user)))
}

pub async fn login(
    State(state): State<Arc<AppState>>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<ApiResponse<AuthResponse>>, AppError> {
    let auth = crate::service::login(
        &state.db,
        &state.redis,
        &state.jwt_config,
        req,
        None, // TODO: extract from X-Real-IP header
        None, // TODO: extract from User-Agent header
    )
    .await?;
    Ok(Json(ApiResponse::success(auth)))
}

pub async fn refresh_token(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RefreshRequest>,
) -> Result<Json<ApiResponse<AuthResponse>>, AppError> {
    let auth = crate::service::refresh_token(
        &state.db,
        &state.redis,
        &state.jwt_config,
        &req.refresh_token,
    )
    .await?;
    Ok(Json(ApiResponse::success(auth)))
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
) -> Result<Json<ApiResponse<()>>, AppError> {
    crate::service::logout(&state.db, &state.redis, user.user_id).await?;
    Ok(Json(ApiResponse::success(())))
}
