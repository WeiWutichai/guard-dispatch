use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

// =============================================================================
// Enums (matching PostgreSQL enums)
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "request_status", rename_all = "snake_case")]
pub enum RequestStatus {
    Pending,
    Assigned,
    InProgress,
    Completed,
    Cancelled,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type, ToSchema)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "urgency_level", rename_all = "lowercase")]
pub enum UrgencyLevel {
    Low,
    Medium,
    High,
    Critical,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
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

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateRequestDto {
    pub location_lat: f64,
    pub location_lng: f64,
    pub address: String,
    pub description: Option<String>,
    pub offered_price: Option<f64>,
    pub special_instructions: Option<String>,
    #[serde(default = "default_urgency")]
    pub urgency: UrgencyLevel,
}

fn default_urgency() -> UrgencyLevel {
    UrgencyLevel::Medium
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct AssignGuardDto {
    pub guard_id: Uuid,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateAssignmentStatusDto {
    pub status: AssignmentStatus,
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListRequestsQuery {
    pub status: Option<RequestStatus>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// =============================================================================
// Response DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct GuardRequestResponse {
    pub id: Uuid,
    pub customer_id: Uuid,
    pub location_lat: f64,
    pub location_lng: f64,
    pub address: String,
    pub description: Option<String>,
    pub offered_price: Option<f64>,
    pub special_instructions: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
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
    pub offered_price: Option<rust_decimal::Decimal>,
    pub special_instructions: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<GuardRequestRow> for GuardRequestResponse {
    fn from(row: GuardRequestRow) -> Self {
        use rust_decimal::prelude::ToPrimitive;
        Self {
            id: row.id,
            customer_id: row.customer_id,
            location_lat: row.location_lat,
            location_lng: row.location_lng,
            address: row.address,
            description: row.description,
            offered_price: row.offered_price.and_then(|d| d.to_f64()),
            special_instructions: row.special_instructions,
            status: row.status,
            urgency: row.urgency,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}

// =============================================================================
// Guard-specific DTOs (enriched with customer name + assignment info)
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct GuardJobResponse {
    pub id: Uuid,
    pub customer_id: Uuid,
    pub customer_name: String,
    pub address: String,
    pub description: Option<String>,
    pub special_instructions: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub offered_price: Option<f64>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub assignment_id: Uuid,
    pub assignment_status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct GuardJobRow {
    pub id: Uuid,
    pub customer_id: Uuid,
    pub customer_name: Option<String>,
    pub address: String,
    pub description: Option<String>,
    pub special_instructions: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub offered_price: Option<rust_decimal::Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub assignment_id: Uuid,
    pub assignment_status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

impl From<GuardJobRow> for GuardJobResponse {
    fn from(row: GuardJobRow) -> Self {
        use rust_decimal::prelude::ToPrimitive;
        Self {
            id: row.id,
            customer_id: row.customer_id,
            customer_name: row.customer_name.unwrap_or_else(|| "-".to_string()),
            address: row.address,
            description: row.description,
            special_instructions: row.special_instructions,
            status: row.status,
            urgency: row.urgency,
            offered_price: row.offered_price.and_then(|d| d.to_f64()),
            created_at: row.created_at,
            updated_at: row.updated_at,
            assignment_id: row.assignment_id,
            assignment_status: row.assignment_status,
            assigned_at: row.assigned_at,
            arrived_at: row.arrived_at,
            completed_at: row.completed_at,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct GuardDashboardSummary {
    pub today_jobs_count: i64,
    pub today_earnings: f64,
    pub week_earnings: f64,
    pub active_job: Option<GuardJobResponse>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct GuardEarnings {
    pub total_earned: f64,
    pub month_earnings: f64,
    pub week_earnings: f64,
    pub completed_jobs_count: i64,
    pub daily_breakdown: Vec<DailyEarning>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct DailyEarning {
    pub date: NaiveDate,
    pub amount: f64,
    pub jobs_count: i64,
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

// =============================================================================
// Guard Work History DTOs
// =============================================================================

#[derive(Debug, Deserialize, IntoParams)]
pub struct GuardJobsQuery {
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct WorkHistoryResponse {
    pub total_jobs: i64,
    pub total_hours: f64,
    pub avg_rating: Option<f64>,
    pub jobs: Vec<WorkHistoryItem>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct WorkHistoryItem {
    pub id: Uuid,
    pub assignment_id: Uuid,
    pub customer_name: String,
    pub address: String,
    pub description: Option<String>,
    pub offered_price: Option<f64>,
    pub assignment_status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub duration_minutes: Option<i64>,
    pub rating: Option<f64>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct WorkHistoryRow {
    pub id: Uuid,
    pub assignment_id: Uuid,
    pub customer_name: Option<String>,
    pub address: String,
    pub description: Option<String>,
    pub offered_price: Option<rust_decimal::Decimal>,
    pub assignment_status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub duration_minutes: Option<i64>,
    pub rating: Option<rust_decimal::Decimal>,
}

impl From<WorkHistoryRow> for WorkHistoryItem {
    fn from(row: WorkHistoryRow) -> Self {
        use rust_decimal::prelude::ToPrimitive;
        Self {
            id: row.id,
            assignment_id: row.assignment_id,
            customer_name: row.customer_name.unwrap_or_else(|| "-".to_string()),
            address: row.address,
            description: row.description,
            offered_price: row.offered_price.and_then(|d| d.to_f64()),
            assignment_status: row.assignment_status,
            assigned_at: row.assigned_at,
            arrived_at: row.arrived_at,
            completed_at: row.completed_at,
            duration_minutes: row.duration_minutes,
            rating: row.rating.and_then(|d| d.to_f64()),
        }
    }
}

// =============================================================================
// Guard Ratings DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct GuardRatingsSummary {
    pub overall_rating: Option<f64>,
    pub total_reviews: i64,
    pub punctuality: Option<f64>,
    pub professionalism: Option<f64>,
    pub communication: Option<f64>,
    pub appearance: Option<f64>,
    pub recent_reviews: Vec<ReviewItem>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ReviewItem {
    pub id: Uuid,
    pub customer_name: String,
    pub overall_rating: f64,
    pub review_text: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct ReviewRow {
    pub id: Uuid,
    pub customer_name: Option<String>,
    pub overall_rating: rust_decimal::Decimal,
    pub review_text: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct RatingSummaryRow {
    pub overall_rating: Option<rust_decimal::Decimal>,
    pub total_reviews: Option<i64>,
    pub punctuality: Option<rust_decimal::Decimal>,
    pub professionalism: Option<rust_decimal::Decimal>,
    pub communication: Option<rust_decimal::Decimal>,
    pub appearance: Option<rust_decimal::Decimal>,
}
