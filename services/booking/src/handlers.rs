use axum::extract::{Path, Query, State};
use axum::Json;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::AppError;
use shared::models::ApiResponse;

use crate::models::{
    AssignGuardDto, AssignmentResponse, CreateRequestDto, GuardRequestResponse,
    ListRequestsQuery, UpdateAssignmentStatusDto,
};
use crate::state::AppState;

/// POST /requests — Create a new guard request (customer)
pub async fn create_request(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<CreateRequestDto>,
) -> Result<Json<ApiResponse<GuardRequestResponse>>, AppError> {
    let request = crate::service::create_request(&state.db, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(request)))
}

/// GET /requests — List guard requests (role-based filtering)
pub async fn list_requests(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListRequestsQuery>,
) -> Result<Json<ApiResponse<Vec<GuardRequestResponse>>>, AppError> {
    let requests =
        crate::service::list_requests(&state.db, user.user_id, &user.role, query).await?;
    Ok(Json(ApiResponse::success(requests)))
}

/// GET /requests/{id} — Get a specific guard request
pub async fn get_request(
    State(state): State<Arc<AppState>>,
    _user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<GuardRequestResponse>>, AppError> {
    let request = crate::service::get_request(&state.db, id).await?;
    Ok(Json(ApiResponse::success(request)))
}

/// PUT /requests/{id}/cancel — Cancel a guard request (customer only)
pub async fn cancel_request(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<GuardRequestResponse>>, AppError> {
    let request = crate::service::cancel_request(&state.db, id, user.user_id).await?;
    Ok(Json(ApiResponse::success(request)))
}

/// POST /requests/{id}/assign — Assign a guard to a request (admin only)
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

/// PUT /assignments/{id}/status — Update assignment status (guard only)
pub async fn update_assignment_status(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<UpdateAssignmentStatusDto>,
) -> Result<Json<ApiResponse<AssignmentResponse>>, AppError> {
    let assignment =
        crate::service::update_assignment_status(&state.db, id, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(assignment)))
}

/// GET /requests/{id}/assignments — Get assignments for a request
pub async fn get_assignments(
    State(state): State<Arc<AppState>>,
    _user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<Vec<AssignmentResponse>>>, AppError> {
    let assignments = crate::service::get_assignments(&state.db, id).await?;
    Ok(Json(ApiResponse::success(assignments)))
}
