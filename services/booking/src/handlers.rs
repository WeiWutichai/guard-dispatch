use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::Json;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    AcceptDeclineDto, ActiveJobResponse, AssignGuardDto, AssignmentResponse,
    AvailableGuardResponse, AvailableGuardsQuery, CreatePaymentDto, CreateRequestDto,
    CreateServiceRateDto, GuardDashboardSummary, GuardEarnings, GuardJobResponse,
    GuardJobsQuery, GuardRatingsSummary, GuardRequestResponse, ListRequestsQuery,
    PaymentResponse, ServiceRate, UpdateAssignmentStatusDto, UpdateServiceRateDto,
    WorkHistoryResponse,
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
    // Admin can always assign; customer can assign to their own pending request
    if user.role != "admin" {
        let request = crate::service::get_request(&state.db, id).await?;
        if request.customer_id != user.user_id {
            return Err(AppError::Forbidden(
                "Only admins or request owners can assign guards".to_string(),
            ));
        }
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

// =============================================================================
// Guard-specific endpoints
// =============================================================================

#[utoipa::path(
    get,
    path = "/guard/dashboard",
    tag = "Guard",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Guard dashboard summary", body = GuardDashboardSummary),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guard only", body = ErrorBody),
    ),
)]
pub async fn guard_dashboard(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<GuardDashboardSummary>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let summary =
        crate::service::get_guard_dashboard_summary(&state.db, user.user_id).await?;
    Ok(Json(ApiResponse::success(summary)))
}

#[utoipa::path(
    get,
    path = "/guard/jobs",
    tag = "Guard",
    security(("bearer" = [])),
    params(ListRequestsQuery),
    responses(
        (status = 200, description = "Guard enriched jobs list", body = Vec<GuardJobResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guard only", body = ErrorBody),
    ),
)]
pub async fn guard_jobs(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListRequestsQuery>,
) -> Result<Json<ApiResponse<Vec<GuardJobResponse>>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let status_str = query.status.as_ref().map(|s| {
        serde_json::to_value(s)
            .ok()
            .and_then(|v| v.as_str().map(|s| s.to_string()))
            .unwrap_or_else(|| "assigned".to_string())
    });
    let limit = query.limit.unwrap_or(20).min(100);
    let offset = query.offset.unwrap_or(0);
    let jobs = crate::service::get_guard_jobs(
        &state.db,
        user.user_id,
        status_str.as_deref(),
        limit,
        offset,
    )
    .await?;
    Ok(Json(ApiResponse::success(jobs)))
}

#[utoipa::path(
    get,
    path = "/guard/earnings",
    tag = "Guard",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Guard earnings breakdown", body = GuardEarnings),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guard only", body = ErrorBody),
    ),
)]
pub async fn guard_earnings(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<GuardEarnings>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let earnings = crate::service::get_guard_earnings(&state.db, user.user_id).await?;
    Ok(Json(ApiResponse::success(earnings)))
}

#[utoipa::path(
    get,
    path = "/guard/work-history",
    tag = "Guard",
    security(("bearer" = [])),
    params(GuardJobsQuery),
    responses(
        (status = 200, description = "Guard work history", body = WorkHistoryResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guard only", body = ErrorBody),
    ),
)]
pub async fn guard_work_history(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<GuardJobsQuery>,
) -> Result<Json<ApiResponse<WorkHistoryResponse>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let limit = query.limit.unwrap_or(50).min(100);
    let offset = query.offset.unwrap_or(0);
    let history = crate::service::get_guard_work_history(
        &state.db,
        user.user_id,
        query.status.as_deref(),
        limit,
        offset,
    )
    .await?;
    Ok(Json(ApiResponse::success(history)))
}

#[utoipa::path(
    get,
    path = "/guard/ratings",
    tag = "Guard",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Guard ratings summary", body = GuardRatingsSummary),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guard only", body = ErrorBody),
    ),
)]
pub async fn guard_ratings(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<GuardRatingsSummary>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let ratings = crate::service::get_guard_ratings(&state.db, user.user_id).await?;
    Ok(Json(ApiResponse::success(ratings)))
}

// =============================================================================
// Accept / Decline Assignment
// =============================================================================

#[utoipa::path(
    put,
    path = "/assignments/{id}/accept",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    request_body = AcceptDeclineDto,
    responses(
        (status = 200, description = "Assignment accepted/declined", body = AssignmentResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn accept_decline_assignment(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<AcceptDeclineDto>,
) -> Result<Json<ApiResponse<AssignmentResponse>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let assignment =
        crate::service::accept_or_decline_assignment(&state.db, id, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(assignment)))
}

// =============================================================================
// Create Payment (simulated)
// =============================================================================

#[utoipa::path(
    post,
    path = "/payments",
    tag = "Payments",
    security(("bearer" = [])),
    request_body = CreatePaymentDto,
    responses(
        (status = 200, description = "Payment created", body = PaymentResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn create_payment(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<CreatePaymentDto>,
) -> Result<Json<ApiResponse<PaymentResponse>>, AppError> {
    let payment = crate::service::create_payment(&state.db, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(payment)))
}

// =============================================================================
// Start Job (guard starts countdown)
// =============================================================================

#[utoipa::path(
    put,
    path = "/assignments/{id}/start",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    responses(
        (status = 200, description = "Job started", body = ActiveJobResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn start_job(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<ActiveJobResponse>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let job = crate::service::start_job(&state.db, id, user.user_id).await?;
    Ok(Json(ApiResponse::success(job)))
}

// =============================================================================
// Get Active Job (guard's current job with countdown info)
// =============================================================================

#[utoipa::path(
    get,
    path = "/guard/active-job",
    tag = "Guard",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Active job info", body = Option<ActiveJobResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guard only", body = ErrorBody),
    ),
)]
pub async fn get_active_job(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<Option<ActiveJobResponse>>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let job = crate::service::get_active_job(&state.db, user.user_id).await?;
    Ok(Json(ApiResponse::success(job)))
}

// =============================================================================
// Available Guards (customer-facing guard discovery)
// =============================================================================

#[utoipa::path(
    get,
    path = "/available-guards",
    tag = "Guards",
    security(("bearer" = [])),
    params(AvailableGuardsQuery),
    responses(
        (status = 200, description = "List of available guards nearby", body = Vec<AvailableGuardResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn available_guards(
    State(state): State<Arc<AppState>>,
    _user: AuthUser,
    Query(query): Query<AvailableGuardsQuery>,
) -> Result<Json<ApiResponse<Vec<AvailableGuardResponse>>>, AppError> {
    let guards = crate::service::list_available_guards(&state.db, query).await?;
    Ok(Json(ApiResponse::success(guards)))
}

// =============================================================================
// Pricing (Service Rates) endpoints
// =============================================================================

#[utoipa::path(
    get,
    path = "/pricing/services",
    tag = "Pricing",
    responses(
        (status = 200, description = "List of active service rates", body = Vec<ServiceRate>),
    ),
)]
pub async fn list_service_rates(
    State(state): State<Arc<AppState>>,
) -> Result<Json<ApiResponse<Vec<ServiceRate>>>, AppError> {
    let rates = crate::service::list_service_rates(&state.db).await?;
    Ok(Json(ApiResponse::success(rates)))
}

#[utoipa::path(
    get,
    path = "/pricing/services/{id}",
    tag = "Pricing",
    params(("id" = Uuid, Path, description = "Service rate UUID")),
    responses(
        (status = 200, description = "Service rate details", body = ServiceRate),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn get_service_rate(
    State(state): State<Arc<AppState>>,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<ServiceRate>>, AppError> {
    let rate = crate::service::get_service_rate(&state.db, id).await?;
    Ok(Json(ApiResponse::success(rate)))
}

#[utoipa::path(
    post,
    path = "/pricing/services",
    tag = "Pricing",
    security(("bearer" = [])),
    request_body = CreateServiceRateDto,
    responses(
        (status = 200, description = "Service rate created", body = ServiceRate),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
    ),
)]
pub async fn create_service_rate(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(dto): Json<CreateServiceRateDto>,
) -> Result<Json<ApiResponse<ServiceRate>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can create service rates".to_string(),
        ));
    }
    let rate = crate::service::create_service_rate(&state.db, dto).await?;
    Ok(Json(ApiResponse::success(rate)))
}

#[utoipa::path(
    put,
    path = "/pricing/services/{id}",
    tag = "Pricing",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Service rate UUID")),
    request_body = UpdateServiceRateDto,
    responses(
        (status = 200, description = "Service rate updated", body = ServiceRate),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn update_service_rate(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(dto): Json<UpdateServiceRateDto>,
) -> Result<Json<ApiResponse<ServiceRate>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can update service rates".to_string(),
        ));
    }
    let rate = crate::service::update_service_rate(&state.db, id, dto).await?;
    Ok(Json(ApiResponse::success(rate)))
}

#[utoipa::path(
    delete,
    path = "/pricing/services/{id}",
    tag = "Pricing",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Service rate UUID")),
    responses(
        (status = 204, description = "Service rate deactivated"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn delete_service_rate(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<StatusCode, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can delete service rates".to_string(),
        ));
    }
    crate::service::delete_service_rate(&state.db, id).await?;
    Ok(StatusCode::NO_CONTENT)
}
