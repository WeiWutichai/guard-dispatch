use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    GpsEvent, GpsUpdate, GuardLocationRow, GuardLocationWithName, GuardLocationWithNameRow,
    HistoryQuery, LocationHistoryResponse, LocationHistoryRow, LocationResponse,
};

// =============================================================================
// Authorization helpers
// =============================================================================

/// Check if a customer has an active (non-cancelled, non-declined) booking with a guard.
pub async fn has_active_booking(
    db: &PgPool,
    customer_id: Uuid,
    guard_id: Uuid,
) -> Result<bool, AppError> {
    let exists = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS(
            SELECT 1
            FROM booking.assignments a
            INNER JOIN booking.guard_requests r ON r.id = a.request_id
            WHERE r.customer_id = $1
              AND a.guard_id = $2
              AND a.status NOT IN ('cancelled', 'declined')
        )
        "#,
    )
    .bind(customer_id)
    .bind(guard_id)
    .fetch_one(db)
    .await?;

    Ok(exists)
}

// =============================================================================
// Upsert Guard Location (latest position)
// =============================================================================

pub async fn upsert_location(
    db: &PgPool,
    guard_id: Uuid,
    update: &GpsUpdate,
) -> Result<(), AppError> {
    sqlx::query(
        r#"
        INSERT INTO tracking.guard_locations (guard_id, lat, lng, accuracy, heading, speed, recorded_at, is_online)
        VALUES ($1, $2, $3, $4, $5, $6, NOW(), true)
        ON CONFLICT (guard_id)
        DO UPDATE SET
            lat = EXCLUDED.lat,
            lng = EXCLUDED.lng,
            accuracy = EXCLUDED.accuracy,
            heading = EXCLUDED.heading,
            speed = EXCLUDED.speed,
            recorded_at = NOW(),
            is_online = true
        "#,
    )
    .bind(guard_id)
    .bind(update.lat)
    .bind(update.lng)
    .bind(update.accuracy)
    .bind(update.heading)
    .bind(update.speed)
    .execute(db)
    .await?;

    Ok(())
}

/// Mark guard as online when WebSocket connects.
/// Uses UPSERT so a guard connecting for the first time (no prior GPS row) gets a default row.
/// lat/lng default to 0 — will be overwritten by the first real GPS update.
pub async fn set_online(db: &PgPool, guard_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        r#"
        INSERT INTO tracking.guard_locations (guard_id, lat, lng, recorded_at, is_online)
        VALUES ($1, 0, 0, NOW(), true)
        ON CONFLICT (guard_id)
        DO UPDATE SET is_online = true, recorded_at = NOW()
        "#,
    )
    .bind(guard_id)
    .execute(db)
    .await?;
    Ok(())
}

/// Mark guard as offline when WebSocket disconnects.
pub async fn set_offline(db: &PgPool, guard_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE tracking.guard_locations SET is_online = false WHERE guard_id = $1",
    )
    .bind(guard_id)
    .execute(db)
    .await?;
    Ok(())
}

// =============================================================================
// Append to Location History
// NOTE: location_history grows unbounded. In production, set up a scheduled
// job (pg_cron or external) to DELETE rows older than a retention period
// (e.g., 90 days) to prevent table bloat.
// =============================================================================

pub async fn append_history(
    db: &PgPool,
    guard_id: Uuid,
    update: &GpsUpdate,
) -> Result<(), AppError> {
    sqlx::query(
        r#"
        INSERT INTO tracking.location_history
            (guard_id, assignment_id, lat, lng, accuracy, heading, speed, recorded_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        "#,
    )
    .bind(guard_id)
    .bind(update.assignment_id)
    .bind(update.lat)
    .bind(update.lng)
    .bind(update.accuracy)
    .bind(update.heading)
    .bind(update.speed)
    .execute(db)
    .await?;

    Ok(())
}

// =============================================================================
// Publish GPS event to Redis PubSub
// =============================================================================

/// Publish GPS event to Redis PubSub using a pre-established multiplexed connection.
/// Clone of `MultiplexedConnection` is cheap — shares the underlying connection.
pub async fn publish_gps_event(
    redis: &redis::aio::MultiplexedConnection,
    event: &GpsEvent,
) -> Result<(), AppError> {
    let mut conn = redis.clone();

    let channel = format!("gps:{}", event.guard_id);
    let payload = serde_json::to_string(event)
        .map_err(|e| AppError::Internal(format!("Failed to serialize GPS event: {e}")))?;

    conn.publish::<_, _, ()>(&channel, &payload)
        .await
        .map_err(AppError::Redis)?;

    Ok(())
}

// =============================================================================
// Get Latest Location
// =============================================================================

pub async fn get_latest_location(
    db: &PgPool,
    guard_id: Uuid,
) -> Result<LocationResponse, AppError> {
    let row = sqlx::query_as::<_, GuardLocationRow>(
        r#"
        SELECT id, guard_id, lat, lng, accuracy, heading, speed, recorded_at
        FROM tracking.guard_locations
        WHERE guard_id = $1
        "#,
    )
    .bind(guard_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("No location found for guard".to_string()))?;

    Ok(LocationResponse::from(row))
}

// =============================================================================
// Get Location History
// =============================================================================

pub async fn get_location_history(
    db: &PgPool,
    guard_id: Uuid,
    query: HistoryQuery,
) -> Result<Vec<LocationHistoryResponse>, AppError> {
    let limit = query.limit.unwrap_or(100).min(1000);
    let offset = query.offset.unwrap_or(0);

    let rows = match query.assignment_id {
        Some(assignment_id) => {
            sqlx::query_as::<_, LocationHistoryRow>(
                r#"
                SELECT id, guard_id, assignment_id, lat, lng, recorded_at
                FROM tracking.location_history
                WHERE guard_id = $1 AND assignment_id = $2
                ORDER BY recorded_at DESC
                LIMIT $3 OFFSET $4
                "#,
            )
            .bind(guard_id)
            .bind(assignment_id)
            .bind(limit)
            .bind(offset)
            .fetch_all(db)
            .await?
        }
        None => {
            sqlx::query_as::<_, LocationHistoryRow>(
                r#"
                SELECT id, guard_id, assignment_id, lat, lng, recorded_at
                FROM tracking.location_history
                WHERE guard_id = $1
                ORDER BY recorded_at DESC
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

    Ok(rows.into_iter().map(LocationHistoryResponse::from).collect())
}

// =============================================================================
// Get All Guard Locations (admin map view)
// =============================================================================

pub async fn get_all_locations(
    db: &PgPool,
    online_only: bool,
) -> Result<Vec<GuardLocationWithName>, AppError> {
    let rows = if online_only {
        sqlx::query_as::<_, GuardLocationWithNameRow>(
            r#"
            SELECT gl.guard_id, u.full_name,
                   gl.lat, gl.lng, gl.accuracy, gl.heading, gl.speed,
                   gl.recorded_at, gl.is_online,
                   EXISTS(
                       SELECT 1 FROM booking.assignments ba
                       WHERE ba.guard_id = gl.guard_id
                         AND ba.status IN ('pending_acceptance','accepted','en_route','arrived','pending_completion')
                   ) AS has_active_job
            FROM tracking.guard_locations gl
            INNER JOIN auth.users u ON u.id = gl.guard_id
            WHERE u.role = 'guard' AND u.is_active = true AND u.approval_status = 'approved'
              AND gl.is_online = true
            ORDER BY gl.recorded_at DESC
            "#,
        )
        .fetch_all(db)
        .await?
    } else {
        sqlx::query_as::<_, GuardLocationWithNameRow>(
            r#"
            SELECT gl.guard_id, u.full_name,
                   gl.lat, gl.lng, gl.accuracy, gl.heading, gl.speed,
                   gl.recorded_at, gl.is_online,
                   EXISTS(
                       SELECT 1 FROM booking.assignments ba
                       WHERE ba.guard_id = gl.guard_id
                         AND ba.status IN ('pending_acceptance','accepted','en_route','arrived','pending_completion')
                   ) AS has_active_job
            FROM tracking.guard_locations gl
            INNER JOIN auth.users u ON u.id = gl.guard_id
            WHERE u.role = 'guard' AND u.is_active = true AND u.approval_status = 'approved'
            ORDER BY gl.recorded_at DESC
            "#,
        )
        .fetch_all(db)
        .await?
    };

    Ok(rows.into_iter().map(GuardLocationWithName::from).collect())
}
