use chrono::Utc;
use redis::AsyncCommands;
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    AcceptDeclineDto, ActiveJobResponse, AdminReviewResponse, AdminReviewRow, AdminReviewStats,
    AdminReviewsQuery, AssignGuardDto, AssignmentResponse, AssignmentRow, AssignmentStatus,
    AvailableGuardResponse, AvailableGuardRow, AvailableGuardsQuery, CostSummaryResponse,
    CreatePaymentDto, CreateRequestDto, CreateServiceRateDto, DailyEarning, GuardDashboardSummary,
    GuardEarnings, GuardJobResponse, GuardJobRow, GuardRatingsSummary, GuardRequestResponse,
    GuardRequestRow, ListRequestsQuery, PaginatedAdminReviews, PaymentResponse, PaymentRow,
    ProgressReportMediaItem, ProgressReportMediaRow, ProgressReportResponse, ProgressReportRow,
    RatingSummaryRow, RequestStatus, ReviewItem, ReviewRow, ServiceRate, UpdateAssignmentStatusDto,
    UpdateServiceRateDto, WorkHistoryItem, WorkHistoryResponse, WorkHistoryRow,
};

/// Validate and sanitise optional lat/lng. Returns (None, None) if invalid or (0,0).
fn sanitize_coords(lat: Option<f64>, lng: Option<f64>) -> (Option<f64>, Option<f64>) {
    match (lat, lng) {
        (Some(la), Some(lo))
            if (-90.0..=90.0).contains(&la)
                && (-180.0..=180.0).contains(&lo)
                && !(la == 0.0 && lo == 0.0) =>
        {
            (Some(la), Some(lo))
        }
        _ => (None, None),
    }
}

/// Reverse geocode lat/lng to a place name via Nominatim (fire-and-forget style).
/// Returns a short place name or None if geocoding fails.
async fn reverse_geocode(http: &reqwest::Client, lat: f64, lng: f64) -> Option<String> {
    let resp = http
        .get("https://nominatim.openstreetmap.org/reverse")
        .query(&[
            ("lat", lat.to_string()),
            ("lon", lng.to_string()),
            ("format", "json".to_string()),
            ("zoom", "16".to_string()),
            ("accept-language", "th,en".to_string()),
        ])
        .header("User-Agent", "P-GuardApp/1.0")
        .send()
        .await
        .ok()?;

    let data: serde_json::Value = resp.json().await.ok()?;

    // Try short display: road + suburb/district
    let addr = data.get("address")?;
    let road = addr.get("road").and_then(|v| v.as_str());
    let suburb = addr
        .get("suburb")
        .or_else(|| addr.get("district"))
        .or_else(|| addr.get("subdistrict"))
        .and_then(|v| v.as_str());

    match (road, suburb) {
        (Some(r), Some(s)) => Some(format!("{}, {}", r, s)),
        (Some(r), None) => Some(r.to_string()),
        (None, Some(s)) => Some(s.to_string()),
        (None, None) => data.get("display_name").and_then(|v| v.as_str()).map(|s| {
            // Truncate long display_name to first 2 parts
            let parts: Vec<&str> = s.splitn(3, ", ").collect();
            if parts.len() >= 2 {
                format!("{}, {}", parts[0], parts[1])
            } else {
                s.to_string()
            }
        }),
    }
}

/// Insert a notification log entry (fire-and-forget via tokio::spawn).
/// Since booking and notification share the same PostgreSQL instance,
/// we INSERT directly — no HTTP overhead, no FCM push (future enhancement).
/// Fire-and-forget notification creation + FCM push delivery.
///
/// 1. INSERT into notification.notification_logs (shared PostgreSQL)
/// 2. POST to notification-service internal API to trigger FCM push
///
/// Step 2 calls `POST http://rust-notification:3004/notifications/send`
/// which is the admin send_notification endpoint — but using an internal
/// service-to-service call (no JWT needed since it's on the Docker
/// internal network). The notification-service handles FCM OAuth + push.
pub fn spawn_notification(
    db: PgPool,
    user_id: Uuid,
    title: String,
    body: String,
    notification_type: &'static str,
    payload: Option<serde_json::Value>,
) {
    tokio::spawn(async move {
        // 1. Insert notification log (always — even if push fails)
        let result = sqlx::query(
            r#"
            INSERT INTO notification.notification_logs (user_id, title, body, notification_type, payload)
            VALUES ($1, $2, $3, $4::notification_type, $5)
            "#,
        )
        .bind(user_id)
        .bind(&title)
        .bind(&body)
        .bind(notification_type)
        .bind(&payload)
        .execute(&db)
        .await;

        if let Err(e) = result {
            tracing::warn!("Failed to insert notification: {e}");
        }

        // 2. Trigger FCM push via notification-service internal API.
        // The send_notification handler looks up FCM tokens + sends push.
        // Fire-and-forget: if notification-service is down, the DB log
        // persists and the user sees it on next app open via the REST API.
        let push_body = serde_json::json!({
            "user_id": user_id.to_string(),
            "title": title,
            "body": body,
            "notification_type": notification_type,
            "payload": payload,
        });

        let client = reqwest::Client::new();
        match client
            .post("http://rust-notification:3004/internal/push")
            .header("X-Internal-Service", "booking-service")
            .json(&push_body)
            .send()
            .await
        {
            Ok(resp) if !resp.status().is_success() => {
                tracing::warn!(
                    "notification-service push returned status={}",
                    resp.status()
                );
            }
            Err(e) => {
                tracing::warn!("Failed to call notification-service for push: {e}");
            }
            _ => {}
        }
    });
}

/// Publish an assignment status change event via Redis pub/sub (fire-and-forget).
pub fn publish_assignment_event(
    redis_conn: &redis::aio::MultiplexedConnection,
    request_id: Uuid,
    assignment_id: Uuid,
    new_status: &str,
) {
    let mut conn = redis_conn.clone();
    let channel = format!("assignment_status:{request_id}");
    let payload = serde_json::json!({
        "type": "status_changed",
        "assignment_id": assignment_id.to_string(),
        "request_id": request_id.to_string(),
        "status": new_status,
        "timestamp": Utc::now().to_rfc3339(),
    })
    .to_string();

    tokio::spawn(async move {
        let result: Result<(), redis::RedisError> = conn.publish(channel, payload).await;
        if let Err(e) = result {
            tracing::warn!("Failed to publish assignment status event: {e}");
        }
    });
}

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

    // Validate coordinates
    if !(-90.0..=90.0).contains(&req.location_lat) {
        return Err(AppError::BadRequest(
            "Latitude must be between -90 and 90".to_string(),
        ));
    }
    if !(-180.0..=180.0).contains(&req.location_lng) {
        return Err(AppError::BadRequest(
            "Longitude must be between -180 and 180".to_string(),
        ));
    }
    if req.location_lat == 0.0 && req.location_lng == 0.0 {
        return Err(AppError::BadRequest(
            "Invalid coordinates (0,0)".to_string(),
        ));
    }

    // Validate booked_hours
    if let Some(hours) = req.booked_hours {
        if !(1..=720).contains(&hours) {
            return Err(AppError::BadRequest(
                "Booked hours must be between 1 and 720".to_string(),
            ));
        }
    }

    // Validate guard_count — matches the DB CHECK on booking.guard_requests.
    if !(1..=20).contains(&req.guard_count) {
        return Err(AppError::BadRequest(
            "Guard count must be between 1 and 20".to_string(),
        ));
    }

    // Validate offered_price
    if let Some(price) = req.offered_price {
        if price < 0.0 {
            return Err(AppError::BadRequest(
                "Offered price cannot be negative".to_string(),
            ));
        }
    }

    let urgency_str = serde_json::to_value(&req.urgency)
        .map_err(|e| AppError::Internal(format!("Failed to serialize urgency: {e}")))?
        .as_str()
        .unwrap_or("medium")
        .to_string();

    let price = req
        .offered_price
        .map(|p| {
            rust_decimal::Decimal::try_from(p)
                .map_err(|_| AppError::BadRequest("Invalid offered price value".to_string()))
        })
        .transpose()?;

    let row = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        INSERT INTO booking.guard_requests (customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, urgency, booked_hours, guard_count)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8::urgency_level, $9, $10)
        RETURNING id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, booked_hours, guard_count, NULL::assignment_status AS assignment_status, created_at, updated_at
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
    .bind(req.booked_hours)
    .bind(req.guard_count)
    .fetch_one(db)
    .await?;

    // Removed: booking_created notification — customer knows they just booked

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
                    SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address,
                           gr.description, gr.offered_price, gr.special_instructions, gr.status,
                           gr.urgency, gr.booked_hours, gr.guard_count, la.assignment_status, gr.created_at, gr.updated_at
                    FROM booking.guard_requests gr
                    LEFT JOIN LATERAL (
                        SELECT a.status AS assignment_status
                        FROM booking.assignments a
                        WHERE a.request_id = gr.id AND a.status != 'declined'
                        ORDER BY a.assigned_at DESC LIMIT 1
                    ) la ON true
                    WHERE gr.status = $1::request_status
                    ORDER BY gr.created_at DESC
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
                    SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address,
                           gr.description, gr.offered_price, gr.special_instructions, gr.status,
                           gr.urgency, gr.booked_hours, gr.guard_count, la.assignment_status, gr.created_at, gr.updated_at
                    FROM booking.guard_requests gr
                    LEFT JOIN LATERAL (
                        SELECT a.status AS assignment_status
                        FROM booking.assignments a
                        WHERE a.request_id = gr.id AND a.status != 'declined'
                        ORDER BY a.assigned_at DESC LIMIT 1
                    ) la ON true
                    ORDER BY gr.created_at DESC
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
            SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address,
                   gr.description, gr.offered_price, gr.special_instructions, gr.status,
                   gr.urgency, gr.booked_hours, gr.guard_count, a.status AS assignment_status,
                   gr.created_at, gr.updated_at
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
            SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address,
                   gr.description, gr.offered_price, gr.special_instructions, gr.status,
                   gr.urgency, gr.booked_hours, gr.guard_count, la.assignment_status, gr.created_at, gr.updated_at
            FROM booking.guard_requests gr
            LEFT JOIN LATERAL (
                SELECT a.status AS assignment_status
                FROM booking.assignments a
                WHERE a.request_id = gr.id AND a.status != 'declined'
                ORDER BY a.assigned_at DESC LIMIT 1
            ) la ON true
            WHERE gr.customer_id = $1
            ORDER BY gr.created_at DESC
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

pub async fn get_request(db: &PgPool, request_id: Uuid) -> Result<GuardRequestResponse, AppError> {
    let row = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address,
               gr.description, gr.offered_price, gr.special_instructions, gr.status,
               gr.urgency, gr.booked_hours, gr.guard_count, la.assignment_status, gr.created_at, gr.updated_at
        FROM booking.guard_requests gr
        LEFT JOIN LATERAL (
            SELECT a.status AS assignment_status
            FROM booking.assignments a
            WHERE a.request_id = gr.id AND a.status != 'declined'
            ORDER BY a.assigned_at DESC LIMIT 1
        ) la ON true
        WHERE gr.id = $1
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
        SELECT gr.id, gr.customer_id, gr.location_lat, gr.location_lng, gr.address,
               gr.description, gr.offered_price, gr.special_instructions, gr.status,
               gr.urgency, gr.booked_hours, gr.guard_count, NULL::assignment_status AS assignment_status,
               gr.created_at, gr.updated_at
        FROM booking.guard_requests gr
        WHERE gr.id = $1
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
        RETURNING id, customer_id, location_lat, location_lng, address, description, offered_price, special_instructions, status, urgency, booked_hours, guard_count, NULL::assignment_status AS assignment_status, created_at, updated_at
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
        SELECT id, customer_id, location_lat, location_lng, address, description, offered_price,
               special_instructions, status, urgency, booked_hours, guard_count,
               NULL::assignment_status AS assignment_status, created_at, updated_at
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
    let guard_role: Option<String> =
        sqlx::query_scalar("SELECT role::text FROM auth.users WHERE id = $1 AND is_active = true")
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

    // Create assignment with pending_acceptance (guard must accept first)
    let assignment = sqlx::query_as::<_, AssignmentRow>(
        r#"
        INSERT INTO booking.assignments (request_id, guard_id, status)
        VALUES ($1, $2, 'pending_acceptance'::assignment_status)
        RETURNING id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               NULL::timestamptz AS en_route_at, NULL::float8 AS en_route_lat, NULL::float8 AS en_route_lng, NULL::float8 AS arrived_lat, NULL::float8 AS arrived_lng, NULL::TEXT AS en_route_place, NULL::TEXT AS arrived_place,
               NULL::float8 AS started_lat, NULL::float8 AS started_lng, NULL::TEXT AS started_place,
               NULL::float8 AS completion_lat, NULL::float8 AS completion_lng, NULL::TEXT AS completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
        "#,
    )
    .bind(request_id)
    .bind(req.guard_id)
    .fetch_one(&mut *tx)
    .await?;

    // Do NOT update request status yet — wait for guard to accept

    tx.commit().await?;

    // Notify guard: new job assigned
    spawn_notification(
        db.clone(),
        req.guard_id,
        "งานใหม่ที่ได้รับ".to_string(),
        format!("คุณได้รับมอบหมายงานใหม่ที่ {}", request.address),
        "guard_assigned",
        Some(serde_json::json!({
            "request_id": request_id.to_string(),
            "assignment_id": assignment.id.to_string(),
            "target_role": "guard",
        })),
    );

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
    redis_conn: &redis::aio::MultiplexedConnection,
    http_client: &reqwest::Client,
) -> Result<AssignmentResponse, AppError> {
    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
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
        (AssignmentStatus::Accepted, AssignmentStatus::EnRoute)
            | (AssignmentStatus::Assigned, AssignmentStatus::EnRoute)
            | (AssignmentStatus::EnRoute, AssignmentStatus::Arrived)
            | (
                AssignmentStatus::Arrived,
                AssignmentStatus::PendingCompletion
            )
            | (AssignmentStatus::Assigned, AssignmentStatus::Cancelled)
            | (AssignmentStatus::Accepted, AssignmentStatus::Cancelled)
            | (
                AssignmentStatus::AwaitingPayment,
                AssignmentStatus::Cancelled
            )
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
    let completed_at = existing.completed_at;
    let completion_requested_at = if req.status == AssignmentStatus::PendingCompletion {
        Some(now)
    } else {
        existing.completion_requested_at
    };

    // Validate incoming coordinates
    let (req_lat, req_lng) = sanitize_coords(req.lat, req.lng);

    // Check-in location: capture GPS at en_route and arrived transitions
    let en_route_at = if req.status == AssignmentStatus::EnRoute {
        Some(now)
    } else {
        existing.en_route_at
    };
    let en_route_lat = if req.status == AssignmentStatus::EnRoute {
        req_lat
    } else {
        existing.en_route_lat
    };
    let en_route_lng = if req.status == AssignmentStatus::EnRoute {
        req_lng
    } else {
        existing.en_route_lng
    };
    let arrived_lat = if req.status == AssignmentStatus::Arrived {
        req_lat
    } else {
        existing.arrived_lat
    };
    let arrived_lng = if req.status == AssignmentStatus::Arrived {
        req_lng
    } else {
        existing.arrived_lng
    };

    // Capture GPS at completion transition
    let completion_lat = if req.status == AssignmentStatus::PendingCompletion {
        req_lat
    } else {
        existing.completion_lat
    };
    let completion_lng = if req.status == AssignmentStatus::PendingCompletion {
        req_lng
    } else {
        existing.completion_lng
    };

    // Reverse geocode to get place name for check-in location
    let (en_route_place, arrived_place, completion_place) = match req.status {
        AssignmentStatus::EnRoute => {
            let place = if let (Some(lat), Some(lng)) = (req_lat, req_lng) {
                reverse_geocode(http_client, lat, lng).await
            } else {
                None
            };
            (
                place,
                existing.arrived_place.clone(),
                existing.completion_place.clone(),
            )
        }
        AssignmentStatus::Arrived => {
            let place = if let (Some(lat), Some(lng)) = (req_lat, req_lng) {
                reverse_geocode(http_client, lat, lng).await
            } else {
                None
            };
            (
                existing.en_route_place.clone(),
                place,
                existing.completion_place.clone(),
            )
        }
        AssignmentStatus::PendingCompletion => {
            let place = if let (Some(lat), Some(lng)) = (req_lat, req_lng) {
                reverse_geocode(http_client, lat, lng).await
            } else {
                None
            };
            (
                existing.en_route_place.clone(),
                existing.arrived_place.clone(),
                place,
            )
        }
        _ => (
            existing.en_route_place.clone(),
            existing.arrived_place.clone(),
            existing.completion_place.clone(),
        ),
    };

    let status_str = serde_json::to_value(&req.status)
        .map_err(|e| AppError::Internal(format!("Failed to serialize status: {e}")))?
        .as_str()
        .unwrap_or("assigned")
        .to_string();

    let row = sqlx::query_as::<_, AssignmentRow>(
        r#"
        UPDATE booking.assignments
        SET status = $2::assignment_status, arrived_at = $3, completed_at = $4, completion_requested_at = $5,
            en_route_at = $6, en_route_lat = $7, en_route_lng = $8, arrived_lat = $9, arrived_lng = $10,
            en_route_place = $11, arrived_place = $12,
            completion_lat = $13, completion_lng = $14, completion_place = $15
        WHERE id = $1
        RETURNING id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
        "#,
    )
    .bind(assignment_id)
    .bind(&status_str)
    .bind(arrived_at)
    .bind(completed_at)
    .bind(completion_requested_at)
    .bind(en_route_at)
    .bind(en_route_lat)
    .bind(en_route_lng)
    .bind(arrived_lat)
    .bind(arrived_lng)
    .bind(&en_route_place)
    .bind(&arrived_place)
    .bind(completion_lat)
    .bind(completion_lng)
    .bind(&completion_place)
    .fetch_one(&mut *tx)
    .await?;

    // Update the guard_request status accordingly
    let request_status = match req.status {
        AssignmentStatus::EnRoute
        | AssignmentStatus::Arrived
        | AssignmentStatus::PendingCompletion => "in_progress",
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

    // Publish real-time event (fire-and-forget)
    let status_str_for_event = serde_json::to_value(&req.status)
        .ok()
        .and_then(|v| v.as_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "unknown".to_string());
    publish_assignment_event(
        redis_conn,
        existing.request_id,
        assignment_id,
        &status_str_for_event,
    );

    // Notify customer for status changes they care about
    if matches!(
        req.status,
        AssignmentStatus::EnRoute | AssignmentStatus::Arrived | AssignmentStatus::PendingCompletion
    ) {
        let db_clone = db.clone();
        let req_id = existing.request_id;
        let a_id = assignment_id;
        let status = req.status.clone();
        tokio::spawn(async move {
            let cid: Option<Uuid> =
                sqlx::query_scalar("SELECT customer_id FROM booking.guard_requests WHERE id = $1")
                    .bind(req_id)
                    .fetch_optional(&db_clone)
                    .await
                    .ok()
                    .flatten();

            if let Some(customer_id) = cid {
                let (title, body, ntype) = match status {
                    AssignmentStatus::EnRoute => (
                        "เจ้าหน้าที่กำลังเดินทาง",
                        "เจ้าหน้าที่ รปภ. กำลังเดินทางมาหาคุณ",
                        "guard_en_route",
                    ),
                    AssignmentStatus::Arrived => {
                        ("เจ้าหน้าที่ถึงแล้ว", "เจ้าหน้าที่ รปภ. ถึงจุดหมายแล้ว", "guard_arrived")
                    }
                    AssignmentStatus::PendingCompletion => (
                        "เจ้าหน้าที่แจ้งงานเสร็จ",
                        "เจ้าหน้าที่ รปภ. แจ้งว่างานเสร็จสิ้น กรุณาตรวจสอบ",
                        "booking_completed",
                    ),
                    _ => return,
                };
                spawn_notification(
                    db_clone,
                    customer_id,
                    title.to_string(),
                    body.to_string(),
                    ntype,
                    Some(serde_json::json!({
                        "request_id": req_id.to_string(),
                        "assignment_id": a_id.to_string(),
                        "target_role": "customer",
                    })),
                );
            }
        });
    }

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
        SELECT a.id, a.request_id, a.guard_id,
               u.full_name AS guard_name,
               a.status, a.assigned_at, a.arrived_at, a.completed_at, a.started_at, a.completion_requested_at,
               a.en_route_at, a.en_route_lat, a.en_route_lng, a.arrived_lat, a.arrived_lng, a.en_route_place, a.arrived_place,
               a.started_lat, a.started_lng, a.started_place, a.completion_lat, a.completion_lng, a.completion_place,
               r.overall_rating::float8 AS review_overall_rating,
               r.punctuality::float8 AS review_punctuality,
               r.professionalism::float8 AS review_professionalism,
               r.communication::float8 AS review_communication,
               r.appearance::float8 AS review_appearance,
               r.review_text AS review_text
        FROM booking.assignments a
        LEFT JOIN auth.users u ON u.id = a.guard_id
        LEFT JOIN reviews.guard_reviews r ON r.assignment_id = a.id
        WHERE a.request_id = $1
        ORDER BY a.assigned_at DESC
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
                SELECT gr.id, gr.customer_id, COALESCE(cp.full_name, u.full_name) AS customer_name,
                       COALESCE(cp.contact_phone, u.phone) AS customer_phone,
                       gr.location_lat, gr.location_lng,
                       gr.address, gr.description, gr.special_instructions,
                       gr.status, gr.urgency, gr.offered_price, gr.booked_hours,
                       gr.created_at, gr.updated_at,
                       a.id AS assignment_id, a.status AS assignment_status,
                       a.assigned_at, a.arrived_at, a.completed_at, a.started_at,
                       a.en_route_at, a.en_route_lat, a.en_route_lng, a.arrived_lat, a.arrived_lng, a.en_route_place, a.arrived_place,
                       a.started_lat, a.started_lng, a.started_place, a.completion_lat, a.completion_lng, a.completion_place,
                       rv.overall_rating::float8 AS review_overall_rating,
                       rv.punctuality::float8 AS review_punctuality,
                       rv.professionalism::float8 AS review_professionalism,
                       rv.communication::float8 AS review_communication,
                       rv.appearance::float8 AS review_appearance,
                       rv.review_text AS review_text
                FROM booking.guard_requests gr
                INNER JOIN booking.assignments a ON a.request_id = gr.id
                INNER JOIN auth.users u ON u.id = gr.customer_id
                LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
                LEFT JOIN reviews.guard_reviews rv ON rv.assignment_id = a.id
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
                SELECT gr.id, gr.customer_id, COALESCE(cp.full_name, u.full_name) AS customer_name,
                       COALESCE(cp.contact_phone, u.phone) AS customer_phone,
                       gr.location_lat, gr.location_lng,
                       gr.address, gr.description, gr.special_instructions,
                       gr.status, gr.urgency, gr.offered_price, gr.booked_hours,
                       gr.created_at, gr.updated_at,
                       a.id AS assignment_id, a.status AS assignment_status,
                       a.assigned_at, a.arrived_at, a.completed_at, a.started_at,
                       a.en_route_at, a.en_route_lat, a.en_route_lng, a.arrived_lat, a.arrived_lng, a.en_route_place, a.arrived_place,
                       a.started_lat, a.started_lng, a.started_place, a.completion_lat, a.completion_lng, a.completion_place,
                       rv.overall_rating::float8 AS review_overall_rating,
                       rv.punctuality::float8 AS review_punctuality,
                       rv.professionalism::float8 AS review_professionalism,
                       rv.communication::float8 AS review_communication,
                       rv.appearance::float8 AS review_appearance,
                       rv.review_text AS review_text
                FROM booking.guard_requests gr
                INNER JOIN booking.assignments a ON a.request_id = gr.id
                INNER JOIN auth.users u ON u.id = gr.customer_id
                LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
                LEFT JOIN reviews.guard_reviews rv ON rv.assignment_id = a.id
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

    #[derive(sqlx::FromRow)]
    struct CountRow2 {
        count: Option<i64>,
    }

    let (today_count, today_earnings, week_earnings, last_week_earnings, pending_count, pending_acceptance_count, active_job) = tokio::join!(
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
        // Pending acceptance count (jobs waiting for guard to accept)
        sqlx::query_as::<_, CountRow2>(
            r#"
            SELECT COUNT(*) AS count
            FROM booking.assignments a
            WHERE a.guard_id = $1 AND a.status = 'pending_acceptance'
            "#,
        )
        .bind(guard_id)
        .fetch_one(db),
        // Active job (accepted/assigned/en_route/arrived)
        sqlx::query_as::<_, GuardJobRow>(
            r#"
            SELECT gr.id, gr.customer_id, COALESCE(cp.full_name, u.full_name) AS customer_name,
                   COALESCE(cp.contact_phone, u.phone) AS customer_phone,
                   gr.location_lat, gr.location_lng,
                   gr.address, gr.description, gr.special_instructions,
                   gr.status, gr.urgency, gr.offered_price, gr.booked_hours,
                   gr.created_at, gr.updated_at,
                   a.id AS assignment_id, a.status AS assignment_status,
                   a.assigned_at, a.arrived_at, a.completed_at, a.started_at,
                   a.en_route_at, a.en_route_lat, a.en_route_lng, a.arrived_lat, a.arrived_lng, a.en_route_place, a.arrived_place,
                   a.started_lat, a.started_lng, a.started_place, a.completion_lat, a.completion_lng, a.completion_place,
                   NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality,
                   NULL::float8 AS review_professionalism, NULL::float8 AS review_communication,
                   NULL::float8 AS review_appearance, NULL::TEXT AS review_text
            FROM booking.guard_requests gr
            INNER JOIN booking.assignments a ON a.request_id = gr.id
            INNER JOIN auth.users u ON u.id = gr.customer_id
            LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
            WHERE a.guard_id = $1 AND a.status IN ('accepted', 'assigned', 'awaiting_payment', 'en_route', 'arrived', 'pending_completion')
            ORDER BY a.assigned_at DESC
            LIMIT 1
            "#,
        )
        .bind(guard_id)
        .fetch_optional(db),
    );

    Ok(GuardDashboardSummary {
        today_jobs_count: today_count.map_err(AppError::from)?.count.unwrap_or(0),
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
        pending_jobs_count: pending_count.map_err(AppError::from)?.count.unwrap_or(0),
        pending_acceptance_count: pending_acceptance_count
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

pub async fn get_guard_earnings(db: &PgPool, guard_id: Uuid) -> Result<GuardEarnings, AppError> {
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
        total_earned: summary.total_earned.and_then(|d| d.to_f64()).unwrap_or(0.0),
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
                               COALESCE(cp.full_name, u.full_name) AS customer_name, gr.address, gr.description,
                               gr.offered_price, a.status AS assignment_status,
                               a.assigned_at, a.arrived_at, a.completed_at,
                               EXTRACT(EPOCH FROM (a.completed_at - a.arrived_at))::bigint / 60 AS duration_minutes,
                               rv.overall_rating AS rating
                        FROM booking.guard_requests gr
                        INNER JOIN booking.assignments a ON a.request_id = gr.id
                        INNER JOIN auth.users u ON u.id = gr.customer_id
                        LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
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
                               COALESCE(cp.full_name, u.full_name) AS customer_name, gr.address, gr.description,
                               gr.offered_price, a.status AS assignment_status,
                               a.assigned_at, a.arrived_at, a.completed_at,
                               EXTRACT(EPOCH FROM (a.completed_at - a.arrived_at))::bigint / 60 AS duration_minutes,
                               rv.overall_rating AS rating
                        FROM booking.guard_requests gr
                        INNER JOIN booking.assignments a ON a.request_id = gr.id
                        INNER JOIN auth.users u ON u.id = gr.customer_id
                        LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
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
            SELECT r.id, COALESCE(cp.full_name, u.full_name) AS customer_name,
                   r.overall_rating, r.review_text, r.created_at
            FROM reviews.guard_reviews r
            INNER JOIN auth.users u ON u.id = r.customer_id
            LEFT JOIN auth.customer_profiles cp ON cp.user_id = r.customer_id
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
// Admin Reviews — list across all guards + toggle visibility
// =============================================================================

pub async fn list_admin_reviews(
    db: &PgPool,
    query: AdminReviewsQuery,
) -> Result<PaginatedAdminReviews, AppError> {
    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let offset = query.offset.unwrap_or(0).max(0);

    // Build dynamic WHERE on a single SQL string with bound params.
    // Using sqlx::query_as::<_, AdminReviewRow> with QueryBuilder would be
    // cleaner, but we already use this pattern elsewhere in the file.
    let mut where_clauses: Vec<String> = Vec::new();
    let mut bind_idx = 0;

    if query.guard_id.is_some() {
        bind_idx += 1;
        where_clauses.push(format!("r.guard_id = ${bind_idx}"));
    }
    if query.rating.is_some() {
        bind_idx += 1;
        where_clauses.push(format!("FLOOR(r.overall_rating) = ${bind_idx}"));
    }
    if query.is_visible.is_some() {
        bind_idx += 1;
        where_clauses.push(format!("r.is_visible = ${bind_idx}"));
    }
    if query
        .search
        .as_deref()
        .is_some_and(|s| !s.trim().is_empty())
    {
        bind_idx += 1;
        where_clauses.push(format!(
            "(COALESCE(cp.full_name, cu.full_name) ILIKE ${bind_idx} \
             OR gu.full_name ILIKE ${bind_idx} \
             OR r.review_text ILIKE ${bind_idx})"
        ));
    }

    let where_sql = if where_clauses.is_empty() {
        String::new()
    } else {
        format!("WHERE {}", where_clauses.join(" AND "))
    };

    let limit_idx = bind_idx + 1;
    let offset_idx = bind_idx + 2;

    let list_sql = format!(
        r#"
        SELECT
            r.id, r.assignment_id, r.request_id,
            r.customer_id,
            COALESCE(cp.full_name, cu.full_name) AS customer_name,
            r.guard_id,
            gu.full_name AS guard_name,
            r.overall_rating,
            r.punctuality, r.professionalism, r.communication, r.appearance,
            r.review_text,
            req.address,
            r.is_visible,
            r.created_at
        FROM reviews.guard_reviews r
        INNER JOIN auth.users cu ON cu.id = r.customer_id
        LEFT JOIN auth.customer_profiles cp ON cp.user_id = r.customer_id
        INNER JOIN auth.users gu ON gu.id = r.guard_id
        LEFT JOIN booking.guard_requests req ON req.id = r.request_id
        {where_sql}
        ORDER BY r.created_at DESC
        LIMIT ${limit_idx} OFFSET ${offset_idx}
        "#
    );

    let count_sql = format!(
        r#"
        SELECT COUNT(*) AS count
        FROM reviews.guard_reviews r
        INNER JOIN auth.users cu ON cu.id = r.customer_id
        LEFT JOIN auth.customer_profiles cp ON cp.user_id = r.customer_id
        INNER JOIN auth.users gu ON gu.id = r.guard_id
        {where_sql}
        "#
    );

    // Bind helper closures aren't possible because each builder is its own
    // type — duplicate the bind chain for both queries.
    let mut list_query = sqlx::query_as::<_, AdminReviewRow>(&list_sql);
    let mut count_query = sqlx::query_scalar::<_, i64>(&count_sql);

    if let Some(gid) = query.guard_id {
        list_query = list_query.bind(gid);
        count_query = count_query.bind(gid);
    }
    if let Some(rating) = query.rating {
        list_query = list_query.bind(rating);
        count_query = count_query.bind(rating);
    }
    if let Some(visible) = query.is_visible {
        list_query = list_query.bind(visible);
        count_query = count_query.bind(visible);
    }
    if let Some(search) = query.search.as_deref().filter(|s| !s.trim().is_empty()) {
        let pattern = format!("%{}%", search.trim());
        list_query = list_query.bind(pattern.clone());
        count_query = count_query.bind(pattern);
    }

    list_query = list_query.bind(limit).bind(offset);

    let (rows, total) = tokio::try_join!(
        async { list_query.fetch_all(db).await.map_err(AppError::from) },
        async { count_query.fetch_one(db).await.map_err(AppError::from) },
    )?;

    // Compute global stats (NOT filtered) so the cards reflect the whole dataset.
    let stats_row = sqlx::query_as::<_, (Option<i64>, Option<i64>, Option<rust_decimal::Decimal>)>(
        r#"
        SELECT
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE is_visible = true) AS visible,
            AVG(overall_rating) AS avg_rating
        FROM reviews.guard_reviews
        "#,
    )
    .fetch_one(db)
    .await?;

    let stats = AdminReviewStats {
        total: stats_row.0.unwrap_or(0),
        visible: stats_row.1.unwrap_or(0),
        avg_rating: stats_row.2.and_then(|d| d.to_f64()).unwrap_or(0.0),
    };

    let data = rows
        .into_iter()
        .map(|r| AdminReviewResponse {
            id: r.id,
            assignment_id: r.assignment_id,
            request_id: r.request_id,
            customer_id: r.customer_id,
            customer_name: r.customer_name,
            guard_id: r.guard_id,
            guard_name: r.guard_name,
            overall_rating: r.overall_rating.to_f64().unwrap_or(0.0),
            punctuality: r.punctuality.and_then(|d| d.to_f64()),
            professionalism: r.professionalism.and_then(|d| d.to_f64()),
            communication: r.communication.and_then(|d| d.to_f64()),
            appearance: r.appearance.and_then(|d| d.to_f64()),
            review_text: r.review_text,
            address: r.address,
            is_visible: r.is_visible,
            created_at: r.created_at,
        })
        .collect();

    Ok(PaginatedAdminReviews {
        data,
        total,
        limit,
        offset,
        stats,
    })
}

pub async fn set_review_visibility(
    db: &PgPool,
    review_id: Uuid,
    is_visible: bool,
) -> Result<(), AppError> {
    let result = sqlx::query(
        "UPDATE reviews.guard_reviews SET is_visible = $1, updated_at = NOW() WHERE id = $2",
    )
    .bind(is_visible)
    .bind(review_id)
    .execute(db)
    .await?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Review not found".to_string()));
    }
    Ok(())
}

// =============================================================================
// Service Rates (Pricing) — CRUD
// =============================================================================

pub async fn list_service_rates(db: &PgPool) -> Result<Vec<ServiceRate>, AppError> {
    let rows = sqlx::query_as::<_, ServiceRate>(
        r#"
        SELECT id, name, description, base_fee, min_hours, notes, is_active, created_at, updated_at
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
        SELECT id, name, description, base_fee, min_hours, notes, is_active, created_at, updated_at
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

/// Upper bound for `base_fee` (฿/hour). Catches operator typos before they
/// reach the DB (column is `DECIMAL(10,2)` which allows up to 99,999,999.99).
const MAX_BASE_FEE: i64 = 1_000_000;

/// Accepted range for `min_hours`. Zero or negative values are meaningless
/// for a booking service, and anything over 24 is almost certainly wrong
/// (one continuous shift).
const MIN_ALLOWED_HOURS: i32 = 1;
const MAX_ALLOWED_HOURS: i32 = 24;

fn validate_service_rate(base_fee: rust_decimal::Decimal, min_hours: i32) -> Result<(), AppError> {
    if base_fee < rust_decimal::Decimal::ZERO {
        return Err(AppError::BadRequest(
            "Base fee cannot be negative".to_string(),
        ));
    }
    if base_fee > rust_decimal::Decimal::from(MAX_BASE_FEE) {
        return Err(AppError::BadRequest(format!(
            "Base fee cannot exceed ฿{MAX_BASE_FEE}"
        )));
    }
    if !(MIN_ALLOWED_HOURS..=MAX_ALLOWED_HOURS).contains(&min_hours) {
        return Err(AppError::BadRequest(format!(
            "Min hours must be between {MIN_ALLOWED_HOURS} and {MAX_ALLOWED_HOURS}"
        )));
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
        return Err(AppError::BadRequest(
            "Service name too long (max 200 chars)".to_string(),
        ));
    }
    let min_hours = dto.min_hours.unwrap_or(6);
    validate_service_rate(dto.base_fee, min_hours)?;

    let row = sqlx::query_as::<_, ServiceRate>(
        r#"
        INSERT INTO booking.service_rates (name, description, base_fee, min_hours, notes)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, name, description, base_fee, min_hours, notes, is_active, created_at, updated_at
        "#,
    )
    .bind(&name)
    .bind(&dto.description)
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
            return Err(AppError::BadRequest(
                "Service name cannot be empty".to_string(),
            ));
        }
        if name.len() > 200 {
            return Err(AppError::BadRequest(
                "Service name too long (max 200 chars)".to_string(),
            ));
        }
    }

    // Fetch existing to validate merged price values
    let existing = sqlx::query_as::<_, ServiceRate>(
        r#"
        SELECT id, name, description, base_fee, min_hours, notes, is_active, created_at, updated_at
        FROM booking.service_rates
        WHERE id = $1 AND is_active = true
        "#,
    )
    .bind(id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Service rate not found".to_string()))?;

    let final_base = dto.base_fee.unwrap_or(existing.base_fee);
    let final_min_hours = dto.min_hours.unwrap_or(existing.min_hours);
    validate_service_rate(final_base, final_min_hours)?;

    let row = sqlx::query_as::<_, ServiceRate>(
        r#"
        UPDATE booking.service_rates
        SET name        = COALESCE($2, name),
            description = COALESCE($3, description),
            base_fee    = COALESCE($4, base_fee),
            min_hours   = COALESCE($5, min_hours),
            notes       = COALESCE($6, notes),
            is_active   = COALESCE($7, is_active),
            updated_at  = NOW()
        WHERE id = $1
        RETURNING id, name, description, base_fee, min_hours, notes, is_active, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(dto.name.as_deref().map(str::trim))
    .bind(&dto.description)
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
// Accept / Decline Assignment (guard response to pending_acceptance)
// =============================================================================

pub async fn accept_or_decline_assignment(
    db: &PgPool,
    assignment_id: Uuid,
    guard_id: Uuid,
    req: AcceptDeclineDto,
    redis_conn: &redis::aio::MultiplexedConnection,
) -> Result<AssignmentResponse, AppError> {
    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               NULL::timestamptz AS en_route_at, NULL::float8 AS en_route_lat, NULL::float8 AS en_route_lng, NULL::float8 AS arrived_lat, NULL::float8 AS arrived_lng, NULL::TEXT AS en_route_place, NULL::TEXT AS arrived_place,
               NULL::float8 AS started_lat, NULL::float8 AS started_lng, NULL::TEXT AS started_place,
               NULL::float8 AS completion_lat, NULL::float8 AS completion_lng, NULL::TEXT AS completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
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
            "You can only respond to your own assignments".to_string(),
        ));
    }

    if existing.status != AssignmentStatus::PendingAcceptance {
        return Err(AppError::BadRequest(
            "Assignment is not pending acceptance".to_string(),
        ));
    }

    let new_status = if req.accept {
        "awaiting_payment"
    } else {
        "declined"
    };

    let row = sqlx::query_as::<_, AssignmentRow>(
        r#"
        UPDATE booking.assignments
        SET status = $2::assignment_status
        WHERE id = $1
        RETURNING id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
        "#,
    )
    .bind(assignment_id)
    .bind(new_status)
    .fetch_one(&mut *tx)
    .await?;

    if req.accept {
        // Update request status to assigned when guard accepts
        sqlx::query(
            "UPDATE booking.guard_requests SET status = 'assigned'::request_status, updated_at = NOW() WHERE id = $1",
        )
        .bind(existing.request_id)
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;

    // Publish real-time event (fire-and-forget)
    let new_status_label = if req.accept {
        "awaiting_payment"
    } else {
        "declined"
    };
    publish_assignment_event(
        redis_conn,
        existing.request_id,
        assignment_id,
        new_status_label,
    );

    // Notify customer about guard's decision
    {
        let db_clone = db.clone();
        let req_id = existing.request_id;
        let accepted = req.accept;
        let a_id = assignment_id;
        tokio::spawn(async move {
            let cid: Option<Uuid> =
                sqlx::query_scalar("SELECT customer_id FROM booking.guard_requests WHERE id = $1")
                    .bind(req_id)
                    .fetch_optional(&db_clone)
                    .await
                    .ok()
                    .flatten();

            if let Some(customer_id) = cid {
                if accepted {
                    spawn_notification(
                        db_clone,
                        customer_id,
                        "เจ้าหน้าที่ตอบรับแล้ว".to_string(),
                        "เจ้าหน้าที่ รปภ. ตอบรับงานแล้ว กรุณาชำระเงิน".to_string(),
                        "guard_assigned",
                        Some(serde_json::json!({
                            "request_id": req_id.to_string(),
                            "assignment_id": a_id.to_string(),
                            "target_role": "customer",
                        })),
                    );
                } else {
                    spawn_notification(
                        db_clone,
                        customer_id,
                        "เจ้าหน้าที่ปฏิเสธงาน".to_string(),
                        "เจ้าหน้าที่ รปภ. ปฏิเสธงาน กรุณาเลือกเจ้าหน้าที่ใหม่".to_string(),
                        "booking_cancelled",
                        Some(serde_json::json!({
                            "request_id": req_id.to_string(),
                            "target_role": "customer",
                        })),
                    );
                }
            }
        });
    }

    Ok(AssignmentResponse::from(row))
}

// =============================================================================
// Create Payment (simulated — records payment, updates request status)
// =============================================================================

fn validate_payment_request(req: &CreatePaymentDto) -> Result<(), AppError> {
    let valid_methods = ["promptpay", "credit_card", "debit_card", "mobile_banking"];
    if !valid_methods.contains(&req.payment_method.as_str()) {
        return Err(AppError::BadRequest(format!(
            "Invalid payment method: {}. Must be one of: {}",
            req.payment_method,
            valid_methods.join(", ")
        )));
    }
    if req.amount <= Decimal::ZERO {
        return Err(AppError::BadRequest(
            "Payment amount must be positive".to_string(),
        ));
    }
    Ok(())
}

pub async fn create_payment(
    db: &PgPool,
    customer_id: Uuid,
    req: CreatePaymentDto,
    redis_conn: &redis::aio::MultiplexedConnection,
) -> Result<PaymentResponse, AppError> {
    validate_payment_request(&req)?;

    let mut tx = db.begin().await?;

    // Verify request exists and belongs to customer
    let request = sqlx::query_as::<_, GuardRequestRow>(
        r#"
        SELECT id, customer_id, location_lat, location_lng, address, description, offered_price,
               special_instructions, status, urgency, booked_hours, guard_count,
               NULL::assignment_status AS assignment_status, created_at, updated_at
        FROM booking.guard_requests
        WHERE id = $1
        FOR UPDATE
        "#,
    )
    .bind(req.request_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Guard request not found".to_string()))?;

    if request.customer_id != customer_id {
        return Err(AppError::Forbidden(
            "You can only pay for your own requests".to_string(),
        ));
    }

    if request.status != RequestStatus::Assigned {
        return Err(AppError::BadRequest(
            "Can only pay for assigned requests (guard must accept first)".to_string(),
        ));
    }

    // Create payment record (simulated — immediately completed). final_amount /
    // refund_amount / actual_hours_worked stay NULL until the job ends; the
    // proration step in `review_completion` fills them in.
    let payment = sqlx::query_as::<_, PaymentRow>(
        r#"
        INSERT INTO booking.payments (request_id, customer_id, amount, payment_method, status, paid_at)
        VALUES ($1, $2, $3, $4, 'completed', NOW())
        RETURNING id, request_id, customer_id, amount, payment_method, status, paid_at, created_at,
                  actual_hours_worked, final_amount, refund_amount, tip_amount
        "#,
    )
    .bind(req.request_id)
    .bind(customer_id)
    .bind(req.amount)
    .bind(&req.payment_method)
    .fetch_one(&mut *tx)
    .await?;

    // Update assignment status from awaiting_payment → accepted (guard can now start route)
    let updated_assignment_id = sqlx::query_scalar::<_, Uuid>(
        r#"
        UPDATE booking.assignments
        SET status = 'accepted'::assignment_status
        WHERE request_id = $1 AND status = 'awaiting_payment'::assignment_status
        RETURNING id
        "#,
    )
    .bind(req.request_id)
    .fetch_optional(&mut *tx)
    .await?;

    tx.commit().await?;

    // Publish real-time event (fire-and-forget) — guard sees payment confirmed instantly
    if let Some(aid) = updated_assignment_id {
        publish_assignment_event(redis_conn, req.request_id, aid, "accepted");
    }

    // Notify guard: payment received
    {
        let db_clone = db.clone();
        let req_id = req.request_id;
        let _amount = req.amount;
        tokio::spawn(async move {
            let gid: Option<Uuid> = sqlx::query_scalar(
                "SELECT guard_id FROM booking.assignments WHERE request_id = $1 AND status = 'accepted'::assignment_status LIMIT 1",
            )
            .bind(req_id)
            .fetch_optional(&db_clone)
            .await
            .ok()
            .flatten();

            // Removed: payment notification — guard sees payment status in job detail
            let _ = gid;
        });
    }

    Ok(PaymentResponse::from(payment))
}

// =============================================================================
// Start Job (guard starts countdown timer)
// =============================================================================

pub async fn start_job(
    db: &PgPool,
    assignment_id: Uuid,
    guard_id: Uuid,
    lat: Option<f64>,
    lng: Option<f64>,
    http_client: &reqwest::Client,
) -> Result<ActiveJobResponse, AppError> {
    // Validate and reverse geocode BEFORE the transaction to avoid holding the row lock
    // during a potentially slow external HTTP call
    let (lat, lng) = sanitize_coords(lat, lng);
    let started_place = if let (Some(lt), Some(lg)) = (lat, lng) {
        reverse_geocode(http_client, lt, lg).await
    } else {
        None
    };

    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
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
            "You can only start your own assignments".to_string(),
        ));
    }

    if existing.status != AssignmentStatus::Arrived {
        return Err(AppError::BadRequest(
            "Can only start job after arriving at location".to_string(),
        ));
    }

    if existing.started_at.is_some() {
        return Err(AppError::BadRequest("Job already started".to_string()));
    }

    let now = Utc::now();

    sqlx::query(
        "UPDATE booking.assignments SET started_at = $2, started_lat = $3, started_lng = $4, started_place = $5 WHERE id = $1",
    )
    .bind(assignment_id)
    .bind(now)
    .bind(lat)
    .bind(lng)
    .bind(&started_place)
    .execute(&mut *tx)
    .await?;

    // Fetch request details for response
    #[derive(sqlx::FromRow)]
    struct RequestInfo {
        customer_id: Uuid,
        customer_name: Option<String>,
        address: String,
        booked_hours: Option<i32>,
        offered_price: Option<rust_decimal::Decimal>,
    }

    let info = sqlx::query_as::<_, RequestInfo>(
        r#"
        SELECT gr.customer_id, COALESCE(cp.full_name, u.full_name) AS customer_name, gr.address, gr.booked_hours, gr.offered_price
        FROM booking.guard_requests gr
        INNER JOIN auth.users u ON u.id = gr.customer_id
        LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
        WHERE gr.id = $1
        "#,
    )
    .bind(existing.request_id)
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;

    let booked_hours = info.booked_hours.unwrap_or(6);
    let remaining_seconds = (booked_hours as i64) * 3600;

    Ok(ActiveJobResponse {
        assignment_id,
        request_id: existing.request_id,
        customer_id: info.customer_id,
        customer_name: info.customer_name.unwrap_or_else(|| "-".to_string()),
        address: info.address,
        booked_hours,
        started_at: Some(now),
        remaining_seconds: Some(remaining_seconds),
        assignment_status: AssignmentStatus::Arrived,
        offered_price: info.offered_price.and_then(|d| d.to_f64()),
        completion_requested_at: None,
        en_route_at: existing.en_route_at,
        en_route_lat: existing.en_route_lat,
        en_route_lng: existing.en_route_lng,
        arrived_at: existing.arrived_at,
        arrived_lat: existing.arrived_lat,
        arrived_lng: existing.arrived_lng,
        en_route_place: existing.en_route_place,
        arrived_place: existing.arrived_place,
        started_lat: lat,
        started_lng: lng,
        started_place,
        completion_lat: None,
        completion_lng: None,
        completion_place: None,
    })
}

// =============================================================================
// Get Active Job (guard's current active job with countdown)
// =============================================================================

pub async fn get_active_job(
    db: &PgPool,
    guard_id: Uuid,
) -> Result<Option<ActiveJobResponse>, AppError> {
    #[derive(sqlx::FromRow)]
    struct ActiveJobRow {
        assignment_id: Uuid,
        request_id: Uuid,
        customer_id: Uuid,
        customer_name: Option<String>,
        address: String,
        booked_hours: Option<i32>,
        started_at: Option<chrono::DateTime<Utc>>,
        completion_requested_at: Option<chrono::DateTime<Utc>>,
        assignment_status: AssignmentStatus,
        offered_price: Option<rust_decimal::Decimal>,
        en_route_at: Option<chrono::DateTime<Utc>>,
        en_route_lat: Option<f64>,
        en_route_lng: Option<f64>,
        arrived_at: Option<chrono::DateTime<Utc>>,
        arrived_lat: Option<f64>,
        arrived_lng: Option<f64>,
        en_route_place: Option<String>,
        arrived_place: Option<String>,
        started_lat: Option<f64>,
        started_lng: Option<f64>,
        started_place: Option<String>,
        completion_lat: Option<f64>,
        completion_lng: Option<f64>,
        completion_place: Option<String>,
    }

    let row = sqlx::query_as::<_, ActiveJobRow>(
        r#"
        SELECT a.id AS assignment_id, gr.id AS request_id, gr.customer_id,
               COALESCE(cp.full_name, u.full_name) AS customer_name, gr.address, gr.booked_hours,
               a.started_at, a.completion_requested_at, a.status AS assignment_status, gr.offered_price,
               a.en_route_at, a.en_route_lat, a.en_route_lng, a.arrived_at, a.arrived_lat, a.arrived_lng, a.en_route_place, a.arrived_place,
               a.started_lat, a.started_lng, a.started_place, a.completion_lat, a.completion_lng, a.completion_place
        FROM booking.assignments a
        INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
        INNER JOIN auth.users u ON u.id = gr.customer_id
        LEFT JOIN auth.customer_profiles cp ON cp.user_id = gr.customer_id
        WHERE a.guard_id = $1 AND a.status IN ('accepted', 'assigned', 'awaiting_payment', 'en_route', 'arrived', 'pending_completion')
        ORDER BY a.assigned_at DESC
        LIMIT 1
        "#,
    )
    .bind(guard_id)
    .fetch_optional(db)
    .await?;

    match row {
        None => Ok(None),
        Some(r) => {
            let booked_hours = r.booked_hours.unwrap_or(6);
            let remaining_seconds = r.started_at.map(|start| {
                let elapsed = Utc::now().signed_duration_since(start).num_seconds();
                let total = (booked_hours as i64) * 3600;
                (total - elapsed).max(0)
            });

            Ok(Some(ActiveJobResponse {
                assignment_id: r.assignment_id,
                request_id: r.request_id,
                customer_id: r.customer_id,
                customer_name: r.customer_name.unwrap_or_else(|| "-".to_string()),
                address: r.address,
                booked_hours,
                started_at: r.started_at,
                remaining_seconds,
                assignment_status: r.assignment_status,
                offered_price: r.offered_price.and_then(|d| d.to_f64()),
                completion_requested_at: r.completion_requested_at,
                en_route_at: r.en_route_at,
                en_route_lat: r.en_route_lat,
                en_route_lng: r.en_route_lng,
                arrived_at: r.arrived_at,
                arrived_lat: r.arrived_lat,
                arrived_lng: r.arrived_lng,
                en_route_place: r.en_route_place,
                arrived_place: r.arrived_place,
                started_lat: r.started_lat,
                started_lng: r.started_lng,
                started_place: r.started_place,
                completion_lat: r.completion_lat,
                completion_lng: r.completion_lng,
                completion_place: r.completion_place,
            }))
        }
    }
}

// =============================================================================
// Get Active Job for Customer (customer views guard's countdown)
// =============================================================================

pub async fn get_customer_active_job(
    db: &PgPool,
    request_id: Uuid,
    user_id: Uuid,
    user_role: &str,
) -> Result<Option<ActiveJobResponse>, AppError> {
    // Verify ownership (customer owns request, or admin)
    if user_role != "admin" {
        let owns = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM booking.guard_requests WHERE id = $1 AND customer_id = $2)",
        )
        .bind(request_id)
        .bind(user_id)
        .fetch_one(db)
        .await?;

        if !owns {
            return Err(AppError::Forbidden(
                "You can only view active jobs for your own requests".to_string(),
            ));
        }
    }

    #[derive(sqlx::FromRow)]
    struct ActiveJobRow {
        assignment_id: Uuid,
        request_id: Uuid,
        guard_name: Option<String>,
        address: String,
        booked_hours: Option<i32>,
        started_at: Option<chrono::DateTime<Utc>>,
        completion_requested_at: Option<chrono::DateTime<Utc>>,
        assignment_status: AssignmentStatus,
        offered_price: Option<rust_decimal::Decimal>,
        en_route_at: Option<chrono::DateTime<Utc>>,
        en_route_lat: Option<f64>,
        en_route_lng: Option<f64>,
        arrived_at: Option<chrono::DateTime<Utc>>,
        arrived_lat: Option<f64>,
        arrived_lng: Option<f64>,
        en_route_place: Option<String>,
        arrived_place: Option<String>,
        started_lat: Option<f64>,
        started_lng: Option<f64>,
        started_place: Option<String>,
        completion_lat: Option<f64>,
        completion_lng: Option<f64>,
        completion_place: Option<String>,
    }

    let row = sqlx::query_as::<_, ActiveJobRow>(
        r#"
        SELECT a.id AS assignment_id, gr.id AS request_id,
               u.full_name AS guard_name, gr.address, gr.booked_hours,
               a.started_at, a.completion_requested_at, a.status AS assignment_status, gr.offered_price,
               a.en_route_at, a.en_route_lat, a.en_route_lng, a.arrived_at, a.arrived_lat, a.arrived_lng, a.en_route_place, a.arrived_place,
               a.started_lat, a.started_lng, a.started_place, a.completion_lat, a.completion_lng, a.completion_place
        FROM booking.assignments a
        INNER JOIN booking.guard_requests gr ON gr.id = a.request_id
        INNER JOIN auth.users u ON u.id = a.guard_id
        WHERE a.request_id = $1 AND a.status IN ('accepted', 'assigned', 'awaiting_payment', 'en_route', 'arrived', 'pending_completion')
        ORDER BY a.assigned_at DESC
        LIMIT 1
        "#,
    )
    .bind(request_id)
    .fetch_optional(db)
    .await?;

    match row {
        None => Ok(None),
        Some(r) => {
            let booked_hours = r.booked_hours.unwrap_or(6);
            let remaining_seconds = r.started_at.map(|start| {
                let elapsed = Utc::now().signed_duration_since(start).num_seconds();
                let total = (booked_hours as i64) * 3600;
                (total - elapsed).max(0)
            });

            Ok(Some(ActiveJobResponse {
                assignment_id: r.assignment_id,
                request_id: r.request_id,
                customer_id: user_id,
                customer_name: r.guard_name.unwrap_or_else(|| "-".to_string()),
                address: r.address,
                booked_hours,
                started_at: r.started_at,
                remaining_seconds,
                assignment_status: r.assignment_status,
                offered_price: r.offered_price.and_then(|d| d.to_f64()),
                completion_requested_at: r.completion_requested_at,
                en_route_at: r.en_route_at,
                en_route_lat: r.en_route_lat,
                en_route_lng: r.en_route_lng,
                arrived_at: r.arrived_at,
                arrived_lat: r.arrived_lat,
                arrived_lng: r.arrived_lng,
                en_route_place: r.en_route_place,
                arrived_place: r.arrived_place,
                started_lat: r.started_lat,
                started_lng: r.started_lng,
                started_place: r.started_place,
                completion_lat: r.completion_lat,
                completion_lng: r.completion_lng,
                completion_place: r.completion_place,
            }))
        }
    }
}

// =============================================================================
// Payment Proration (cost summary on job completion)
// =============================================================================

/// Compute the prorated final amount and the resulting refund.
///
/// Rules:
/// - `actual_hours` is clamped to `[0, booked_hours]` — overtime never adds
///   to the bill (the customer can tip separately if they want to give more).
/// - `booked_hours <= 0` is treated as a no-op: keep the original price.
/// - `final_amount = original * (actual / booked)`, rounded to 2 dp.
/// - `refund_amount = max(0, original - final)`.
fn compute_proration(
    original_amount: Decimal,
    booked_hours: i32,
    actual_seconds: i64,
) -> (Decimal, Decimal, Decimal) {
    // Clamp hours worked to non-negative seconds first to avoid surprises
    // from clock-skew or out-of-order timestamps.
    let secs = actual_seconds.max(0);
    let raw_hours = Decimal::from(secs) / Decimal::from(3600_i64);

    if booked_hours <= 0 {
        // No booking duration recorded → can't prorate; keep original.
        return (raw_hours, original_amount, Decimal::ZERO);
    }

    let booked_dec = Decimal::from(booked_hours);
    let actual = if raw_hours > booked_dec {
        booked_dec
    } else {
        raw_hours
    };

    let final_amount = if actual.is_zero() {
        Decimal::ZERO
    } else {
        (original_amount * actual / booked_dec).round_dp(2)
    };

    let refund = if original_amount > final_amount {
        original_amount - final_amount
    } else {
        Decimal::ZERO
    };

    // Round actual hours to 2 dp to match DB DECIMAL(5,2)
    (actual.round_dp(2), final_amount, refund)
}

/// Apply proration to the customer's payment row inside an open transaction.
///
/// Looks up the latest completed payment for the request and updates
/// `actual_hours_worked`, `final_amount`, `refund_amount`. If no payment
/// exists yet (e.g. customer never paid), this is a silent no-op so the
/// completion flow still succeeds.
async fn prorate_payment_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    request_id: Uuid,
    started_at: Option<chrono::DateTime<Utc>>,
    completed_at: Option<chrono::DateTime<Utc>>,
) -> Result<(), AppError> {
    // Look up the request's booked_hours + the latest completed payment row.
    // If either is missing, skip silently — the completion flow still succeeds
    // (payment proration is best-effort, not a hard requirement).
    let row: Option<(Option<i32>, Option<Uuid>, Option<Decimal>)> = sqlx::query_as(
        r#"
        SELECT
            r.booked_hours,
            p.id,
            p.amount
        FROM booking.guard_requests r
        LEFT JOIN LATERAL (
            SELECT id, amount
            FROM booking.payments
            WHERE request_id = r.id AND status = 'completed'
            ORDER BY created_at DESC
            LIMIT 1
        ) p ON TRUE
        WHERE r.id = $1
        "#,
    )
    .bind(request_id)
    .fetch_optional(&mut **tx)
    .await?;

    let Some((booked_hours, payment_id, original_amount)) = row else {
        tracing::warn!(
            request_id = %request_id,
            "prorate_payment_in_tx: guard_request not found, skipping proration"
        );
        return Ok(());
    };
    let (Some(payment_id), Some(original_amount), Some(booked_hours)) =
        (payment_id, original_amount, booked_hours)
    else {
        // Missing payment row (customer never paid) or missing booked_hours
        // (legacy data). Not an error — just means there's nothing to prorate.
        tracing::warn!(
            request_id = %request_id,
            has_booked_hours = booked_hours.is_some(),
            has_payment = payment_id.is_some(),
            "prorate_payment_in_tx: missing data, skipping proration"
        );
        return Ok(());
    };

    // If the assignment was completed without ever being started (e.g. an
    // admin override), we have no factual basis for proration. Skip the
    // payment update entirely so the customer keeps the original amount —
    // proration columns stay NULL and the cost-summary endpoint will show
    // the original price as the final price. Computing `final = 0 * rate`
    // here would be a billing data corruption (customer billed 0 for work
    // that did happen). (code-reviewer MEDIUM fix)
    let (Some(start), Some(end)) = (started_at, completed_at) else {
        tracing::warn!(
            request_id = %request_id,
            has_started_at = started_at.is_some(),
            has_completed_at = completed_at.is_some(),
            "prorate_payment_in_tx: missing timestamps, skipping proration"
        );
        return Ok(());
    };
    let actual_seconds = (end - start).num_seconds();

    let (actual_hours, final_amount, refund_amount) =
        compute_proration(original_amount, booked_hours, actual_seconds);

    sqlx::query(
        r#"
        UPDATE booking.payments
        SET actual_hours_worked = $2,
            final_amount        = $3,
            refund_amount       = $4
        WHERE id = $1
        "#,
    )
    .bind(payment_id)
    .bind(actual_hours)
    .bind(final_amount)
    .bind(refund_amount)
    .execute(&mut **tx)
    .await?;

    Ok(())
}

// =============================================================================
// Cost Summary (read) + Tip (write)
// =============================================================================

/// Build a `CostSummaryResponse` for an assignment.
///
/// Visibility:
/// - Admin: any assignment
/// - Customer: only assignments tied to their own requests
/// - Guard: only assignments where they are the assigned guard
///
/// Returns 404 if the assignment / payment can't be found, 403 on visibility
/// failure. Works at any assignment status — fields that are still unknown
/// (e.g. `actual_hours_worked` while job is active) come back as `None`.
pub async fn get_cost_summary(
    db: &PgPool,
    assignment_id: Uuid,
    user_id: Uuid,
    role: &str,
) -> Result<CostSummaryResponse, AppError> {
    #[derive(sqlx::FromRow)]
    struct Row {
        // assignment
        request_id: Uuid,
        guard_id: Uuid,
        status: AssignmentStatus,
        started_at: Option<chrono::DateTime<Utc>>,
        completed_at: Option<chrono::DateTime<Utc>>,
        // request
        customer_id: Uuid,
        booked_hours: Option<i32>,
        // payment (LEFT JOIN — may be NULL if customer never paid)
        payment_id: Option<Uuid>,
        original_amount: Option<Decimal>,
        actual_hours_worked: Option<Decimal>,
        final_amount: Option<Decimal>,
        refund_amount: Option<Decimal>,
        tip_amount: Option<Decimal>,
    }

    let row = sqlx::query_as::<_, Row>(
        r#"
        SELECT
            a.request_id,
            a.guard_id,
            a.status,
            a.started_at,
            a.completed_at,
            r.customer_id,
            r.booked_hours,
            p.id           AS payment_id,
            p.amount       AS original_amount,
            p.actual_hours_worked,
            p.final_amount,
            p.refund_amount,
            p.tip_amount
        FROM booking.assignments a
        JOIN booking.guard_requests r ON r.id = a.request_id
        LEFT JOIN LATERAL (
            SELECT id, amount, actual_hours_worked, final_amount, refund_amount, tip_amount
            FROM booking.payments
            WHERE request_id = a.request_id AND status = 'completed'
            ORDER BY created_at DESC
            LIMIT 1
        ) p ON TRUE
        WHERE a.id = $1
        "#,
    )
    .bind(assignment_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Assignment not found".to_string()))?;

    // Authorization
    let allowed = match role {
        "admin" => true,
        "guard" => row.guard_id == user_id,
        _ => row.customer_id == user_id,
    };
    if !allowed {
        return Err(AppError::Forbidden(
            "You do not have access to this cost summary".to_string(),
        ));
    }

    let payment_id = row.payment_id.ok_or_else(|| {
        AppError::NotFound("No payment recorded for this assignment yet".to_string())
    })?;
    let original_amount = row.original_amount.unwrap_or(Decimal::ZERO);
    let booked_hours = row.booked_hours.unwrap_or(0);
    let tip_amount = row.tip_amount.unwrap_or(Decimal::ZERO);

    // Hourly rate is helpful for the UI to explain proration math.
    let hourly_rate = if booked_hours > 0 {
        Some((original_amount / Decimal::from(booked_hours)).round_dp(2))
    } else {
        None
    };

    // Net is final + tip — only meaningful when proration has run.
    let net_amount = row.final_amount.map(|fa| (fa + tip_amount).round_dp(2));

    Ok(CostSummaryResponse {
        assignment_id,
        request_id: row.request_id,
        status: row.status,
        booked_hours,
        actual_hours_worked: row.actual_hours_worked,
        original_amount,
        final_amount: row.final_amount,
        refund_amount: row.refund_amount,
        tip_amount,
        net_amount,
        hourly_rate,
        started_at: row.started_at,
        completed_at: row.completed_at,
        payment_id,
    })
}

/// Customer adds a tip to the guard from the completion-summary screen.
///
/// Rules:
/// - Only the request owner can tip.
/// - Tip can only be added once the assignment is `completed` (so the
///   customer has seen the summary first).
/// - Tip amount must be > 0.
/// - Tips accumulate — calling this twice adds both amounts.
/// - Notifies the guard via `spawn_notification`.
pub async fn add_tip(
    db: &PgPool,
    assignment_id: Uuid,
    user_id: Uuid,
    amount: Decimal,
) -> Result<CostSummaryResponse, AppError> {
    if amount <= Decimal::ZERO {
        return Err(AppError::BadRequest(
            "Tip amount must be greater than zero".to_string(),
        ));
    }

    let mut tx = db.begin().await?;

    #[derive(sqlx::FromRow)]
    struct Row {
        request_id: Uuid,
        guard_id: Uuid,
        status: AssignmentStatus,
        customer_id: Uuid,
        payment_id: Option<Uuid>,
    }

    let row = sqlx::query_as::<_, Row>(
        r#"
        SELECT
            a.request_id,
            a.guard_id,
            a.status,
            r.customer_id,
            p.id AS payment_id
        FROM booking.assignments a
        JOIN booking.guard_requests r ON r.id = a.request_id
        LEFT JOIN LATERAL (
            SELECT id
            FROM booking.payments
            WHERE request_id = a.request_id AND status = 'completed'
            ORDER BY created_at DESC
            LIMIT 1
        ) p ON TRUE
        WHERE a.id = $1
        FOR UPDATE OF a
        "#,
    )
    .bind(assignment_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Assignment not found".to_string()))?;

    if row.customer_id != user_id {
        return Err(AppError::Forbidden(
            "Only the request owner can add a tip".to_string(),
        ));
    }

    if row.status != AssignmentStatus::Completed {
        return Err(AppError::BadRequest(
            "Tips can only be added after the job is completed".to_string(),
        ));
    }

    let payment_id = row
        .payment_id
        .ok_or_else(|| AppError::NotFound("No payment recorded for this assignment".to_string()))?;

    sqlx::query(
        r#"
        UPDATE booking.payments
        SET tip_amount = tip_amount + $2
        WHERE id = $1
        "#,
    )
    .bind(payment_id)
    .bind(amount)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // Notify guard about the tip
    spawn_notification(
        db.clone(),
        row.guard_id,
        "ลูกค้ามอบทิปให้คุณ".to_string(),
        format!("คุณได้รับทิปเพิ่มเติม {} บาท", amount),
        "system",
        Some(serde_json::json!({
            "request_id": row.request_id.to_string(),
            "assignment_id": assignment_id.to_string(),
            "tip_amount": amount.to_string(),
            "target_role": "guard",
        })),
    );

    // Return the refreshed summary
    get_cost_summary(db, assignment_id, user_id, "customer").await
}

// =============================================================================
// Review Completion (customer approves or holds guard's completion request)
// =============================================================================

pub async fn review_completion(
    db: &PgPool,
    assignment_id: Uuid,
    user_id: Uuid,
    role: &str,
    req: crate::models::ReviewCompletionDto,
    redis_conn: &redis::aio::MultiplexedConnection,
) -> Result<AssignmentResponse, AppError> {
    let mut tx = db.begin().await?;

    let existing = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
        FROM booking.assignments
        WHERE id = $1
        FOR UPDATE
        "#,
    )
    .bind(assignment_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound("Assignment not found".to_string()))?;

    if existing.status != AssignmentStatus::PendingCompletion {
        return Err(AppError::BadRequest(
            "Assignment is not pending completion review".to_string(),
        ));
    }

    // Customer must own the request, or be admin
    if role != "admin" {
        let owns = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM booking.guard_requests WHERE id = $1 AND customer_id = $2)",
        )
        .bind(existing.request_id)
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;

        if !owns {
            return Err(AppError::Forbidden(
                "You can only review completions for your own requests".to_string(),
            ));
        }
    }

    let now = Utc::now();

    if req.approve {
        // Approve: status → completed
        let row = sqlx::query_as::<_, AssignmentRow>(
            r#"
            UPDATE booking.assignments
            SET status = 'completed'::assignment_status, completed_at = $2
            WHERE id = $1
            RETURNING id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
            "#,
        )
        .bind(assignment_id)
        .bind(now)
        .fetch_one(&mut *tx)
        .await?;

        // Update request status to completed
        sqlx::query(
            "UPDATE booking.guard_requests SET status = 'completed'::request_status, updated_at = NOW() WHERE id = $1",
        )
        .bind(existing.request_id)
        .execute(&mut *tx)
        .await?;

        // Prorate the customer's payment by actual hours worked.
        // We do this inside the same transaction so that "completed" and the
        // billing snapshot are committed atomically — if the proration update
        // fails, the completion approval rolls back and the customer can retry.
        prorate_payment_in_tx(
            &mut tx,
            existing.request_id,
            row.started_at,
            row.completed_at,
        )
        .await?;

        tx.commit().await?;
        publish_assignment_event(redis_conn, existing.request_id, assignment_id, "completed");

        // Notify guard: job completed/approved
        spawn_notification(
            db.clone(),
            existing.guard_id,
            "งานเสร็จสมบูรณ์".to_string(),
            "ลูกค้าอนุมัติการทำงานเสร็จสิ้นแล้ว".to_string(),
            "booking_completed",
            Some(serde_json::json!({
                "request_id": existing.request_id.to_string(),
                "assignment_id": assignment_id.to_string(),
                "target_role": "guard",
            })),
        );

        Ok(AssignmentResponse::from(row))
    } else {
        // Hold: status → arrived (guard resumes working), clear completion_requested_at
        let row = sqlx::query_as::<_, AssignmentRow>(
            r#"
            UPDATE booking.assignments
            SET status = 'arrived'::assignment_status, completion_requested_at = NULL
            WHERE id = $1
            RETURNING id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
            "#,
        )
        .bind(assignment_id)
        .fetch_one(&mut *tx)
        .await?;

        tx.commit().await?;
        publish_assignment_event(redis_conn, existing.request_id, assignment_id, "arrived");
        Ok(AssignmentResponse::from(row))
    }
}

// =============================================================================
// Submit Review (customer rates guard after job completion)
// =============================================================================

pub async fn submit_review(
    db: &PgPool,
    assignment_id: Uuid,
    customer_id: Uuid,
    role: &str,
    req: crate::models::CreateReviewDto,
) -> Result<crate::models::SubmitReviewResponse, AppError> {
    use rust_decimal::Decimal;

    // Validate rating ranges (1.0 - 5.0)
    let one = Decimal::new(1, 0);
    let five = Decimal::new(5, 0);

    if req.overall_rating < one || req.overall_rating > five {
        return Err(AppError::BadRequest(
            "overall_rating must be between 1.0 and 5.0".to_string(),
        ));
    }
    for (name, val) in [
        ("punctuality", &req.punctuality),
        ("professionalism", &req.professionalism),
        ("communication", &req.communication),
        ("appearance", &req.appearance),
    ] {
        if let Some(v) = val {
            if *v < one || *v > five {
                return Err(AppError::BadRequest(format!(
                    "{name} must be between 1.0 and 5.0"
                )));
            }
        }
    }

    // Fetch assignment — must be completed
    let assignment = sqlx::query_as::<_, AssignmentRow>(
        r#"
        SELECT id, request_id, guard_id, NULL::TEXT AS guard_name, status, assigned_at, arrived_at, completed_at, started_at, completion_requested_at,
               en_route_at, en_route_lat, en_route_lng, arrived_lat, arrived_lng, en_route_place, arrived_place,
               started_lat, started_lng, started_place, completion_lat, completion_lng, completion_place,
               NULL::float8 AS review_overall_rating, NULL::float8 AS review_punctuality, NULL::float8 AS review_professionalism, NULL::float8 AS review_communication, NULL::float8 AS review_appearance, NULL::TEXT AS review_text
        FROM booking.assignments
        WHERE id = $1
        "#,
    )
    .bind(assignment_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Assignment not found".to_string()))?;

    if assignment.status != AssignmentStatus::Completed {
        return Err(AppError::BadRequest(
            "Can only review completed assignments".to_string(),
        ));
    }

    // Authorization: customer must own the request, or be admin
    if role != "admin" {
        let owns = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM booking.guard_requests WHERE id = $1 AND customer_id = $2)",
        )
        .bind(assignment.request_id)
        .bind(customer_id)
        .fetch_one(db)
        .await?;

        if !owns {
            return Err(AppError::Forbidden(
                "You can only review your own requests".to_string(),
            ));
        }
    }

    // Insert review (UNIQUE constraint on assignment_id prevents duplicates)
    let review_id = match sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO reviews.guard_reviews (guard_id, customer_id, assignment_id, request_id, overall_rating, punctuality, professionalism, communication, appearance, review_text)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING id
        "#,
    )
    .bind(assignment.guard_id)
    .bind(customer_id)
    .bind(assignment_id)
    .bind(assignment.request_id)
    .bind(req.overall_rating)
    .bind(req.punctuality)
    .bind(req.professionalism)
    .bind(req.communication)
    .bind(req.appearance)
    .bind(&req.review_text)
    .fetch_one(db)
    .await {
        Ok(id) => id,
        Err(sqlx::Error::Database(db_err)) if db_err.is_unique_violation() => {
            return Err(AppError::Conflict("Review already submitted for this assignment".to_string()));
        }
        Err(e) => return Err(AppError::from(e)),
    };

    // Removed: review notification — guard can see reviews in ratings tab

    Ok(crate::models::SubmitReviewResponse {
        id: review_id,
        message: "Review submitted".to_string(),
    })
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
            COALESCE(jc.cnt, 0) AS completed_jobs,
            rv.avg_rating AS rating,
            COALESCE(rv.review_count, 0) AS review_count
        FROM auth.users u
        INNER JOIN tracking.guard_locations gl ON gl.guard_id = u.id
        LEFT JOIN auth.guard_profiles gp ON gp.user_id = u.id
        LEFT JOIN (
            SELECT a.guard_id, COUNT(*) AS cnt
            FROM booking.assignments a
            WHERE a.status = 'completed'
            GROUP BY a.guard_id
        ) jc ON jc.guard_id = u.id
        LEFT JOIN (
            SELECT r.guard_id,
                   AVG(r.overall_rating)::float8 AS avg_rating,
                   COUNT(*)::int8 AS review_count
            FROM reviews.guard_reviews r
            GROUP BY r.guard_id
        ) rv ON rv.guard_id = u.id
        WHERE u.role = 'guard'
          AND u.is_active = true
          AND u.approval_status = 'approved'
          AND gl.is_online = true
          AND gl.recorded_at > NOW() - INTERVAL '5 minutes'
          AND NOT EXISTS (
              SELECT 1 FROM booking.assignments ba
              WHERE ba.guard_id = u.id
                AND ba.status IN ('pending_acceptance', 'accepted', 'en_route', 'arrived', 'pending_completion')
          )
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

// =============================================================================
// Progress Reports
// =============================================================================

/// Lightweight row for verifying assignment ownership + status.
#[allow(dead_code)]
#[derive(Debug, sqlx::FromRow)]
struct ProgressAssignmentCheck {
    pub guard_id: Uuid,
    pub status: AssignmentStatus,
    pub booked_hours: Option<i32>,
    pub customer_id: Uuid,
}

/// Submit an hourly progress report (guard only).
/// Uses runtime queries (sqlx::query) because progress_reports table is new and
/// not available at compile-time without a running DB.
#[allow(clippy::too_many_arguments)]
pub async fn submit_progress_report(
    db: &PgPool,
    s3_client: &aws_sdk_s3::Client,
    s3_bucket: &str,
    s3_endpoint: &str,
    s3_public_url: &str,
    assignment_id: Uuid,
    guard_id: Uuid,
    hour_number: i32,
    message: Option<String>,
    files: Vec<(Vec<u8>, String)>, // Vec<(bytes, mime_type)>
) -> Result<ProgressReportResponse, AppError> {
    // 1. Verify assignment exists, belongs to this guard, and is in active status
    let row = sqlx::query_as::<_, ProgressAssignmentCheck>(
        r#"
        SELECT a.guard_id, a.status AS "status",
               gr.booked_hours, gr.customer_id
        FROM booking.assignments a
        JOIN booking.guard_requests gr ON gr.id = a.request_id
        WHERE a.id = $1
        "#,
    )
    .bind(assignment_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Assignment not found".to_string()))?;

    if row.guard_id != guard_id {
        return Err(AppError::Forbidden(
            "You can only submit reports for your own assignments".to_string(),
        ));
    }

    let active_statuses = [
        AssignmentStatus::Accepted,
        AssignmentStatus::EnRoute,
        AssignmentStatus::Arrived,
        AssignmentStatus::PendingCompletion,
    ];
    if !active_statuses.contains(&row.status) {
        return Err(AppError::BadRequest(
            "Assignment is not in an active state".to_string(),
        ));
    }

    // 2. Validate hour_number (0 = initial report at job start)
    if hour_number < 0 {
        return Err(AppError::BadRequest("hour_number must be >= 0".to_string()));
    }
    if let Some(booked) = row.booked_hours {
        if hour_number > booked {
            return Err(AppError::BadRequest(format!(
                "hour_number ({hour_number}) exceeds booked_hours ({booked})"
            )));
        }
    }

    // 3. Upload files in parallel via JoinSet
    let mut uploaded: Vec<(String, String, i32)> = Vec::new(); // (file_key, mime_type, file_size)
    if !files.is_empty() {
        let mut join_set = tokio::task::JoinSet::new();
        for (idx, (data, mime)) in files.into_iter().enumerate() {
            let ext = crate::s3::mime_to_extension(&mime);
            let file_key = format!("reports/{assignment_id}/{hour_number}/{idx}.{ext}");
            let file_size = data.len() as i32;
            let s3 = s3_client.clone();
            let bucket = s3_bucket.to_string();
            let fk = file_key.clone();
            let mt = mime.clone();
            join_set.spawn(async move {
                crate::s3::upload_file(&s3, &bucket, &fk, data, &mt).await?;
                Ok::<(String, String, i32), AppError>((file_key, mime, file_size))
            });
        }
        while let Some(result) = join_set.join_next().await {
            let item =
                result.map_err(|e| AppError::Internal(format!("Upload task failed: {e}")))?;
            uploaded.push(item?);
        }
        // Sort by file_key to maintain consistent order (index is in the key)
        uploaded.sort_by(|a, b| a.0.cmp(&b.0));
    }

    // Set legacy photo_file_key from first image (backward compat)
    let first_image = uploaded
        .iter()
        .find(|(_, mime, _)| !crate::s3::is_video_mime(mime));
    let photo_file_key = first_image.map(|(k, _, _)| k.as_str());
    let photo_mime_type = first_image.map(|(_, m, _)| m.as_str());

    // 4. INSERT with ON CONFLICT DO NOTHING — returns None if duplicate
    let inserted = sqlx::query_as::<_, ProgressReportRow>(
        r#"
        INSERT INTO booking.progress_reports (assignment_id, guard_id, hour_number, message, photo_file_key, photo_mime_type)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (assignment_id, hour_number) DO NOTHING
        RETURNING id, assignment_id, guard_id, hour_number, message, photo_file_key, photo_mime_type, created_at
        "#,
    )
    .bind(assignment_id)
    .bind(guard_id)
    .bind(hour_number)
    .bind(message.as_deref())
    .bind(photo_file_key)
    .bind(photo_mime_type)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| {
        AppError::Conflict(format!(
            "Progress report for hour {hour_number} already submitted"
        ))
    })?;

    // 5. Bulk INSERT media rows + generate signed URLs
    let rewrite = s3_endpoint != s3_public_url;
    let mut media = Vec::with_capacity(uploaded.len());
    for (sort_order, (file_key, mime_type, file_size)) in uploaded.into_iter().enumerate() {
        let media_row = sqlx::query_as::<_, ProgressReportMediaRow>(
            r#"
            INSERT INTO booking.progress_report_media (report_id, file_key, mime_type, file_size, sort_order)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, report_id, file_key, mime_type, file_size, sort_order, created_at
            "#,
        )
        .bind(inserted.id)
        .bind(&file_key)
        .bind(&mime_type)
        .bind(file_size)
        .bind(sort_order as i32)
        .fetch_one(db)
        .await?;

        let url = crate::s3::get_signed_url(s3_client, s3_bucket, &file_key).await?;
        let url = if rewrite {
            url.replacen(s3_endpoint, s3_public_url, 1)
        } else {
            url
        };
        media.push(ProgressReportMediaItem {
            id: media_row.id,
            url,
            mime_type,
            file_size,
            sort_order: sort_order as i32,
        });
    }

    // 6. photo_url = first image signed URL (backward compat)
    let photo_url = media
        .iter()
        .find(|m| !crate::s3::is_video_mime(&m.mime_type))
        .map(|m| m.url.clone());

    // Removed: progress report notification — customer sees reports in active job screen

    Ok(ProgressReportResponse {
        id: inserted.id,
        assignment_id: inserted.assignment_id,
        guard_id: inserted.guard_id,
        hour_number: inserted.hour_number,
        message: inserted.message,
        photo_url,
        media,
        created_at: inserted.created_at,
    })
}

/// List progress reports for an assignment (guard, customer, or admin).
#[allow(clippy::too_many_arguments)]
pub async fn list_progress_reports(
    db: &PgPool,
    s3_client: &aws_sdk_s3::Client,
    s3_bucket: &str,
    s3_endpoint: &str,
    s3_public_url: &str,
    assignment_id: Uuid,
    user_id: Uuid,
    user_role: &str,
) -> Result<Vec<ProgressReportResponse>, AppError> {
    // 1. Verify access: admin can see all, guard/customer must be involved
    if user_role != "admin" {
        let has_access: Option<bool> = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM booking.assignments a
                JOIN booking.guard_requests gr ON gr.id = a.request_id
                WHERE a.id = $1
                  AND (a.guard_id = $2 OR gr.customer_id = $2)
            )
            "#,
        )
        .bind(assignment_id)
        .bind(user_id)
        .fetch_one(db)
        .await?;

        if has_access != Some(true) {
            return Err(AppError::Forbidden(
                "You don't have access to this assignment's reports".to_string(),
            ));
        }
    }

    // 2. Fetch all reports
    let rows = sqlx::query_as::<_, ProgressReportRow>(
        r#"
        SELECT id, assignment_id, guard_id, hour_number, message, photo_file_key, photo_mime_type, created_at
        FROM booking.progress_reports
        WHERE assignment_id = $1
        ORDER BY hour_number ASC
        "#,
    )
    .bind(assignment_id)
    .fetch_all(db)
    .await?;

    if rows.is_empty() {
        return Ok(vec![]);
    }

    // 3. Fetch all media for these reports in one query
    let report_ids: Vec<Uuid> = rows.iter().map(|r| r.id).collect();
    let media_rows = sqlx::query_as::<_, ProgressReportMediaRow>(
        r#"
        SELECT id, report_id, file_key, mime_type, file_size, sort_order, created_at
        FROM booking.progress_report_media
        WHERE report_id = ANY($1)
        ORDER BY report_id, sort_order
        "#,
    )
    .bind(&report_ids)
    .fetch_all(db)
    .await?;

    // Group media by report_id
    let mut media_map: std::collections::HashMap<Uuid, Vec<ProgressReportMediaRow>> =
        std::collections::HashMap::new();
    for m in media_rows {
        media_map.entry(m.report_id).or_default().push(m);
    }

    // 4. Build responses with signed URLs
    let rewrite = s3_endpoint != s3_public_url;
    let mut responses = Vec::with_capacity(rows.len());
    for row in rows {
        // Build media items with signed URLs
        let mut media = Vec::new();
        if let Some(media_rows) = media_map.remove(&row.id) {
            for m in media_rows {
                let url = crate::s3::get_signed_url(s3_client, s3_bucket, &m.file_key).await?;
                let url = if rewrite {
                    url.replacen(s3_endpoint, s3_public_url, 1)
                } else {
                    url
                };
                media.push(ProgressReportMediaItem {
                    id: m.id,
                    url,
                    mime_type: m.mime_type,
                    file_size: m.file_size,
                    sort_order: m.sort_order,
                });
            }
        }

        // Legacy fallback: if no media rows but photo_file_key exists (pre-migration data)
        if media.is_empty() {
            if let Some(ref key) = row.photo_file_key {
                let url = crate::s3::get_signed_url(s3_client, s3_bucket, key).await?;
                let url = if rewrite {
                    url.replacen(s3_endpoint, s3_public_url, 1)
                } else {
                    url
                };
                let mime = row
                    .photo_mime_type
                    .clone()
                    .unwrap_or_else(|| "image/jpeg".to_string());
                media.push(ProgressReportMediaItem {
                    id: row.id, // reuse report id for legacy
                    url,
                    mime_type: mime,
                    file_size: 0, // unknown for legacy
                    sort_order: 0,
                });
            }
        }

        // photo_url = first image from media (backward compat)
        let photo_url = media
            .iter()
            .find(|m| !crate::s3::is_video_mime(&m.mime_type))
            .map(|m| m.url.clone());

        responses.push(ProgressReportResponse {
            id: row.id,
            assignment_id: row.assignment_id,
            guard_id: row.guard_id,
            hour_number: row.hour_number,
            message: row.message,
            photo_url,
            media,
            created_at: row.created_at,
        });
    }

    Ok(responses)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{CreateRequestDto, UrgencyLevel};

    // =========================================================================
    // create_request input validation (mirrors validation in create_request())
    // These test validation logic without requiring a database connection.
    // =========================================================================

    /// Helper that runs the same validation checks as create_request().
    fn validate_create_request(req: &CreateRequestDto) -> Result<(), AppError> {
        if req.address.is_empty() {
            return Err(AppError::BadRequest("Address is required".to_string()));
        }

        // Validate coordinates
        if !(-90.0..=90.0).contains(&req.location_lat) {
            return Err(AppError::BadRequest(
                "Latitude must be between -90 and 90".to_string(),
            ));
        }
        if !(-180.0..=180.0).contains(&req.location_lng) {
            return Err(AppError::BadRequest(
                "Longitude must be between -180 and 180".to_string(),
            ));
        }
        if req.location_lat == 0.0 && req.location_lng == 0.0 {
            return Err(AppError::BadRequest(
                "Invalid coordinates (0,0)".to_string(),
            ));
        }

        // Validate booked_hours
        if let Some(hours) = req.booked_hours {
            if !(1..=720).contains(&hours) {
                return Err(AppError::BadRequest(
                    "Booked hours must be between 1 and 720".to_string(),
                ));
            }
        }

        // Validate guard_count
        if !(1..=20).contains(&req.guard_count) {
            return Err(AppError::BadRequest(
                "Guard count must be between 1 and 20".to_string(),
            ));
        }

        // Validate offered_price
        if let Some(price) = req.offered_price {
            if price < 0.0 {
                return Err(AppError::BadRequest(
                    "Offered price cannot be negative".to_string(),
                ));
            }
        }

        // Validate Decimal conversion (NaN/Infinity)
        if let Some(p) = req.offered_price {
            rust_decimal::Decimal::try_from(p)
                .map_err(|_| AppError::BadRequest("Invalid offered price value".to_string()))?;
        }

        Ok(())
    }

    fn valid_request() -> CreateRequestDto {
        CreateRequestDto {
            location_lat: 13.7563,
            location_lng: 100.5018,
            address: "123 Test Street, Bangkok".to_string(),
            description: None,
            offered_price: None,
            special_instructions: None,
            urgency: UrgencyLevel::Medium,
            booked_hours: Some(6),
            guard_count: 1,
        }
    }

    #[test]
    fn create_request_accepts_valid_input() {
        assert!(validate_create_request(&valid_request()).is_ok());
    }

    // --- Coordinate validation ---

    #[test]
    fn create_request_rejects_lat_above_90() {
        let mut req = valid_request();
        req.location_lat = 91.0;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Latitude"));
    }

    #[test]
    fn create_request_rejects_lat_below_negative_90() {
        let mut req = valid_request();
        req.location_lat = -91.0;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Latitude"));
    }

    #[test]
    fn create_request_rejects_lng_above_180() {
        let mut req = valid_request();
        req.location_lng = 181.0;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Longitude"));
    }

    #[test]
    fn create_request_rejects_lng_below_negative_180() {
        let mut req = valid_request();
        req.location_lng = -181.0;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Longitude"));
    }

    #[test]
    fn create_request_rejects_zero_zero_coordinates() {
        let mut req = valid_request();
        req.location_lat = 0.0;
        req.location_lng = 0.0;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("(0,0)"));
    }

    #[test]
    fn create_request_accepts_lat_at_boundaries() {
        let mut req = valid_request();
        req.location_lat = 90.0;
        assert!(validate_create_request(&req).is_ok());
        req.location_lat = -90.0;
        assert!(validate_create_request(&req).is_ok());
    }

    #[test]
    fn create_request_accepts_lng_at_boundaries() {
        let mut req = valid_request();
        req.location_lng = 180.0;
        assert!(validate_create_request(&req).is_ok());
        req.location_lng = -180.0;
        assert!(validate_create_request(&req).is_ok());
    }

    // --- booked_hours validation ---

    #[test]
    fn create_request_rejects_zero_booked_hours() {
        let mut req = valid_request();
        req.booked_hours = Some(0);
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Booked hours"));
    }

    #[test]
    fn create_request_rejects_negative_booked_hours() {
        let mut req = valid_request();
        req.booked_hours = Some(-1);
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Booked hours"));
    }

    #[test]
    fn create_request_rejects_721_booked_hours() {
        let mut req = valid_request();
        req.booked_hours = Some(721);
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Booked hours"));
    }

    #[test]
    fn create_request_accepts_1_booked_hour() {
        let mut req = valid_request();
        req.booked_hours = Some(1);
        assert!(validate_create_request(&req).is_ok());
    }

    #[test]
    fn create_request_accepts_720_booked_hours() {
        let mut req = valid_request();
        req.booked_hours = Some(720);
        assert!(validate_create_request(&req).is_ok());
    }

    #[test]
    fn create_request_accepts_none_booked_hours() {
        let mut req = valid_request();
        req.booked_hours = None;
        assert!(validate_create_request(&req).is_ok());
    }

    // --- guard_count validation ---

    #[test]
    fn create_request_rejects_zero_guard_count() {
        let mut req = valid_request();
        req.guard_count = 0;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Guard count"));
    }

    #[test]
    fn create_request_rejects_negative_guard_count() {
        let mut req = valid_request();
        req.guard_count = -1;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Guard count"));
    }

    #[test]
    fn create_request_rejects_21_guard_count() {
        let mut req = valid_request();
        req.guard_count = 21;
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("Guard count"));
    }

    #[test]
    fn create_request_accepts_boundary_guard_counts() {
        let mut req = valid_request();
        req.guard_count = 1;
        assert!(validate_create_request(&req).is_ok());
        req.guard_count = 20;
        assert!(validate_create_request(&req).is_ok());
    }

    // --- offered_price validation ---

    #[test]
    fn create_request_rejects_negative_price() {
        let mut req = valid_request();
        req.offered_price = Some(-1.0);
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("price"));
    }

    #[test]
    fn create_request_rejects_nan_price() {
        let mut req = valid_request();
        req.offered_price = Some(f64::NAN);
        // NaN fails both the negativity check (NaN < 0.0 is false) and
        // the Decimal::try_from conversion
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("price") || format!("{err:?}").contains("Invalid"));
    }

    #[test]
    fn create_request_rejects_infinity_price() {
        let mut req = valid_request();
        req.offered_price = Some(f64::INFINITY);
        let err = validate_create_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("price") || format!("{err:?}").contains("Invalid"));
    }

    #[test]
    fn create_request_accepts_zero_price() {
        let mut req = valid_request();
        req.offered_price = Some(0.0);
        assert!(validate_create_request(&req).is_ok());
    }

    #[test]
    fn create_request_accepts_valid_price() {
        let mut req = valid_request();
        req.offered_price = Some(500.50);
        assert!(validate_create_request(&req).is_ok());
    }

    // --- sanitize_coords ---

    #[test]
    fn sanitize_coords_rejects_out_of_range() {
        assert_eq!(sanitize_coords(Some(91.0), Some(0.0)), (None, None));
        assert_eq!(sanitize_coords(Some(0.0), Some(181.0)), (None, None));
    }

    #[test]
    fn sanitize_coords_rejects_zero_zero() {
        assert_eq!(sanitize_coords(Some(0.0), Some(0.0)), (None, None));
    }

    #[test]
    fn sanitize_coords_accepts_valid() {
        assert_eq!(
            sanitize_coords(Some(13.75), Some(100.5)),
            (Some(13.75), Some(100.5))
        );
    }

    #[test]
    fn sanitize_coords_returns_none_for_none_input() {
        assert_eq!(sanitize_coords(None, None), (None, None));
        assert_eq!(sanitize_coords(Some(13.0), None), (None, None));
        assert_eq!(sanitize_coords(None, Some(100.0)), (None, None));
    }

    // =========================================================================
    // validate_payment_request — security hotfix C1 regression guard
    // =========================================================================

    use crate::models::CreatePaymentDto;

    fn valid_payment() -> CreatePaymentDto {
        CreatePaymentDto {
            request_id: Uuid::new_v4(),
            amount: Decimal::new(150000, 2), // ฿1500.00
            payment_method: "promptpay".to_string(),
        }
    }

    #[test]
    fn payment_accepts_valid_amount() {
        assert!(validate_payment_request(&valid_payment()).is_ok());
    }

    #[test]
    fn payment_rejects_zero_amount() {
        let mut req = valid_payment();
        req.amount = Decimal::ZERO;
        let err = validate_payment_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("positive"));
    }

    #[test]
    fn payment_rejects_negative_amount() {
        let mut req = valid_payment();
        req.amount = Decimal::new(-100, 2); // -฿1.00
        let err = validate_payment_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("positive"));
    }

    #[test]
    fn payment_rejects_invalid_method() {
        let mut req = valid_payment();
        req.payment_method = "bitcoin".to_string();
        let err = validate_payment_request(&req).unwrap_err();
        assert!(format!("{err:?}").contains("payment method"));
    }

    #[test]
    fn payment_accepts_all_valid_methods() {
        for method in ["promptpay", "credit_card", "debit_card", "mobile_banking"] {
            let mut req = valid_payment();
            req.payment_method = method.to_string();
            assert!(
                validate_payment_request(&req).is_ok(),
                "method {method} should be accepted"
            );
        }
    }

    // =========================================================================
    // validate_service_rate — review findings M3 + L4
    // =========================================================================

    #[test]
    fn service_rate_accepts_typical_values() {
        assert!(validate_service_rate(rust_decimal::Decimal::from(150), 6).is_ok());
    }

    #[test]
    fn service_rate_accepts_zero_base_fee() {
        // Free service (promo/trial) is a legitimate use case.
        assert!(validate_service_rate(rust_decimal::Decimal::ZERO, 6).is_ok());
    }

    #[test]
    fn service_rate_rejects_negative_base_fee() {
        let err = validate_service_rate(rust_decimal::Decimal::from(-1), 6).unwrap_err();
        assert!(format!("{err:?}").contains("negative"));
    }

    #[test]
    fn service_rate_rejects_base_fee_above_cap() {
        let err =
            validate_service_rate(rust_decimal::Decimal::from(MAX_BASE_FEE + 1), 6).unwrap_err();
        assert!(format!("{err:?}").contains("exceed"));
    }

    #[test]
    fn service_rate_accepts_base_fee_at_cap() {
        assert!(validate_service_rate(rust_decimal::Decimal::from(MAX_BASE_FEE), 6).is_ok());
    }

    #[test]
    fn service_rate_rejects_zero_min_hours() {
        let err = validate_service_rate(rust_decimal::Decimal::from(100), 0).unwrap_err();
        assert!(format!("{err:?}").contains("Min hours"));
    }

    #[test]
    fn service_rate_rejects_negative_min_hours() {
        let err = validate_service_rate(rust_decimal::Decimal::from(100), -5).unwrap_err();
        assert!(format!("{err:?}").contains("Min hours"));
    }

    #[test]
    fn service_rate_rejects_min_hours_over_24() {
        let err = validate_service_rate(rust_decimal::Decimal::from(100), 25).unwrap_err();
        assert!(format!("{err:?}").contains("Min hours"));
    }

    #[test]
    fn service_rate_accepts_min_hours_boundary() {
        assert!(validate_service_rate(rust_decimal::Decimal::from(100), 1).is_ok());
        assert!(validate_service_rate(rust_decimal::Decimal::from(100), 24).is_ok());
    }
}
