use chrono::Utc;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    AssignGuardDto, AssignmentResponse, AssignmentRow, AssignmentStatus, CreateRequestDto,
    GuardRequestResponse, GuardRequestRow, ListRequestsQuery, RequestStatus,
    UpdateAssignmentStatusDto,
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

    let row = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        INSERT INTO booking.guard_requests (customer_id, location_lat, location_lng, address, description, urgency)
        VALUES ($1, $2, $3, $4, $5, $6::urgency_level)
        RETURNING id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
        "#,
    )
    .bind(customer_id)
    .bind(req.location_lat)
    .bind(req.location_lng)
    .bind(&req.address)
    .bind(&req.description)
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
                    SELECT id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
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
                    SELECT id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
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
            SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address, gr.description, gr.status, gr.urgency, gr.created_at, gr.updated_at
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
            SELECT id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
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
        SELECT id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
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
) -> Result<GuardRequestResponse, AppError> {
    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        SELECT id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
        FROM booking.guard_requests
        WHERE id = $1
        FOR UPDATE
        "#,
    )
    .bind(request_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Guard request not found".to_string()))?;

    if existing.customer_id != user_id {
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
        SELECT id, customer_id, location_lat, location_lng, address, description, status, urgency, created_at, updated_at
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

    if existing.guard_id != guard_id {
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
