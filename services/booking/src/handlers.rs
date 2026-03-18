use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Multipart, Path, Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::Json;
use futures_util::StreamExt;
use std::sync::Arc;

use uuid::Uuid;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    AcceptDeclineDto, ActiveJobResponse, AssignGuardDto, AssignmentResponse,
    AvailableGuardResponse, AvailableGuardsQuery, CreatePaymentDto, CreateRequestDto,
    CreateReviewDto, CreateServiceRateDto, GuardDashboardSummary, GuardEarnings,
    GuardJobResponse, GuardJobsQuery, GuardRatingsSummary, GuardRequestResponse,
    ListRequestsQuery, PaymentResponse, ProgressReportResponse, ReviewCompletionDto, ServiceRate,
    StartJobDto, SubmitReviewResponse, UpdateAssignmentStatusDto, UpdateServiceRateDto,
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
        crate::service::update_assignment_status(&state.db, id, user.user_id, &user.role, req, &state.redis_conn, &state.http_client).await?;
    Ok(Json(ApiResponse::success(assignment)))
}

#[utoipa::path(
    put,
    path = "/assignments/{id}/review-completion",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    request_body = ReviewCompletionDto,
    responses(
        (status = 200, description = "Completion reviewed", body = AssignmentResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn review_completion(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<ReviewCompletionDto>,
) -> Result<Json<ApiResponse<AssignmentResponse>>, AppError> {
    let assignment =
        crate::service::review_completion(&state.db, id, user.user_id, &user.role, req, &state.redis_conn).await?;
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
// Submit Review (customer rates guard after completion)
// =============================================================================

#[utoipa::path(
    post,
    path = "/assignments/{id}/review",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    request_body = CreateReviewDto,
    responses(
        (status = 200, description = "Review submitted", body = SubmitReviewResponse),
        (status = 400, description = "Bad request", body = ErrorBody),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 409, description = "Review already exists", body = ErrorBody),
    ),
)]
pub async fn submit_review(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<CreateReviewDto>,
) -> Result<Json<ApiResponse<SubmitReviewResponse>>, AppError> {
    let result = crate::service::submit_review(&state.db, id, user.user_id, &user.role, req).await?;
    Ok(Json(ApiResponse::success(result)))
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
// Public Guard Reviews (any authenticated user)
// =============================================================================

#[utoipa::path(
    get,
    path = "/guards/{guard_id}/reviews",
    tag = "Guards",
    security(("bearer" = [])),
    params(
        ("guard_id" = Uuid, Path, description = "Guard user ID"),
    ),
    responses(
        (status = 200, description = "Guard ratings and reviews", body = GuardRatingsSummary),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn get_guard_reviews(
    State(state): State<Arc<AppState>>,
    Path(guard_id): Path<Uuid>,
    _user: AuthUser,
) -> Result<Json<ApiResponse<GuardRatingsSummary>>, AppError> {
    let ratings = crate::service::get_guard_ratings(&state.db, guard_id).await?;
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
        crate::service::accept_or_decline_assignment(&state.db, id, user.user_id, req, &state.redis_conn).await?;
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
    let payment = crate::service::create_payment(&state.db, user.user_id, req, &state.redis_conn).await?;
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
    body: Option<Json<StartJobDto>>,
) -> Result<Json<ApiResponse<ActiveJobResponse>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let (lat, lng) = body.map(|b| (b.lat, b.lng)).unwrap_or((None, None));
    let job = crate::service::start_job(&state.db, id, user.user_id, lat, lng, &state.http_client).await?;
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
// Get Active Job for Customer (customer views guard's countdown)
// =============================================================================

#[utoipa::path(
    get,
    path = "/requests/{id}/active-job",
    tag = "Requests",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Request UUID")),
    responses(
        (status = 200, description = "Active job info for this request", body = Option<ActiveJobResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Request not found", body = ErrorBody),
    ),
)]
pub async fn get_customer_active_job(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(request_id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<Option<ActiveJobResponse>>>, AppError> {
    let job = crate::service::get_customer_active_job(&state.db, request_id, user.user_id, &user.role).await?;
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

// =============================================================================
// WebSocket — Real-time assignment status updates
// =============================================================================

#[utoipa::path(
    get,
    path = "/ws/assignments",
    tag = "Assignments",
    security(("bearer" = [])),
    responses(
        (status = 101, description = "WebSocket upgrade for real-time assignment status updates. Send request_id as first text message."),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn ws_assignment_status(
    State(state): State<Arc<AppState>>,
    ws: WebSocketUpgrade,
    user: AuthUser,
) -> Result<impl IntoResponse, AppError> {
    Ok(ws.on_upgrade(move |socket| handle_assignment_ws(socket, state, user)))
}

async fn handle_assignment_ws(mut socket: WebSocket, state: Arc<AppState>, user: AuthUser) {
    tracing::info!(
        "Assignment WS connected: user_id={}, role={}",
        user.user_id,
        user.role
    );

    // Step 1: Client sends request_id as the first message (per CLAUDE.md — no sensitive IDs in URL)
    let request_id: String = loop {
        match socket.recv().await {
            Some(Ok(Message::Text(text))) => {
                let trimmed = text.trim().to_string();
                if !trimmed.is_empty() {
                    break trimmed;
                }
            }
            Some(Ok(Message::Close(_))) | None => {
                tracing::info!("Assignment WS closed before sending request_id");
                return;
            }
            _ => continue,
        }
    };

    tracing::info!(
        "Assignment WS subscribing: request_id={}, user_id={}",
        request_id,
        user.user_id
    );

    // Step 2: Subscribe to Redis channel for this request's assignment updates
    let channel = format!("assignment_status:{request_id}");

    let mut pubsub = match state.redis_client.get_async_pubsub().await {
        Ok(ps) => ps,
        Err(e) => {
            tracing::error!("Failed to create Redis PubSub connection: {e}");
            let _ = socket
                .send(Message::Text(
                    serde_json::json!({"error": "Internal server error"})
                        .to_string()
                        .into(),
                ))
                .await;
            return;
        }
    };

    if let Err(e) = pubsub.subscribe(&channel).await {
        tracing::error!("Failed to subscribe to {channel}: {e}");
        return;
    }

    // Send ack to confirm subscription
    let _ = socket
        .send(Message::Text(
            serde_json::json!({"type": "subscribed", "request_id": request_id})
                .to_string()
                .into(),
        ))
        .await;

    // Step 3: Forward Redis messages to WebSocket client
    let mut msg_stream = pubsub.on_message();

    loop {
        tokio::select! {
            // Redis pub/sub message received — forward to client
            Some(msg) = msg_stream.next() => {
                let payload: String = match msg.get_payload() {
                    Ok(p) => p,
                    Err(_) => continue,
                };
                if socket.send(Message::Text(payload.into())).await.is_err() {
                    break; // Client disconnected
                }
            }
            // Client message — handle close/ping
            Some(client_msg) = socket.recv() => {
                match client_msg {
                    Ok(Message::Close(_)) | Err(_) => break,
                    Ok(Message::Ping(data)) => {
                        let _ = socket.send(Message::Pong(data)).await;
                    }
                    _ => {} // Ignore other messages
                }
            }
            else => break,
        }
    }

    tracing::info!(
        "Assignment WS disconnected: request_id={}, user_id={}",
        request_id,
        user.user_id
    );
}

// =============================================================================
// Progress Reports
// =============================================================================

/// Submit an hourly progress report (guard, multipart: hour_number + message + photo)
#[utoipa::path(
    post,
    path = "/assignments/{id}/progress-reports",
    tag = "Progress Reports",
    params(("id" = Uuid, Path, description = "Assignment ID")),
    responses(
        (status = 200, description = "Report submitted", body = ProgressReportResponse),
        (status = 409, description = "Already reported for this hour"),
    ),
    security(("bearer" = [])),
)]
pub async fn submit_progress_report(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
    mut multipart: Multipart,
) -> Result<Json<ApiResponse<ProgressReportResponse>>, AppError> {
    let mut hour_number: Option<i32> = None;
    let mut message: Option<String> = None;
    let mut photo_data: Option<Vec<u8>> = None;
    let mut photo_mime: Option<String> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(format!("Failed to read multipart: {e}")))?
    {
        let name = field.name().unwrap_or("").to_string();

        match name.as_str() {
            "hour_number" => {
                let text = field
                    .text()
                    .await
                    .map_err(|e| AppError::BadRequest(format!("Invalid hour_number: {e}")))?;
                hour_number = Some(
                    text.parse::<i32>()
                        .map_err(|e| AppError::BadRequest(format!("Invalid hour_number: {e}")))?,
                );
            }
            "message" => {
                message = Some(
                    field
                        .text()
                        .await
                        .map_err(|e| AppError::BadRequest(format!("Invalid message: {e}")))?,
                );
            }
            "photo" => {
                photo_mime = field.content_type().map(|s| s.to_string());
                let data = field
                    .bytes()
                    .await
                    .map_err(|e| AppError::BadRequest(format!("Failed to read photo: {e}")))?
                    .to_vec();
                photo_data = Some(data);
            }
            _ => {}
        }
    }

    let hour_number =
        hour_number.ok_or_else(|| AppError::BadRequest("hour_number is required".to_string()))?;

    // Validate photo if provided
    let validated_photo = if let Some(data) = photo_data {
        let mime = photo_mime.unwrap_or_else(|| "application/octet-stream".to_string());
        crate::s3::validate_upload(&mime, data.len(), &data)?;
        Some((data, mime))
    } else {
        None
    };

    let result = crate::service::submit_progress_report(
        &state.db,
        &state.s3_client,
        &state.s3_bucket,
        &state.s3_endpoint,
        &state.s3_public_url,
        id,
        user.user_id,
        hour_number,
        message,
        validated_photo,
    )
    .await?;

    Ok(Json(ApiResponse::success(result)))
}

/// List progress reports for an assignment
#[utoipa::path(
    get,
    path = "/assignments/{id}/progress-reports",
    tag = "Progress Reports",
    params(("id" = Uuid, Path, description = "Assignment ID")),
    responses(
        (status = 200, description = "Progress reports list", body = Vec<ProgressReportResponse>),
    ),
    security(("bearer" = [])),
)]
pub async fn list_progress_reports(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiResponse<Vec<ProgressReportResponse>>>, AppError> {
    let reports = crate::service::list_progress_reports(
        &state.db,
        &state.s3_client,
        &state.s3_bucket,
        &state.s3_endpoint,
        &state.s3_public_url,
        id,
        user.user_id,
        &user.role,
    )
    .await?;

    Ok(Json(ApiResponse::success(reports)))
}
