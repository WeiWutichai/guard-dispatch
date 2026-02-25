use axum::extract::{Path, Query, State};
use axum::Json;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::AppError;
use shared::models::ApiResponse;

use crate::models::{
    ListNotificationsQuery, NotificationLogResponse, RegisterTokenRequest,
    SendNotificationRequest,
};
use crate::state::AppState;

/// POST /tokens — Register an FCM device token
pub async fn register_token(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<RegisterTokenRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    crate::service::register_token(&state.db, user.user_id, &req.token, &req.device_type).await?;
    Ok(Json(ApiResponse::success(())))
}

/// DELETE /tokens — Unregister an FCM device token
#[derive(serde::Deserialize)]
pub struct DeleteTokenRequest {
    pub token: String,
}

pub async fn unregister_token(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<DeleteTokenRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    crate::service::unregister_token(&state.db, user.user_id, &req.token).await?;
    Ok(Json(ApiResponse::success(())))
}

/// GET /notifications — List user notifications
pub async fn list_notifications(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListNotificationsQuery>,
) -> Result<Json<ApiResponse<Vec<NotificationLogResponse>>>, AppError> {
    let notifications =
        crate::service::list_notifications(&state.db, user.user_id, query).await?;
    Ok(Json(ApiResponse::success(notifications)))
}

/// PUT /notifications/{id}/read — Mark notification as read
pub async fn mark_as_read(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<NotificationLogResponse>>, AppError> {
    let notification = crate::service::mark_as_read(&state.db, id, user.user_id).await?;
    Ok(Json(ApiResponse::success(notification)))
}

/// POST /notifications/send — Send notification (internal/admin)
pub async fn send_notification(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<SendNotificationRequest>,
) -> Result<Json<ApiResponse<NotificationLogResponse>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can send notifications".to_string(),
        ));
    }
    let notification = crate::service::send_notification(
        &state.db,
        &state.http_client,
        &state.fcm_config,
        req,
    )
    .await?;
    Ok(Json(ApiResponse::success(notification)))
}
