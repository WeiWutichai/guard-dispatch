use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// =============================================================================
// Enums (matching PostgreSQL enums)
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type)]
#[sqlx(type_name = "request_status", rename_all = "snake_case")]
pub enum RequestStatus {
    Pending,
    Assigned,
    InProgress,
    Completed,
    Cancelled,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type)]
#[sqlx(type_name = "urgency_level", rename_all = "lowercase")]
pub enum UrgencyLevel {
    Low,
    Medium,
    High,
    Critical,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type)]
#[sqlx(type_name = "assignment_status", rename_all = "snake_case")]
pub enum AssignmentStatus {
    Assigned,
    EnRoute,
    Arrived,
    Completed,
    Cancelled,
}

// =============================================================================
// Request DTOs
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct CreateRequestDto {
    pub location_lat: f64,
    pub location_lng: f64,
    pub address: String,
    pub description: Option<String>,
    #[serde(default = "default_urgency")]
    pub urgency: UrgencyLevel,
}

fn default_urgency() -> UrgencyLevel {
    UrgencyLevel::Medium
}

#[derive(Debug, Deserialize)]
pub struct AssignGuardDto {
    pub guard_id: Uuid,
}

#[derive(Debug, Deserialize)]
pub struct UpdateAssignmentStatusDto {
    pub status: AssignmentStatus,
}

#[derive(Debug, Deserialize)]
pub struct ListRequestsQuery {
    pub status: Option<RequestStatus>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// =============================================================================
// Response DTOs
// =============================================================================

#[derive(Debug, Serialize)]
pub struct GuardRequestResponse {
    pub id: Uuid,
    pub customer_id: Uuid,
    pub location_lat: f64,
    pub location_lng: f64,
    pub address: String,
    pub description: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct AssignmentResponse {
    pub id: Uuid,
    pub request_id: Uuid,
    pub guard_id: Uuid,
    pub status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

// =============================================================================
// Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct GuardRequestRow {
    pub id: Uuid,
    pub customer_id: Uuid,
    pub location_lat: f64,
    pub location_lng: f64,
    pub address: String,
    pub description: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<GuardRequestRow> for GuardRequestResponse {
    fn from(row: GuardRequestRow) -> Self {
        Self {
            id: row.id,
            customer_id: row.customer_id,
            location_lat: row.location_lat,
            location_lng: row.location_lng,
            address: row.address,
            description: row.description,
            status: row.status,
            urgency: row.urgency,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct AssignmentRow {
    pub id: Uuid,
    pub request_id: Uuid,
    pub guard_id: Uuid,
    pub status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

impl From<AssignmentRow> for AssignmentResponse {
    fn from(row: AssignmentRow) -> Self {
        Self {
            id: row.id,
            request_id: row.request_id,
            guard_id: row.guard_id,
            status: row.status,
            assigned_at: row.assigned_at,
            arrived_at: row.arrived_at,
            completed_at: row.completed_at,
        }
    }
}
