use axum::extract::{Path, Query, State};
use axum::Json;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    AssignGuardDto, AssignmentResponse, CreateRequestDto, GuardRequestResponse,
    ListRequestsQuery, UpdateAssignmentStatusDto,
};
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/requests",
    tag = "Requests",
    security(("bearer" = [])),
    request_body = CreateRequestDto,
    responses(
        (status = 200, description = "Request created", body = GuardRequestResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn create_request(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<CreateRequestDto>,
) -> Result<Json<ApiResponse<GuardRequestResponse>>, AppError> {
    let request = crate::service::create_request(&state.db, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(request)))
}

#[utoipa::path(
    get,
    path = "/requests",
    tag = "Requests",
    security(("bearer" = [])),
    params(ListRequestsQuery),
    responses(
        (status = 200, description = "List of requests", body = Vec<GuardRequestResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn list_requests(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListRequestsQuery>,
) -> Result<Json<ApiResponse<Vec<GuardRequestResponse>>>, AppError> {
    let requests =
        crate::service::list_requests(&state.db, user.user_id, &user.role, query).await?;
    Ok(Json(ApiResponse::success(requests)))
}

#[utoipa::path(
    get,
    path = "/requests/{id}",
    tag = "Requests",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Request UUID")),
    responses(
        (status = 200, description = "Request details", body = GuardRequestResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn get_request(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<GuardRequestResponse>>, AppError> {
    let request = crate::service::get_request(&state.db, id).await?;

    // Authorization: only the owning customer, an assigned guard, or admin
    if user.role != "admin" {
        let is_owner = request.customer_id == user.user_id;
        let is_assigned = crate::service::is_guard_assigned(&state.db, id, user.user_id).await?;
        if !is_owner && !is_assigned {
            return Err(AppError::Forbidden(
                "You do not have access to this request".to_string(),
            ));
        }
    }

    Ok(Json(ApiResponse::success(request)))
}

#[utoipa::path(
    put,
    path = "/requests/{id}/cancel",
    tag = "Requests",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Request UUID")),
    responses(
        (status = 200, description = "Request cancelled", body = GuardRequestResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn cancel_request(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<GuardRequestResponse>>, AppError> {
    let request = crate::service::cancel_request(&state.db, id, user.user_id, &user.role).await?;
    Ok(Json(ApiResponse::success(request)))
}

#[utoipa::path(
    post,
    path = "/requests/{id}/assign",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Request UUID")),
    request_body = AssignGuardDto,
    responses(
        (status = 200, description = "Guard assigned", body = AssignmentResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
    ),
)]
pub async fn assign_guard(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<AssignGuardDto>,
) -> Result<Json<ApiResponse<AssignmentResponse>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can assign guards".to_string(),
        ));
    }
    let assignment = crate::service::assign_guard(&state.db, id, req).await?;
    Ok(Json(ApiResponse::success(assignment)))
}

#[utoipa::path(
    put,
    path = "/assignments/{id}/status",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    request_body = UpdateAssignmentStatusDto,
    responses(
        (status = 200, description = "Status updated", body = AssignmentResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn update_assignment_status(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<UpdateAssignmentStatusDto>,
) -> Result<Json<ApiResponse<AssignmentResponse>>, AppError> {
    let assignment =
        crate::service::update_assignment_status(&state.db, id, user.user_id, &user.role, req).await?;
    Ok(Json(ApiResponse::success(assignment)))
}

#[utoipa::path(
    get,
    path = "/requests/{id}/assignments",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Request UUID")),
    responses(
        (status = 200, description = "List of assignments", body = Vec<AssignmentResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn get_assignments(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<Vec<AssignmentResponse>>>, AppError> {
    // Authorization: only the request owner, an assigned guard, or admin
    if user.role != "admin" {
        let request = crate::service::get_request(&state.db, id).await?;
        let is_owner = request.customer_id == user.user_id;
        let is_assigned = crate::service::is_guard_assigned(&state.db, id, user.user_id).await?;
        if !is_owner && !is_assigned {
            return Err(AppError::Forbidden(
                "You do not have access to this request's assignments".to_string(),
            ));
        }
    }

    let assignments = crate::service::get_assignments(&state.db, id).await?;
    Ok(Json(ApiResponse::success(assignments)))
}
