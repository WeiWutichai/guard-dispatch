use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    GpsEvent, GpsUpdate, GuardLocationRow, HistoryQuery, LocationHistoryResponse,
    LocationHistoryRow, LocationResponse,
};

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
        INSERT INTO tracking.guard_locations (guard_id, lat, lng, accuracy, heading, speed, recorded_at)
        VALUES ($1, $2, $3, $4, $5, $6, NOW())
        ON CONFLICT (guard_id)
        DO UPDATE SET
            lat = EXCLUDED.lat,
            lng = EXCLUDED.lng,
            accuracy = EXCLUDED.accuracy,
            heading = EXCLUDED.heading,
            speed = EXCLUDED.speed,
            recorded_at = NOW()
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
        INSERT INTO tracking.location_history (guard_id, assignment_id, lat, lng, recorded_at)
        VALUES ($1, $2, $3, $4, NOW())
        "#,
    )
    .bind(guard_id)
    .bind(update.assignment_id)
    .bind(update.lat)
    .bind(update.lng)
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
