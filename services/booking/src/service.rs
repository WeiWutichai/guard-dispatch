use chrono::Utc;
use rust_decimal::prelude::ToPrimitive;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    AssignGuardDto, AssignmentResponse, AssignmentRow, AssignmentStatus, AvailableGuardResponse,
    AvailableGuardRow, AvailableGuardsQuery, CreateRequestDto, CreateServiceRateDto, DailyEarning,
    GuardDashboardSummary, GuardEarnings, GuardJobResponse, GuardJobRow, GuardRatingsSummary,
    GuardRequestResponse, GuardRequestRow, ListRequestsQuery, RatingSummaryRow, RequestStatus,
    ReviewItem, ReviewRow, ServiceRate, UpdateAssignmentStatusDto, UpdateServiceRateDto,
    WorkHistoryItem, WorkHistoryResponse, WorkHistoryRow,
};

// =============================================================================
// Create Guard Request
// =============================================================================

pub async fn create_request(
    db: &PgPool,
    customer_id: Uuid,
    req: CreateRequestDto,
) -> Result<GuardRequestResponse, AppError> {
    if req.address.is_empty() {
        return Err(AppError::BadRequest("Address is required".to_string()));
    }

    let urgency_str = serde_json::to_value(&req.urgency)
        .map_err(|e| AppError::Internal(format!("Failed to serialize urgency: {e}")))?
        .as_str()
        .unwrap_or("medium")
        .to_string();

    let price = req
        .offered_price
        .map(|p| rust_decimal::Decimal::try_from(p).unwrap_or_default());

    let row = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        INSERT INTO booking.guard_requests (customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, urgency)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8::urgency_level)
        RETURNING id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
        "#,
    )
    .bind(customer_id)
    .bind(req.location_lat)
    .bind(req.location_lng)
    .bind(&req.address)
    .bind(&req.description)
    .bind(price)
    .bind(&req.special_instructions)
    .bind(&urgency_str)
    .fetch_one(db)
    .await?;

    Ok(GuardRequestResponse::from(row))
}

// =============================================================================
// List Guard Requests
// =============================================================================

pub async fn list_requests(
    db: &PgPool,
    user_id: Uuid,
    role: &str,
    query: ListRequestsQuery,
) -> Result<Vec<GuardRequestResponse>, AppError> {
    let limit = query.limit.unwrap_or(20).min(100);
    let offset = query.offset.unwrap_or(0);

    let rows = if role == "admin" {
        // Admin sees all requests
        match query.status {
            Some(ref status) => {
                let status_str = serde_json::to_value(status)
                    .map_err(|e| AppError::Internal(format!("Failed to serialize status: {e}")))?
                    .as_str()
                    .unwrap_or("pending")
                    .to_string();
                sqlx::query_as::<_, GuardRequestRow>(
                    r#"
                    SELECT id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
                    FROM booking.guard_requests
                    WHERE status = $1::request_status
                    ORDER BY created_at DESC
                    LIMIT $2 OFFSET $3
                    "#,
                )
                .bind(&status_str)
                .bind(limit)
                .bind(offset)
                .fetch_all(db)
                .await?
            }
            None => {
                sqlx::query_as::<_, GuardRequestRow>(
                    r#"
                    SELECT id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
                    FROM booking.guard_requests
                    ORDER BY created_at DESC
                    LIMIT $1 OFFSET $2
                    "#,
                )
                .bind(limit)
                .bind(offset)
                .fetch_all(db)
                .await?
            }
        }
    } else if role == "guard" {
        // Guard sees assigned requests
        sqlx::query_as::<_, GuardRequestRow>(
            r#"
            SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address, gr.description, gr.offered_price, gr.special_instructions, gr.status, gr.urgency, gr.created_at, gr.updated_at
            FROM booking.guard_requests gr
            INNER JOIN booking.assignments a ON a.request_id = gr.id
            WHERE a.guard_id = $1
            ORDER BY gr.created_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(db)
        .await?
    } else {
        // Customer sees their own requests
        sqlx::query_as::<_, GuardRequestRow>(
            r#"
            SELECT id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
            FROM booking.guard_requests
            WHERE customer_id = $1
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(db)
        .await?
    };

    Ok(rows.into_iter().map(GuardRequestResponse::from).collect())
}

// =============================================================================
// Get Guard Request
// =============================================================================

pub async fn get_request(
    db: &PgPool,
    request_id: Uuid,
) -> Result<GuardRequestResponse, AppError> {
    let row = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        SELECT id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
        FROM booking.guard_requests
        WHERE id = $1
        "#,
    )
    .bind(request_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Guard request not found".to_string()))?;

    Ok(GuardRequestResponse::from(row))
}

// =============================================================================
// Cancel Guard Request (with transaction)
// =============================================================================

pub async fn cancel_request(
    db: &PgPool,
    request_id: Uuid,
    user_id: Uuid,
    role: &str,
) -> Result<GuardRequestResponse, AppError> {
    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        SELECT id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
        FROM booking.guard_requests
        WHERE id = $1
        FOR UPDATE
        "#,
    )
    .bind(request_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Guard request not found".to_string()))?;

    // Admin can cancel any request; non-admin can only cancel their own
    if role != "admin" && existing.customer_id != user_id {
        return Err(AppError::Forbidden(
            "You can only cancel your own requests".to_string(),
        ));
    }

    if existing.status == RequestStatus::Completed || existing.status == RequestStatus::Cancelled {
        return Err(AppError::BadRequest(
            "Cannot cancel a completed or already cancelled request".to_string(),
        ));
    }

    let row = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        UPDATE booking.guard_requests
        SET status = 'cancelled'::request_status, updated_at = NOW()
        WHERE id = $1
        RETURNING id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
        "#,
    )
    .bind(request_id)
    .fetch_one(&mut *tx)
    .await?;

    // Also cancel any active assignments
    sqlx::query(
        r#"
        UPDATE booking.assignments
        SET status = 'cancelled'::assignment_status
        WHERE request_id = $1 AND status NOT IN ('completed', 'cancelled')
        "#,
    )
    .bind(request_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(GuardRequestResponse::from(row))
}

// =============================================================================
// Assign Guard (with transaction)
// =============================================================================

pub async fn assign_guard(
    db: &PgPool,
    request_id: Uuid,
    req: AssignGuardDto,
) -> Result<AssignmentResponse, AppError> {
    let mut tx = db.begin().await?;

    // Verify request exists and is pending (lock row)
    let request = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        SELECT id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, created_at, updated_at
        FROM booking.guard_requests
        WHERE id = $1
        FOR UPDATE
        "#,
    )
    .bind(request_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Guard request not found".to_string()))?;

    if request.status != RequestStatus::Pending {
        return Err(AppError::BadRequest(
            "Can only assign guard to pending requests".to_string(),
        ));
    }

    // Verify guard exists and has guard role
    let guard_role: Option<String> = sqlx::query_scalar(
        "SELECT role::text FROM auth.users WHERE id = $1 AND is_active = true",
    )
    .bind(req.guard_id)
    .fetch_optional(&mut *tx)
    .await?;

    match guard_role {
        None => return Err(AppError::NotFound("Guard not found".to_string())),
        Some(role) if role != "guard" => {
            return Err(AppError::BadRequest("User is not a guard".to_string()))
        }
        _ => {}
    }

    // Create assignment
    let assignment = sqlx::query_as::<_, AssignmentRow>(
        r#"
        INSERT INTO booking.assignments (request_id, guard_id)
        VALUES ($1, $2)
        RETURNING id, request_id, guard_id, status, assigned_at, arrived_at, completed_at
        "#,
    )
    .bind(request_id)
    .bind(req.guard_id)
    .fetch_one(&mut *tx)
    .await?;

    // Update request status to assigned
    sqlx::query(
        "UPDATE booking.guard_requests SET status = 'assigned'::request_status, updated_at = NOW() WHERE id = $1",
    )
    .bind(request_id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(AssignmentResponse::from(assignment))
}

// =============================================================================
// Update Assignment Status (with transaction)
// =============================================================================

pub async fn update_assignment_status(
    db: &PgPool,
    assignment_id: Uuid,
    guard_id: Uuid,
    role: &str,
    req: UpdateAssignmentStatusDto,
) -> Result<AssignmentResponse, AppError> {
    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, status, assigned_at, arrived_at, completed_at
        FROM booking.assignments
        WHERE id = $1
        FOR UPDATE
        "#,
    )
    .bind(assignment_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Assignment not found".to_string()))?;

    // Admin can update any assignment; guards can only update their own
    if role != "admin" && existing.guard_id != guard_id {
        return Err(AppError::Forbidden(
            "You can only update your own assignments".to_string(),
        ));
    }

    // Validate status transitions
    let valid_transition = matches!(
        (&existing.status, &req.status),
        (AssignmentStatus::Assigned, AssignmentStatus::EnRoute)
            | (AssignmentStatus::EnRoute, AssignmentStatus::Arrived)
            | (AssignmentStatus::Arrived, AssignmentStatus::Completed)
            | (AssignmentStatus::Assigned, AssignmentStatus::Cancelled)
            | (AssignmentStatus::EnRoute, AssignmentStatus::Cancelled)
    );

    if !valid_transition {
        return Err(AppError::BadRequest(format!(
            "Invalid status transition from {:?} to {:?}",
            existing.status, req.status
        )));
    }

    let now = Utc::now();
    let arrived_at = if req.status == AssignmentStatus::Arrived {
        Some(now)
    } else {
        existing.arrived_at
    };
    let completed_at = if req.status == AssignmentStatus::Completed {
        Some(now)
    } else {
        existing.completed_at
    };

    let status_str = serde_json::to_value(&req.status)
        .map_err(|e| AppError::Internal(format!("Failed to serialize status: {e}")))?
        .as_str()
        .unwrap_or("assigned")
        .to_string();

    let row = sqlx::query_as::<_, AssignmentRow>(
        r#"
        UPDATE booking.assignments
        SET status = $2::assignment_status, arrived_at = $3, completed_at = $4
        WHERE id = $1
        RETURNING id, request_id, guard_id, status, assigned_at, arrived_at, completed_at
        "#,
    )
    .bind(assignment_id)
    .bind(&status_str)
    .bind(arrived_at)
    .bind(completed_at)
    .fetch_one(&mut *tx)
    .await?;

    // Update the guard_request status accordingly
    let request_status = match req.status {
        AssignmentStatus::EnRoute | AssignmentStatus::Arrived => "in_progress",
        AssignmentStatus::Completed => "completed",
        AssignmentStatus::Cancelled => "cancelled",
        _ => "assigned",
    };

    sqlx::query(
        "UPDATE booking.guard_requests SET status = $2::request_status, updated_at = NOW() WHERE id = $1",
    )
    .bind(existing.request_id)
    .bind(request_status)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(AssignmentResponse::from(row))
}

// =============================================================================
// Get Assignments for a Request
// =============================================================================

pub async fn get_assignments(
    db: &PgPool,
    request_id: Uuid,
) -> Result<Vec<AssignmentResponse>, AppError> {
    let rows = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, status, assigned_at, arrived_at, completed_at
        FROM booking.assignments
        WHERE request_id = $1
        ORDER BY assigned_at DESC
        "#,
    )
    .bind(request_id)
    .fetch_all(db)
    .await?;

    Ok(rows.into_iter().map(AssignmentResponse::from).collect())
}

// =============================================================================
// Authorization Helper — Check if guard is assigned to a request
// =============================================================================

pub async fn is_guard_assigned(
    db: &PgPool,
    request_id: Uuid,
    guard_id: Uuid,
) -> Result<bool, AppError> {
    let exists: Option<bool> = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM booking.assignments
            WHERE request_id = $1 AND guard_id = $2
        )
        "#,
    )
    .bind(request_id)
    .bind(guard_id)
    .fetch_one(db)
    .await?;

    Ok(exists.unwrap_or(false))
}

// =============================================================================
// Guard Jobs (enriched with customer name + assignment info)
// =============================================================================

pub async fn get_guard_jobs(
    db: &PgPool,
    guard_id: Uuid,
    status: Option<&str>,
    limit: i64,
    offset: i64,
) -> Result<Vec<GuardJobResponse>, AppError> {
    let rows = match status {
        Some(s) => {
            sqlx::query_as::<_, GuardJobRow>(
                r#"
                SELECT gr.id, gr.customer_id, u.full_name AS customer_name,
                       gr.address, gr.description, gr.special_instructions,
                       gr.status, gr.urgency, gr.offered_price,
                       gr.created_at, gr.updated_at,
                       a.id AS assignment_id, a.status AS assignment_status,
                       a.assigned_at, a.arrived_at, a.completed_at
                FROM booking.guard_requests gr
                INNER JOIN booking.assignments a ON a.request_id = gr.id
                INNER JOIN auth.users u ON u.id = gr.customer_id
                WHERE a.guard_id = $1 AND a.status = $2::assignment_status
                ORDER BY gr.created_at DESC
                LIMIT $3 OFFSET $4
                "#,
            )
            .bind(guard_id)
            .bind(s)
            .bind(limit)
            .bind(offset)
            .fetch_all(db)
            .await?
        }
        None => {
            sqlx::query_as::<_, GuardJobRow>(
                r#"
                SELECT gr.id, gr.customer_id, u.full_name AS customer_name,
                       gr.address, gr.description, gr.special_instructions,
                       gr.status, gr.urgency, gr.offered_price,
                       gr.created_at, gr.updated_at,
                       a.id AS assignment_id, a.status AS assignment_status,
                       a.assigned_at, a.arrived_at, a.completed_at
                FROM booking.guard_requests gr
                INNER JOIN booking.assignments a ON a.request_id = gr.id
                INNER JOIN auth.users u ON u.id = gr.customer_id
                WHERE a.guard_id = $1
                ORDER BY gr.created_at DESC
                LIMIT $2 OFFSET $3
                "#,
            )
            .bind(guard_id)
            .bind(limit)
            .bind(offset)
            .fetch_all(db)
            .await?
        }
    };

    Ok(rows.into_iter().map(GuardJobResponse::from).collect())
}

// =============================================================================
// Guard Dashboard Summary (home tab)
// =============================================================================

pub async fn get_guard_dashboard_summary(
    db: &PgPool,
    guard_id: Uuid,
) -> Result<GuardDashboardSummary, AppError> {
    #[derive(sqlx::FromRow)]
    struct CountRow {
        count: Option<i64>,
    }

    #[derive(sqlx::FromRow)]
    struct SumRow {
        total: Option<rust_decimal::Decimal>,
    }

    let (today_count, today_earnings, week_earnings, last_week_earnings, pending_count, active_job) = tokio::join!(
        // Today's assigned jobs
        sqlx::query_as::<_, CountRow>(
            r#"
            SELECT COUNT(*) AS count
            FROM booking.assignments a
            WHERE a.guard_id = $1 AND DATE(a.assigned_at) = CURRENT_DATE
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        // Today's completed earnings
        sqlx::query_as::<_, SumRow>(
            r#"
            SELECT COALESCE(SUM(gr.offered_price), 0) AS total
            FROM booking.assignments a
            INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
            WHERE a.guard_id = $1 AND a.status = 'completed' AND DATE(a.completed_at) = CURRENT_DATE
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        // This week's completed earnings
        sqlx::query_as::<_, SumRow>(
            r#"
            SELECT COALESCE(SUM(gr.offered_price), 0) AS total
            FROM booking.assignments a
            INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
            WHERE a.guard_id = $1 AND a.status = 'completed' AND a.completed_at >= date_trunc('week', NOW())
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        // Last week's completed earnings (for week-over-week comparison)
        sqlx::query_as::<_, SumRow>(
            r#"
            SELECT COALESCE(SUM(gr.offered_price), 0) AS total
            FROM booking.assignments a
            INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
            WHERE a.guard_id = $1 AND a.status = 'completed'
              AND a.completed_at >= date_trunc('week', NOW()) - INTERVAL '7 days'
              AND a.completed_at < date_trunc('week', NOW())
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        // Pending jobs (assigned but not yet completed/cancelled)
        sqlx::query_as::<_, CountRow>(
            r#"
            SELECT COUNT(*) AS count
            FROM booking.assignments a
            WHERE a.guard_id = $1 AND a.status IN ('assigned', 'en_route', 'arrived')
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        // Active job (assigned/en_route/arrived)
        sqlx::query_as::<_, GuardJobRow>(
            r#"
            SELECT gr.id, gr.customer_id, u.full_name AS customer_name,
                   gr.address, gr.description, gr.special_instructions,
                   gr.status, gr.urgency, gr.offered_price,
                   gr.created_at, gr.updated_at,
                   a.id AS assignment_id, a.status AS assignment_status,
                   a.assigned_at, a.arrived_at, a.completed_at
            FROM booking.guard_requests gr
            INNER JOIN booking.assignments a ON a.request_id = gr.id
            INNER JOIN auth.users u ON u.id = gr.customer_id
            WHERE a.guard_id = $1 AND a.status IN ('assigned', 'en_route', 'arrived')
            ORDER BY a.assigned_at DESC
            LIMIT 1
            "#,
        )
        .bind(guard_id)
        .fetch_optional(db),
    );

    Ok(GuardDashboardSummary {
        today_jobs_count: today_count
            .map_err(AppError::from)?
            .count
            .unwrap_or(0),
        today_earnings: today_earnings
            .map_err(AppError::from)?
            .total
            .and_then(|d| d.to_f64())
            .unwrap_or(0.0),
        week_earnings: week_earnings
            .map_err(AppError::from)?
            .total
            .and_then(|d| d.to_f64())
            .unwrap_or(0.0),
        last_week_earnings: last_week_earnings
            .map_err(AppError::from)?
            .total
            .and_then(|d| d.to_f64())
            .unwrap_or(0.0),
        pending_jobs_count: pending_count
            .map_err(AppError::from)?
            .count
            .unwrap_or(0),
        active_job: active_job
            .map_err(AppError::from)?
            .map(GuardJobResponse::from),
    })
}

// =============================================================================
// Guard Earnings (income tab)
// =============================================================================

pub async fn get_guard_earnings(
    db: &PgPool,
    guard_id: Uuid,
) -> Result<GuardEarnings, AppError> {
    #[derive(sqlx::FromRow)]
    struct EarningSummaryRow {
        total_earned: Option<rust_decimal::Decimal>,
        month_earnings: Option<rust_decimal::Decimal>,
        week_earnings: Option<rust_decimal::Decimal>,
        completed_jobs_count: Option<i64>,
    }

    #[derive(sqlx::FromRow)]
    struct DailyEarningRow {
        date: chrono::NaiveDate,
        amount: Option<rust_decimal::Decimal>,
        jobs_count: Option<i64>,
    }

    let (summary, daily) = tokio::join!(
        sqlx::query_as::<_, EarningSummaryRow>(
            r#"
            SELECT
                COALESCE(SUM(gr.offered_price), 0) AS total_earned,
                COALESCE(SUM(CASE WHEN a.completed_at >= date_trunc('month', NOW()) THEN gr.offered_price ELSE 0 END), 0) AS month_earnings,
                COALESCE(SUM(CASE WHEN a.completed_at >= date_trunc('week', NOW()) THEN gr.offered_price ELSE 0 END), 0) AS week_earnings,
                COUNT(*) AS completed_jobs_count
            FROM booking.assignments a
            INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
            WHERE a.guard_id = $1 AND a.status = 'completed'
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        sqlx::query_as::<_, DailyEarningRow>(
            r#"
            SELECT DATE(a.completed_at) AS date,
                   COALESCE(SUM(gr.offered_price), 0) AS amount,
                   COUNT(*) AS jobs_count
            FROM booking.assignments a
            INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
            WHERE a.guard_id = $1 AND a.status = 'completed'
                  AND a.completed_at >= NOW() - INTERVAL '30 days'
            GROUP BY DATE(a.completed_at)
            ORDER BY date DESC
            "#,
        )
        .bind(guard_id)
        .fetch_all(db),
    );

    let summary = summary.map_err(AppError::from)?;
    let daily = daily.map_err(AppError::from)?;

    Ok(GuardEarnings {
        total_earned: summary
            .total_earned
            .and_then(|d| d.to_f64())
            .unwrap_or(0.0),
        month_earnings: summary
            .month_earnings
            .and_then(|d| d.to_f64())
            .unwrap_or(0.0),
        week_earnings: summary
            .week_earnings
            .and_then(|d| d.to_f64())
            .unwrap_or(0.0),
        completed_jobs_count: summary.completed_jobs_count.unwrap_or(0),
        daily_breakdown: daily
            .into_iter()
            .map(|r| DailyEarning {
                date: r.date,
                amount: r.amount.and_then(|d| d.to_f64()).unwrap_or(0.0),
                jobs_count: r.jobs_count.unwrap_or(0),
            })
            .collect(),
    })
}

// =============================================================================
// Guard Work History (profile → work history screen)
// =============================================================================

pub async fn get_guard_work_history(
    db: &PgPool,
    guard_id: Uuid,
    status: Option<&str>,
    limit: i64,
    offset: i64,
) -> Result<WorkHistoryResponse, AppError> {
    #[derive(sqlx::FromRow)]
    struct StatsRow {
        total_jobs: Option<i64>,
        total_minutes: Option<i64>,
        avg_rating: Option<rust_decimal::Decimal>,
    }

    let (stats, jobs) = tokio::join!(
        sqlx::query_as::<_, StatsRow>(
            r#"
            SELECT
                COUNT(*) AS total_jobs,
                COALESCE(SUM(
                    EXTRACT(EPOCH FROM (a.completed_at - a.arrived_at))::bigint / 60
                ), 0) AS total_minutes,
                (SELECT AVG(r.overall_rating)
                 FROM reviews.guard_reviews r WHERE r.guard_id = $1) AS avg_rating
            FROM booking.assignments a
            WHERE a.guard_id = $1 AND a.status = 'completed'
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        {
            match status {
                Some(s) => {
                    sqlx::query_as::<_, WorkHistoryRow>(
                        r#"
                        SELECT gr.id, a.id AS assignment_id,
                               u.full_name AS customer_name, gr.address, gr.description,
                               gr.offered_price, a.status AS assignment_status,
                               a.assigned_at, a.arrived_at, a.completed_at,
                               EXTRACT(EPOCH FROM (a.completed_at - a.arrived_at))::bigint / 60 AS duration_minutes,
                               rv.overall_rating AS rating
                        FROM booking.guard_requests gr
                        INNER JOIN booking.assignments a ON a.request_id = gr.id
                        INNER JOIN auth.users u ON u.id = gr.customer_id
                        LEFT JOIN reviews.guard_reviews rv ON rv.assignment_id = a.id
                        WHERE a.guard_id = $1 AND a.status = $2::assignment_status
                        ORDER BY a.assigned_at DESC
                        LIMIT $3 OFFSET $4
                        "#,
                    )
                    .bind(guard_id)
                    .bind(s)
                    .bind(limit)
                    .bind(offset)
                    .fetch_all(db)
                }
                None => {
                    sqlx::query_as::<_, WorkHistoryRow>(
                        r#"
                        SELECT gr.id, a.id AS assignment_id,
                               u.full_name AS customer_name, gr.address, gr.description,
                               gr.offered_price, a.status AS assignment_status,
                               a.assigned_at, a.arrived_at, a.completed_at,
                               EXTRACT(EPOCH FROM (a.completed_at - a.arrived_at))::bigint / 60 AS duration_minutes,
                               rv.overall_rating AS rating
                        FROM booking.guard_requests gr
                        INNER JOIN booking.assignments a ON a.request_id = gr.id
                        INNER JOIN auth.users u ON u.id = gr.customer_id
                        LEFT JOIN reviews.guard_reviews rv ON rv.assignment_id = a.id
                        WHERE a.guard_id = $1
                        ORDER BY a.assigned_at DESC
                        LIMIT $2 OFFSET $3
                        "#,
                    )
                    .bind(guard_id)
                    .bind(limit)
                    .bind(offset)
                    .fetch_all(db)
                }
            }
        },
    );

    let stats = stats.map_err(AppError::from)?;
    let jobs = jobs.map_err(AppError::from)?;
    let total_minutes = stats.total_minutes.unwrap_or(0);

    Ok(WorkHistoryResponse {
        total_jobs: stats.total_jobs.unwrap_or(0),
        total_hours: total_minutes as f64 / 60.0,
        avg_rating: stats.avg_rating.and_then(|d| d.to_f64()),
        jobs: jobs.into_iter().map(WorkHistoryItem::from).collect(),
    })
}

// =============================================================================
// Guard Ratings Summary (profile → ratings screen)
// =============================================================================

pub async fn get_guard_ratings(
    db: &PgPool,
    guard_id: Uuid,
) -> Result<GuardRatingsSummary, AppError> {
    let (summary, recent_reviews) = tokio::join!(
        sqlx::query_as::<_, RatingSummaryRow>(
            r#"
            SELECT
                AVG(overall_rating) AS overall_rating,
                COUNT(*) AS total_reviews,
                AVG(punctuality) AS punctuality,
                AVG(professionalism) AS professionalism,
                AVG(communication) AS communication,
                AVG(appearance) AS appearance
            FROM reviews.guard_reviews
            WHERE guard_id = $1
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        sqlx::query_as::<_, ReviewRow>(
            r#"
            SELECT r.id, u.full_name AS customer_name,
                   r.overall_rating, r.review_text, r.created_at
            FROM reviews.guard_reviews r
            INNER JOIN auth.users u ON u.id = r.customer_id
            WHERE r.guard_id = $1
            ORDER BY r.created_at DESC
            LIMIT 20
            "#,
        )
        .bind(guard_id)
        .fetch_all(db),
    );

    let summary = summary.map_err(AppError::from)?;
    let recent_reviews = recent_reviews.map_err(AppError::from)?;

    Ok(GuardRatingsSummary {
        overall_rating: summary.overall_rating.and_then(|d| d.to_f64()),
        total_reviews: summary.total_reviews.unwrap_or(0),
        punctuality: summary.punctuality.and_then(|d| d.to_f64()),
        professionalism: summary.professionalism.and_then(|d| d.to_f64()),
        communication: summary.communication.and_then(|d| d.to_f64()),
        appearance: summary.appearance.and_then(|d| d.to_f64()),
        recent_reviews: recent_reviews
            .into_iter()
            .map(|r| ReviewItem {
                id: r.id,
                customer_name: r.customer_name.unwrap_or_else(|| "-".to_string()),
                overall_rating: r.overall_rating.to_f64().unwrap_or(0.0),
                review_text: r.review_text,
                created_at: r.created_at,
            })
            .collect(),
    })
}

// =============================================================================
// Service Rates (Pricing) — CRUD
// =============================================================================

pub async fn list_service_rates(db: &PgPool) -> Result<Vec<ServiceRate>, AppError> {
    let rows = sqlx::query_as::<_, ServiceRate>(
        r#"
        SELECT id, name, description, min_price, max_price, base_fee, min_hours, notes, is_active, created_at, updated_at
        FROM booking.service_rates
        WHERE is_active = true
        ORDER BY created_at ASC
        LIMIT 100
        "#,
    )
    .fetch_all(db)
    .await?;

    Ok(rows)
}

pub async fn get_service_rate(db: &PgPool, id: Uuid) -> Result<ServiceRate, AppError> {
    let row = sqlx::query_as::<_, ServiceRate>(
        r#"
        SELECT id, name, description, min_price, max_price, base_fee, min_hours, notes, is_active, created_at, updated_at
        FROM booking.service_rates
        WHERE id = $1 AND is_active = true
        "#,
    )
    .bind(id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Service rate not found".to_string()))?;

    Ok(row)
}

fn validate_prices(
    min_price: rust_decimal::Decimal,
    max_price: rust_decimal::Decimal,
    base_fee: rust_decimal::Decimal,
) -> Result<(), AppError> {
    if min_price < rust_decimal::Decimal::ZERO {
        return Err(AppError::BadRequest("Min price cannot be negative".to_string()));
    }
    if max_price < rust_decimal::Decimal::ZERO {
        return Err(AppError::BadRequest("Max price cannot be negative".to_string()));
    }
    if base_fee < rust_decimal::Decimal::ZERO {
        return Err(AppError::BadRequest("Base fee cannot be negative".to_string()));
    }
    if min_price > max_price {
        return Err(AppError::BadRequest(
            "Min price cannot exceed max price".to_string(),
        ));
    }
    Ok(())
}

pub async fn create_service_rate(
    db: &PgPool,
    dto: CreateServiceRateDto,
) -> Result<ServiceRate, AppError> {
    let name = dto.name.trim().to_string();
    if name.is_empty() {
        return Err(AppError::BadRequest("Service name is required".to_string()));
    }
    if name.len() > 200 {
        return Err(AppError::BadRequest("Service name too long (max 200 chars)".to_string()));
    }
    validate_prices(dto.min_price, dto.max_price, dto.base_fee)?;

    let min_hours = dto.min_hours.unwrap_or(6);

    let row = sqlx::query_as::<_, ServiceRate>(
        r#"
        INSERT INTO booking.service_rates (name, description, min_price, max_price, base_fee, min_hours, notes)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id, name, description, min_price, max_price, base_fee, min_hours, notes, is_active, created_at, updated_at
        "#,
    )
    .bind(&name)
    .bind(&dto.description)
    .bind(dto.min_price)
    .bind(dto.max_price)
    .bind(dto.base_fee)
    .bind(min_hours)
    .bind(&dto.notes)
    .fetch_one(db)
    .await?;

    Ok(row)
}

pub async fn update_service_rate(
    db: &PgPool,
    id: Uuid,
    dto: UpdateServiceRateDto,
) -> Result<ServiceRate, AppError> {
    if let Some(ref name) = dto.name {
        if name.trim().is_empty() {
            return Err(AppError::BadRequest("Service name cannot be empty".to_string()));
        }
        if name.len() > 200 {
            return Err(AppError::BadRequest("Service name too long (max 200 chars)".to_string()));
        }
    }

    // Fetch existing to validate merged price values
    let existing = sqlx::query_as::<_, ServiceRate>(
        r#"
        SELECT id, name, description, min_price, max_price, base_fee, min_hours, notes, is_active, created_at, updated_at
        FROM booking.service_rates
        WHERE id = $1 AND is_active = true
        "#,
    )
    .bind(id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Service rate not found".to_string()))?;

    let final_min = dto.min_price.unwrap_or(existing.min_price);
    let final_max = dto.max_price.unwrap_or(existing.max_price);
    let final_base = dto.base_fee.unwrap_or(existing.base_fee);
    validate_prices(final_min, final_max, final_base)?;

    let row = sqlx::query_as::<_, ServiceRate>(
        r#"
        UPDATE booking.service_rates
        SET name        = COALESCE($2, name),
            description = COALESCE($3, description),
            min_price   = COALESCE($4, min_price),
            max_price   = COALESCE($5, max_price),
            base_fee    = COALESCE($6, base_fee),
            min_hours   = COALESCE($7, min_hours),
            notes       = COALESCE($8, notes),
            is_active   = COALESCE($9, is_active),
            updated_at  = NOW()
        WHERE id = $1
        RETURNING id, name, description, min_price, max_price, base_fee, min_hours, notes, is_active, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(dto.name.as_deref().map(str::trim))
    .bind(&dto.description)
    .bind(dto.min_price)
    .bind(dto.max_price)
    .bind(dto.base_fee)
    .bind(dto.min_hours)
    .bind(&dto.notes)
    .bind(dto.is_active)
    .fetch_one(db)
    .await?;

    Ok(row)
}

pub async fn delete_service_rate(db: &PgPool, id: Uuid) -> Result<(), AppError> {
    // Soft delete: set is_active = false
    let result = sqlx::query(
        "UPDATE booking.service_rates SET is_active = false, updated_at = NOW() WHERE id = $1 AND is_active = true",
    )
    .bind(id)
    .execute(db)
    .await?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Service rate not found".to_string()));
    }

    Ok(())
}

// =============================================================================
// Available Guards (customer-facing guard discovery)
// =============================================================================

pub async fn list_available_guards(
    db: &PgPool,
    query: AvailableGuardsQuery,
) -> Result<Vec<AvailableGuardResponse>, AppError> {
    let radius_km = query.radius_km.unwrap_or(50.0).min(200.0);
    let limit = query.limit.unwrap_or(20).min(50);
    let offset = query.offset.unwrap_or(0);

    let rows = sqlx::query_as::<_, AvailableGuardRow>(
        r#"
        SELECT
            u.id,
            u.full_name,
            u.avatar_url,
            gp.years_of_experience AS experience_years,
            gl.lat,
            gl.lng,
            (6371.0 * acos(
                LEAST(1.0, GREATEST(-1.0,
                    cos(radians($1::float8)) * cos(radians(gl.lat)) *
                    cos(radians(gl.lng) - radians($2::float8)) +
                    sin(radians($1::float8)) * sin(radians(gl.lat))
                ))
            )) AS distance_km,
            gl.recorded_at AS last_seen_at,
            COALESCE(jc.cnt, 0) AS completed_jobs
        FROM auth.users u
        INNER JOIN tracking.guard_locations gl ON gl.guard_id = u.id
        LEFT JOIN auth.guard_profiles gp ON gp.user_id = u.id
        LEFT JOIN (
            SELECT a.guard_id, COUNT(*) AS cnt
            FROM booking.assignments a
            WHERE a.status = 'completed'
            GROUP BY a.guard_id
        ) jc ON jc.guard_id = u.id
        WHERE u.role = 'guard'
          AND u.is_active = true
          AND u.approval_status = 'approved'
          AND gl.recorded_at > NOW() - INTERVAL '30 minutes'
          AND (6371.0 * acos(
              LEAST(1.0, GREATEST(-1.0,
                  cos(radians($1::float8)) * cos(radians(gl.lat)) *
                  cos(radians(gl.lng) - radians($2::float8)) +
                  sin(radians($1::float8)) * sin(radians(gl.lat))
              ))
          )) <= $3::float8
        ORDER BY distance_km ASC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(query.lat)
    .bind(query.lng)
    .bind(radius_km)
    .bind(limit)
    .bind(offset)
    .fetch_all(db)
    .await?;

    Ok(rows.into_iter().map(AvailableGuardResponse::from).collect())
}
