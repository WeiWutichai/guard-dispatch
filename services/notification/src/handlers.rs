use axum::extract::{Path, Query, State};
use axum::Json;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    ListNotificationsQuery, NotificationLogResponse, RegisterTokenRequest, RoleQuery,
    SendNotificationRequest, UnreadCountResponse,
};
use crate::state::AppState;

// =============================================================================
// Internal Push (service-to-service, no JWT)
// =============================================================================

/// Internal endpoint for other services (booking, chat) to trigger FCM push.
/// No JWT required — accessible only from Docker internal network.
/// Nginx does NOT proxy this path (no /notification/internal/ location).
///
/// The calling service has already INSERT'd the notification_logs row;
/// this endpoint only handles FCM push delivery.
pub async fn internal_push(
    State(state): State<Arc<AppState>>,
    Json(req): Json<SendNotificationRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    // Push-only path — callers INSERT their own log row before POSTing
    // here, so delegating to `send_notification` would double-log.
    crate::service::push_only(&state.db, &state.http_client, &state.fcm_auth, req).await?;
    Ok(Json(ApiResponse::success(())))
}

#[utoipa::path(
    post,
    path = "/tokens",
    tag = "FCM Tokens",
    security(("bearer" = [])),
    request_body = RegisterTokenRequest,
    responses(
        (status = 200, description = "Token registered"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn register_token(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<RegisterTokenRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    crate::service::register_token(&state.db, user.user_id, &req.token, &req.device_type).await?;
    Ok(Json(ApiResponse::success(())))
}

/// DELETE /tokens — Unregister an FCM device token
#[derive(serde::Deserialize, utoipa::ToSchema)]
pub struct DeleteTokenRequest {
    pub token: String,
}

#[utoipa::path(
    delete,
    path = "/tokens",
    tag = "FCM Tokens",
    security(("bearer" = [])),
    request_body = DeleteTokenRequest,
    responses(
        (status = 200, description = "Token unregistered"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn unregister_token(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<DeleteTokenRequest>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    crate::service::unregister_token(&state.db, user.user_id, &req.token).await?;
    Ok(Json(ApiResponse::success(())))
}

#[utoipa::path(
    get,
    path = "/notifications",
    tag = "Notifications",
    security(("bearer" = [])),
    params(ListNotificationsQuery),
    responses(
        (status = 200, description = "List of notifications", body = Vec<NotificationLogResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn list_notifications(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListNotificationsQuery>,
) -> Result<Json<ApiResponse<Vec<NotificationLogResponse>>>, AppError> {
    let notifications = crate::service::list_notifications(&state.db, user.user_id, query).await?;
    Ok(Json(ApiResponse::success(notifications)))
}

#[utoipa::path(
    get,
    path = "/notifications/unread-count",
    tag = "Notifications",
    security(("bearer" = [])),
    params(RoleQuery),
    responses(
        (status = 200, description = "Unread notification count", body = UnreadCountResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn unread_count(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<RoleQuery>,
) -> Result<Json<ApiResponse<UnreadCountResponse>>, AppError> {
    let count =
        crate::service::get_unread_count(&state.db, user.user_id, query.role.as_deref()).await?;
    Ok(Json(ApiResponse::success(UnreadCountResponse { count })))
}

#[utoipa::path(
    put,
    path = "/notifications/read-all",
    tag = "Notifications",
    security(("bearer" = [])),
    params(RoleQuery),
    responses(
        (status = 200, description = "All notifications marked as read", body = UnreadCountResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn mark_all_as_read(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<RoleQuery>,
) -> Result<Json<ApiResponse<UnreadCountResponse>>, AppError> {
    let count =
        crate::service::mark_all_as_read(&state.db, user.user_id, query.role.as_deref()).await?;
    Ok(Json(ApiResponse::success(UnreadCountResponse { count })))
}

#[utoipa::path(
    put,
    path = "/notifications/{id}/read",
    tag = "Notifications",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Notification UUID")),
    responses(
        (status = 200, description = "Notification marked as read", body = NotificationLogResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn mark_as_read(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<NotificationLogResponse>>, AppError> {
    let notification = crate::service::mark_as_read(&state.db, id, user.user_id).await?;
    Ok(Json(ApiResponse::success(notification)))
}

#[utoipa::path(
    post,
    path = "/notifications/send",
    tag = "Notifications",
    security(("bearer" = [])),
    request_body = SendNotificationRequest,
    responses(
        (status = 200, description = "Notification sent", body = NotificationLogResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
    ),
)]
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
    let notification =
        crate::service::send_notification(&state.db, &state.http_client, &state.fcm_auth, req)
            .await?;
    Ok(Json(ApiResponse::success(notification)))
}
