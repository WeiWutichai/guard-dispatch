use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

// =============================================================================
// WebSocket Messages
// =============================================================================

/// GPS update received from guard's device via WebSocket
#[derive(Debug, Deserialize, Serialize, Clone, ToSchema)]
pub struct GpsUpdate {
    pub lat: f64,
    pub lng: f64,
    pub accuracy: Option<f32>,
    pub heading: Option<f32>,
    pub speed: Option<f32>,
    pub assignment_id: Option<Uuid>,
}

/// Outgoing WebSocket message to subscribers
#[derive(Debug, Serialize, Clone, ToSchema)]
pub struct GpsEvent {
    pub guard_id: Uuid,
    pub lat: f64,
    pub lng: f64,
    pub accuracy: Option<f32>,
    pub heading: Option<f32>,
    pub speed: Option<f32>,
    pub recorded_at: DateTime<Utc>,
}

// =============================================================================
// REST Response DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct LocationResponse {
    pub guard_id: Uuid,
    pub lat: f64,
    pub lng: f64,
    pub accuracy: Option<f32>,
    pub heading: Option<f32>,
    pub speed: Option<f32>,
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct LocationHistoryResponse {
    pub id: Uuid,
    pub guard_id: Uuid,
    pub assignment_id: Option<Uuid>,
    pub lat: f64,
    pub lng: f64,
    pub recorded_at: DateTime<Utc>,
}

// =============================================================================
// Query params
// =============================================================================

#[derive(Debug, Deserialize, IntoParams)]
pub struct HistoryQuery {
    pub assignment_id: Option<Uuid>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// =============================================================================
// Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct GuardLocationRow {
    pub id: Uuid,
    pub guard_id: Uuid,
    pub lat: f64,
    pub lng: f64,
    pub accuracy: Option<f32>,
    pub heading: Option<f32>,
    pub speed: Option<f32>,
    pub recorded_at: DateTime<Utc>,
}

impl From<GuardLocationRow> for LocationResponse {
    fn from(row: GuardLocationRow) -> Self {
        Self {
            guard_id: row.guard_id,
            lat: row.lat,
            lng: row.lng,
            accuracy: row.accuracy,
            heading: row.heading,
            speed: row.speed,
            recorded_at: row.recorded_at,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct LocationHistoryRow {
    pub id: Uuid,
    pub guard_id: Uuid,
    pub assignment_id: Option<Uuid>,
    pub lat: f64,
    pub lng: f64,
    pub recorded_at: DateTime<Utc>,
}

impl From<LocationHistoryRow> for LocationHistoryResponse {
    fn from(row: LocationHistoryRow) -> Self {
        Self {
            id: row.id,
            guard_id: row.guard_id,
            assignment_id: row.assignment_id,
            lat: row.lat,
            lng: row.lng,
            recorded_at: row.recorded_at,
        }
    }
}
