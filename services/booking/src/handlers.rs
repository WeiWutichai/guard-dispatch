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
    AcceptDeclineDto, ActiveJobResponse, AddTipDto, AdminPaymentItem, AdminPaymentsPage,
    AdminPaymentsQuery, AdminRefundsQuery, AdminReviewsQuery, AssignGuardDto, AssignmentResponse,
    AvailableGuardResponse, AvailableGuardsQuery, CostSummaryResponse, CreatePaymentDto,
    CreateRequestDto, CreateReviewDto, CreateServiceRateDto, GuardDashboardSummary, GuardEarnings,
    GuardJobResponse, GuardJobsQuery, GuardRatingsSummary, GuardRequestResponse, ListReceiptsQuery,
    ListRequestsQuery, PaginatedAdminReviews, PaymentResponse, ProcessRefundRequest,
    ProgressReportResponse, ReceiptsPage, ReviewCompletionDto, ServiceRate, StartJobDto,
    SubmitReviewResponse, ToggleReviewVisibilityDto, UpdateAssignmentStatusDto,
    UpdateServiceRateDto, WalletSummary, WorkHistoryResponse,
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
    // Only users with an approved customer profile (or admins) can create booking requests.
    // A guard who also registered as a customer has role='guard' in auth.users but has
    // an approved customer_profiles entry — they should be allowed to book.
    if user.role != "admin" {
        let has_customer_profile: Option<bool> = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM auth.customer_profiles WHERE user_id = $1 AND approval_status = 'approved')",
        )
        .bind(user.user_id)
        .fetch_one(&state.db)
        .await?;
        if !has_customer_profile.unwrap_or(false) {
            return Err(AppError::Forbidden(
                "Only approved customers can create booking requests".to_string(),
            ));
        }
    }
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
    let assignment = crate::service::update_assignment_status(
        &state.db,
        id,
        user.user_id,
        &user.role,
        req,
        &state.redis_conn,
        &state.http_client,
    )
    .await?;
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
    let assignment = crate::service::review_completion(
        &state.db,
        id,
        user.user_id,
        &user.role,
        req,
        &state.redis_conn,
    )
    .await?;
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
    let result =
        crate::service::submit_review(&state.db, id, user.user_id, &user.role, req).await?;
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
    let summary = crate::service::get_guard_dashboard_summary(&state.db, user.user_id).await?;
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
// Admin Reviews — list across all guards / toggle visibility
// =============================================================================

#[utoipa::path(
    get,
    path = "/admin/reviews",
    tag = "Admin Reviews",
    security(("bearer" = [])),
    params(AdminReviewsQuery),
    responses(
        (status = 200, description = "Paginated reviews with global stats", body = PaginatedAdminReviews),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin only", body = ErrorBody),
    ),
)]
pub async fn list_admin_reviews(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<AdminReviewsQuery>,
) -> Result<Json<ApiResponse<PaginatedAdminReviews>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can list all reviews".to_string(),
        ));
    }
    let result = crate::service::list_admin_reviews(&state.db, query).await?;
    Ok(Json(ApiResponse::success(result)))
}

#[utoipa::path(
    put,
    path = "/admin/reviews/{id}/visibility",
    tag = "Admin Reviews",
    security(("bearer" = [])),
    request_body = ToggleReviewVisibilityDto,
    params(("id" = Uuid, Path, description = "Review ID")),
    responses(
        (status = 200, description = "Visibility updated"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin only", body = ErrorBody),
        (status = 404, description = "Review not found", body = ErrorBody),
    ),
)]
pub async fn set_review_visibility(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
    Json(req): Json<ToggleReviewVisibilityDto>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Only admins can change review visibility".to_string(),
        ));
    }
    crate::service::set_review_visibility(&state.db, id, req.is_visible).await?;
    Ok(Json(ApiResponse::success(())))
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
    let assignment = crate::service::accept_or_decline_assignment(
        &state.db,
        id,
        user.user_id,
        req,
        &state.redis_conn,
    )
    .await?;
    Ok(Json(ApiResponse::success(assignment)))
}

/// Guard cancels an assignment that is still awaiting payment.
/// Resets the request so the customer can pick another guard (or cancel themselves).
#[utoipa::path(
    put,
    path = "/assignments/{id}/cancel-unpaid",
    tag = "Assignments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment ID")),
    responses(
        (status = 200, description = "Assignment cancelled", body = AssignmentResponse),
        (status = 400, description = "Not awaiting payment", body = ErrorBody),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Assignment not found", body = ErrorBody),
    ),
)]
pub async fn cancel_unpaid_assignment(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<AssignmentResponse>>, AppError> {
    if user.role != "guard" {
        return Err(AppError::Forbidden("Guard only endpoint".to_string()));
    }
    let assignment =
        crate::service::guard_cancel_unpaid(&state.db, id, user.user_id, &state.redis_conn)
            .await?;
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
    let payment =
        crate::service::create_payment(&state.db, user.user_id, req, &state.redis_conn).await?;
    Ok(Json(ApiResponse::success(payment)))
}

// =============================================================================
// Cost Summary (read) + Add Tip (write)
// =============================================================================

#[utoipa::path(
    get,
    path = "/assignments/{id}/cost-summary",
    tag = "Payments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    responses(
        (status = 200, description = "Cost summary", body = CostSummaryResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn get_cost_summary(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<CostSummaryResponse>>, AppError> {
    let summary = crate::service::get_cost_summary(&state.db, id, user.user_id, &user.role).await?;
    Ok(Json(ApiResponse::success(summary)))
}

#[utoipa::path(
    get,
    path = "/customer/receipts",
    tag = "Payments",
    security(("bearer" = [])),
    params(ListReceiptsQuery),
    responses(
        (status = 200, description = "Paginated list of completed-job receipts", body = ReceiptsPage),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn list_customer_receipts(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListReceiptsQuery>,
) -> Result<Json<ApiResponse<ReceiptsPage>>, AppError> {
    let page = crate::service::list_customer_receipts(&state.db, user.user_id, query).await?;
    Ok(Json(ApiResponse::success(page)))
}

// =============================================================================
// Admin: refund workflow (migration 042)
// =============================================================================

fn require_admin(user: &AuthUser) -> Result<(), AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden(
            "Admin role required for this endpoint".to_string(),
        ));
    }
    Ok(())
}

#[utoipa::path(
    get,
    path = "/admin/payments",
    tag = "Admin",
    security(("bearer" = [])),
    params(AdminPaymentsQuery),
    responses(
        (status = 200, description = "All payments list", body = AdminPaymentsPage),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin role required", body = ErrorBody),
    ),
)]
pub async fn list_admin_payments(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<AdminPaymentsQuery>,
) -> Result<Json<ApiResponse<AdminPaymentsPage>>, AppError> {
    require_admin(&user)?;
    let page = crate::service::list_admin_payments(&state.db, query).await?;
    Ok(Json(ApiResponse::success(page)))
}

#[utoipa::path(
    get,
    path = "/admin/refunds",
    tag = "Admin",
    security(("bearer" = [])),
    params(AdminRefundsQuery),
    responses(
        (status = 200, description = "Refunds list filtered by status", body = AdminPaymentsPage),
        (status = 400, description = "Invalid status filter", body = ErrorBody),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin role required", body = ErrorBody),
    ),
)]
pub async fn list_admin_refunds(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<AdminRefundsQuery>,
) -> Result<Json<ApiResponse<AdminPaymentsPage>>, AppError> {
    require_admin(&user)?;
    let page = crate::service::list_admin_refunds(&state.db, query).await?;
    Ok(Json(ApiResponse::success(page)))
}

/// Admin-only active-operations dashboard.
/// Lists every in-flight assignment (pending_acceptance → pending_completion)
/// with the latest guard GPS snapshot + progress-report counters.
#[utoipa::path(
    get,
    path = "/admin/active-operations",
    tag = "Admin",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Active assignments with GPS + progress counters", body = crate::models::AdminActiveOpsResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin role required", body = ErrorBody),
    ),
)]
pub async fn list_active_operations(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<crate::models::AdminActiveOpsResponse>>, AppError> {
    require_admin(&user)?;
    let page = crate::service::list_active_operations(&state.db).await?;
    Ok(Json(ApiResponse::success(page)))
}

#[utoipa::path(
    get,
    path = "/admin/payments/{id}",
    tag = "Admin",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Payment UUID")),
    responses(
        (status = 200, description = "Payment detail", body = AdminPaymentItem),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin role required", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn get_admin_payment(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<AdminPaymentItem>>, AppError> {
    require_admin(&user)?;
    let item = crate::service::get_admin_payment(&state.db, id).await?;
    Ok(Json(ApiResponse::success(item)))
}

#[utoipa::path(
    put,
    path = "/admin/refunds/{id}/process",
    tag = "Admin",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Payment UUID to process refund for")),
    request_body = ProcessRefundRequest,
    responses(
        (status = 200, description = "Refund marked processed/skipped", body = AdminPaymentItem),
        (status = 400, description = "Invalid action or missing reference", body = ErrorBody),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin role required", body = ErrorBody),
        (status = 404, description = "Payment not found", body = ErrorBody),
        (status = 409, description = "Refund already processed/skipped", body = ErrorBody),
    ),
)]
pub async fn process_refund(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<ProcessRefundRequest>,
) -> Result<Json<ApiResponse<AdminPaymentItem>>, AppError> {
    require_admin(&user)?;
    let item = crate::service::process_refund(&state.db, id, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(item)))
}

#[utoipa::path(
    get,
    path = "/admin/wallet/summary",
    tag = "Admin",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Wallet overview stats", body = WalletSummary),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Admin role required", body = ErrorBody),
    ),
)]
pub async fn admin_wallet_summary(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<WalletSummary>>, AppError> {
    require_admin(&user)?;
    let summary = crate::service::wallet_summary(&state.db).await?;
    Ok(Json(ApiResponse::success(summary)))
}

#[utoipa::path(
    post,
    path = "/assignments/{id}/tip",
    tag = "Payments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Assignment UUID")),
    request_body = AddTipDto,
    responses(
        (status = 200, description = "Tip added — refreshed cost summary", body = CostSummaryResponse),
        (status = 400, description = "Invalid amount or job not completed", body = ErrorBody),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn add_tip(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<uuid::Uuid>,
    Json(req): Json<AddTipDto>,
) -> Result<Json<ApiResponse<CostSummaryResponse>>, AppError> {
    let summary = crate::service::add_tip(&state.db, id, user.user_id, req.amount).await?;
    Ok(Json(ApiResponse::success(summary)))
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
    let job = crate::service::start_job(&state.db, id, user.user_id, lat, lng, &state.http_client)
        .await?;
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
    let job =
        crate::service::get_customer_active_job(&state.db, request_id, user.user_id, &user.role)
            .await?;
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
    user: AuthUser,
    Query(query): Query<AvailableGuardsQuery>,
) -> Result<Json<ApiResponse<Vec<AvailableGuardResponse>>>, AppError> {
    // Only users with an approved customer profile (or admins) can search for guards.
    if user.role != "admin" {
        let has_customer_profile: Option<bool> = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM auth.customer_profiles WHERE user_id = $1 AND approval_status = 'approved')",
        )
        .bind(user.user_id)
        .fetch_one(&state.db)
        .await?;
        if !has_customer_profile.unwrap_or(false) {
            return Err(AppError::Forbidden(
                "Only approved customers can search for available guards".to_string(),
            ));
        }
    }
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

    // Step 2: Validate request_id format and authorize user
    let request_uuid = match uuid::Uuid::parse_str(&request_id) {
        Ok(id) => id,
        Err(_) => {
            let _ = socket
                .send(Message::Text("Invalid request_id format".into()))
                .await;
            return;
        }
    };

    // Authorization: only request owner, assigned guard, or admin can subscribe
    if user.role != "admin" {
        let is_authorized: bool = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM booking.guard_requests
                WHERE id = $1 AND customer_id = $2
                UNION ALL
                SELECT 1 FROM booking.assignments
                WHERE request_id = $1 AND guard_id = $2
            )
            "#,
        )
        .bind(request_uuid)
        .bind(user.user_id)
        .fetch_one(&state.db)
        .await
        .unwrap_or(false);

        if !is_authorized {
            let _ = socket
                .send(Message::Text("Not authorized for this request".into()))
                .await;
            return;
        }
    }

    tracing::info!(
        "Assignment WS subscribing: request_id={}, user_id={}",
        request_id,
        user.user_id
    );

    // Step 3: Subscribe to Redis channel for this request's assignment updates
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

/// Submit an hourly progress report (guard, multipart: hour_number + message + files)
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
    let mut files: Vec<(Vec<u8>, String)> = Vec::new();

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
            // Accept both "photo" (legacy single) and "files" (multi-file)
            "photo" | "files" => {
                if files.len() >= 5 {
                    return Err(AppError::BadRequest(
                        "Maximum 5 files per progress report".to_string(),
                    ));
                }
                let declared_mime = field
                    .content_type()
                    .map(|s| s.to_string())
                    .unwrap_or_default();
                let data = field
                    .bytes()
                    .await
                    .map_err(|e| AppError::BadRequest(format!("Failed to read file: {e}")))?
                    .to_vec();
                // Use magic-byte detected MIME, fallback to declared
                let mime = crate::s3::detect_mime(&data).unwrap_or_else(|| declared_mime.clone());
                crate::s3::validate_upload(&mime, data.len(), &data)?;
                files.push((data, mime));
            }
            _ => {}
        }
    }

    let hour_number =
        hour_number.ok_or_else(|| AppError::BadRequest("hour_number is required".to_string()))?;

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
        files,
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
