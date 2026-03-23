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

impl GpsUpdate {
    /// Validate GPS coordinates are within valid ranges.
    pub fn validate(&self) -> Result<(), &'static str> {
        if !(-90.0..=90.0).contains(&self.lat) {
            return Err("lat must be between -90 and 90");
        }
        if !(-180.0..=180.0).contains(&self.lng) {
            return Err("lng must be between -180 and 180");
        }
        if self.lat == 0.0 && self.lng == 0.0 {
            return Err("lat/lng at (0,0) is likely invalid");
        }
        if let Some(acc) = self.accuracy {
            if acc < 0.0 || acc > 10_000.0 {
                return Err("accuracy must be between 0 and 10000 meters");
            }
        }
        if let Some(heading) = self.heading {
            if heading < 0.0 || heading > 360.0 {
                return Err("heading must be between 0 and 360 degrees");
            }
        }
        if let Some(speed) = self.speed {
            if speed < 0.0 || speed > 500.0 {
                return Err("speed must be between 0 and 500 m/s");
            }
        }
        Ok(())
    }
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

/// All guard locations with name (for admin map view)
#[derive(Debug, Serialize, ToSchema)]
pub struct GuardLocationWithName {
    pub guard_id: Uuid,
    pub full_name: Option<String>,
    pub lat: f64,
    pub lng: f64,
    pub accuracy: Option<f32>,
    pub heading: Option<f32>,
    pub speed: Option<f32>,
    pub recorded_at: DateTime<Utc>,
    pub is_online: bool,
}

#[derive(Debug, sqlx::FromRow)]
pub struct GuardLocationWithNameRow {
    pub guard_id: Uuid,
    pub full_name: Option<String>,
    pub lat: f64,
    pub lng: f64,
    pub accuracy: Option<f32>,
    pub heading: Option<f32>,
    pub speed: Option<f32>,
    pub recorded_at: DateTime<Utc>,
    pub is_online: bool,
}

impl From<GuardLocationWithNameRow> for GuardLocationWithName {
    fn from(row: GuardLocationWithNameRow) -> Self {
        Self {
            guard_id: row.guard_id,
            full_name: row.full_name,
            lat: row.lat,
            lng: row.lng,
            accuracy: row.accuracy,
            heading: row.heading,
            speed: row.speed,
            recorded_at: row.recorded_at,
            is_online: row.is_online,
        }
    }
}

// =============================================================================
// Query params
// =============================================================================

#[derive(Debug, Deserialize, IntoParams)]
pub struct LocationsQuery {
    pub online_only: Option<bool>,
}

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
