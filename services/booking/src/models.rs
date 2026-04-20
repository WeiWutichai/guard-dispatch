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
    PendingAcceptance,
    Assigned,
    Accepted,
    AwaitingPayment,
    Declined,
    EnRoute,
    Arrived,
    PendingCompletion,
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
    pub booked_hours: Option<i32>,
    /// Number of guards to hire for this booking. Defaults to 1 so legacy
    /// clients that don't send this field keep working. Server validates
    /// 1..=20; anything outside is rejected with BadRequest.
    #[serde(default = "default_guard_count")]
    pub guard_count: i32,
}

fn default_urgency() -> UrgencyLevel {
    UrgencyLevel::Medium
}

fn default_guard_count() -> i32 {
    1
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct AssignGuardDto {
    pub guard_id: Uuid,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateAssignmentStatusDto {
    pub status: AssignmentStatus,
    pub lat: Option<f64>,
    pub lng: Option<f64>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListRequestsQuery {
    pub status: Option<RequestStatus>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct AcceptDeclineDto {
    pub accept: bool,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct StartJobDto {
    pub lat: Option<f64>,
    pub lng: Option<f64>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct ReviewCompletionDto {
    pub approve: bool,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreatePaymentDto {
    pub request_id: Uuid,
    #[schema(value_type = f64)]
    pub amount: rust_decimal::Decimal,
    pub payment_method: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct AddTipDto {
    /// Extra amount the customer wants to give the guard on top of the
    /// (possibly prorated) final price. Must be > 0.
    #[schema(value_type = f64)]
    pub amount: rust_decimal::Decimal,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateReviewDto {
    #[schema(value_type = f64)]
    pub overall_rating: rust_decimal::Decimal,
    #[schema(value_type = Option<f64>)]
    pub punctuality: Option<rust_decimal::Decimal>,
    #[schema(value_type = Option<f64>)]
    pub professionalism: Option<rust_decimal::Decimal>,
    #[schema(value_type = Option<f64>)]
    pub communication: Option<rust_decimal::Decimal>,
    #[schema(value_type = Option<f64>)]
    pub appearance: Option<rust_decimal::Decimal>,
    pub review_text: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct SubmitReviewResponse {
    pub id: Uuid,
    pub message: String,
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
    pub booked_hours: Option<i32>,
    pub guard_count: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub assignment_status: Option<AssignmentStatus>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AssignmentResponse {
    pub id: Uuid,
    pub request_id: Uuid,
    pub guard_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub guard_name: Option<String>,
    pub status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub started_at: Option<DateTime<Utc>>,
    pub completion_requested_at: Option<DateTime<Utc>>,
    // Check-in location data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_place: Option<String>,
    // Review data (if reviewed)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_overall_rating: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_punctuality: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_professionalism: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_communication: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_appearance: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_text: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct PaymentResponse {
    pub id: Uuid,
    pub request_id: Uuid,
    pub customer_id: Uuid,
    #[schema(value_type = f64)]
    pub amount: rust_decimal::Decimal,
    pub payment_method: String,
    pub status: String,
    pub paid_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    /// Hours actually worked (clamped to booked_hours). NULL until job completes.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[schema(value_type = Option<f64>)]
    pub actual_hours_worked: Option<rust_decimal::Decimal>,
    /// Prorated price the customer actually owes after job completion.
    /// Equals `amount * (actual_hours / booked_hours)`. NULL until job completes.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[schema(value_type = Option<f64>)]
    pub final_amount: Option<rust_decimal::Decimal>,
    /// Difference customer overpaid (`amount - final_amount`). Recorded for the
    /// admin refund flow — no real refund is processed by this service.
    #[serde(skip_serializing_if = "Option::is_none")]
    #[schema(value_type = Option<f64>)]
    pub refund_amount: Option<rust_decimal::Decimal>,
    /// Optional bonus the customer added on the completion-summary screen.
    #[schema(value_type = f64)]
    pub tip_amount: rust_decimal::Decimal,
}

/// Cost breakdown returned by `GET /assignments/{id}/cost-summary`.
/// Designed to drive the customer's job-completion screen.
#[derive(Debug, Serialize, ToSchema)]
pub struct CostSummaryResponse {
    pub assignment_id: Uuid,
    pub request_id: Uuid,
    pub status: AssignmentStatus,

    /// Hours the customer originally booked (e.g. 4).
    pub booked_hours: i32,
    /// Hours the guard actually worked (clamped to booked_hours).
    /// `None` while the job is still active.
    #[schema(value_type = Option<f64>)]
    pub actual_hours_worked: Option<rust_decimal::Decimal>,

    /// Original amount the customer paid upfront.
    #[schema(value_type = f64)]
    pub original_amount: rust_decimal::Decimal,
    /// Prorated final price after the job ends. Equals `original_amount`
    /// when the guard finishes the full booked time.
    #[schema(value_type = Option<f64>)]
    pub final_amount: Option<rust_decimal::Decimal>,
    /// Amount to refund to the customer (computed; admin processes the
    /// real refund). Always >= 0.
    #[schema(value_type = Option<f64>)]
    pub refund_amount: Option<rust_decimal::Decimal>,

    /// Optional tip the customer added.
    #[schema(value_type = f64)]
    pub tip_amount: rust_decimal::Decimal,

    /// Net amount charged to the customer = `final_amount + tip_amount`
    /// (after refund). Useful for UI display.
    #[schema(value_type = Option<f64>)]
    pub net_amount: Option<rust_decimal::Decimal>,

    /// Hourly rate derived from `original_amount / booked_hours`. Helps the
    /// UI explain the proration math to the customer.
    #[schema(value_type = Option<f64>)]
    pub hourly_rate: Option<rust_decimal::Decimal>,

    pub started_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,

    pub payment_id: Uuid,
}

// =============================================================================
// Customer receipts — past payments for completed jobs
// =============================================================================

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListReceiptsQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ReceiptItem {
    pub payment_id: Uuid,
    pub request_id: Uuid,
    pub assignment_id: Option<Uuid>,
    /// Human-friendly receipt number — `RCP-YYYY-XXXXXXXX` where X is
    /// the first 8 hex chars of the payment UUID (uppercase). Derived,
    /// not stored, so no migration needed.
    pub receipt_no: String,
    pub service_address: String,
    pub guard_name: Option<String>,
    pub guard_avatar_url: Option<String>,
    pub booked_hours: Option<i32>,
    #[schema(value_type = Option<f64>)]
    pub actual_hours_worked: Option<rust_decimal::Decimal>,
    #[schema(value_type = f64)]
    pub original_amount: rust_decimal::Decimal,
    #[schema(value_type = Option<f64>)]
    pub final_amount: Option<rust_decimal::Decimal>,
    #[schema(value_type = Option<f64>)]
    pub refund_amount: Option<rust_decimal::Decimal>,
    #[schema(value_type = f64)]
    pub tip_amount: rust_decimal::Decimal,
    /// What the customer actually paid end-to-end =
    /// `(final_amount ?? original_amount) + tip_amount`.
    #[schema(value_type = f64)]
    pub net_amount: rust_decimal::Decimal,
    pub payment_method: String,
    pub started_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub paid_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ReceiptsPage {
    pub data: Vec<ReceiptItem>,
    pub total: i64,
}

// =============================================================================
// Admin refund workflow — migration 042
// =============================================================================

/// Query params for `GET /admin/refunds`.
#[derive(Debug, Deserialize, IntoParams)]
pub struct AdminRefundsQuery {
    /// Filter by refund_status — `"pending"`, `"processed"`, or `"skipped"`.
    /// Omit to see all (any non-NULL refund_status).
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// Query params for `GET /admin/payments` — broader view including payments
/// without refund rows.
#[derive(Debug, Deserialize, IntoParams)]
pub struct AdminPaymentsQuery {
    /// Filter by `payments.status` (`"completed"`, `"pending"`, `"failed"`).
    pub status: Option<String>,
    /// Filter by `payment_method` exact match.
    pub method: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// Body for `PUT /admin/refunds/{id}/process`.
#[derive(Debug, Deserialize, ToSchema)]
pub struct ProcessRefundRequest {
    /// Action: `"process"` → admin confirmed transfer; `"skip"` → won't refund.
    pub action: String,
    /// Bank transaction reference / slip number. Required when action=process.
    #[serde(default)]
    pub reference: Option<String>,
    /// Optional admin note (shown alongside the audit trail).
    #[serde(default)]
    pub note: Option<String>,
}

/// Single row in the admin refund / payment tables.
#[derive(Debug, Serialize, ToSchema)]
pub struct AdminPaymentItem {
    pub payment_id: Uuid,
    pub request_id: Uuid,
    pub assignment_id: Option<Uuid>,
    pub customer_id: Uuid,
    pub customer_name: Option<String>,
    pub guard_id: Option<Uuid>,
    pub guard_name: Option<String>,
    pub service_address: String,
    pub booked_hours: Option<i32>,
    #[schema(value_type = Option<f64>)]
    pub actual_hours_worked: Option<rust_decimal::Decimal>,
    #[schema(value_type = f64)]
    pub original_amount: rust_decimal::Decimal,
    #[schema(value_type = Option<f64>)]
    pub final_amount: Option<rust_decimal::Decimal>,
    #[schema(value_type = Option<f64>)]
    pub refund_amount: Option<rust_decimal::Decimal>,
    #[schema(value_type = f64)]
    pub tip_amount: rust_decimal::Decimal,
    pub payment_method: String,
    pub payment_status: String,
    /// One of `"pending"`, `"processed"`, `"skipped"`, or NULL if no refund owed.
    pub refund_status: Option<String>,
    pub refund_processed_at: Option<DateTime<Utc>>,
    pub refund_reference: Option<String>,
    pub refund_processed_by: Option<Uuid>,
    pub refund_processed_by_name: Option<String>,
    pub paid_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AdminPaymentsPage {
    pub data: Vec<AdminPaymentItem>,
    pub total: i64,
}

/// High-level stats used by the admin wallet overview card.
#[derive(Debug, Serialize, ToSchema)]
pub struct WalletSummary {
    /// Sum of `net_amount` (final + tip) for payments paid in the current calendar month.
    #[schema(value_type = f64)]
    pub monthly_revenue: rust_decimal::Decimal,
    /// Count + sum of refund_amount for rows with refund_status='pending'.
    pub pending_refunds_count: i64,
    #[schema(value_type = f64)]
    pub pending_refunds_total: rust_decimal::Decimal,
    /// Count + sum of refund_amount for rows with refund_status='processed'
    /// AND refund_processed_at in the current calendar month.
    pub processed_refunds_count: i64,
    #[schema(value_type = f64)]
    pub processed_refunds_total: rust_decimal::Decimal,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ActiveJobResponse {
    pub assignment_id: Uuid,
    pub request_id: Uuid,
    pub customer_id: Uuid,
    pub customer_name: String,
    pub address: String,
    pub booked_hours: i32,
    pub started_at: Option<DateTime<Utc>>,
    pub remaining_seconds: Option<i64>,
    pub assignment_status: AssignmentStatus,
    pub offered_price: Option<f64>,
    pub completion_requested_at: Option<DateTime<Utc>>,
    // Check-in location data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_place: Option<String>,
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
    pub booked_hours: Option<i32>,
    pub guard_count: i32,
    pub assignment_status: Option<AssignmentStatus>,
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
            booked_hours: row.booked_hours,
            guard_count: row.guard_count,
            assignment_status: row.assignment_status,
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
    pub customer_phone: Option<String>,
    pub location_lat: Option<f64>,
    pub location_lng: Option<f64>,
    pub address: String,
    pub description: Option<String>,
    pub special_instructions: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub offered_price: Option<f64>,
    pub booked_hours: Option<i32>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub assignment_id: Uuid,
    pub assignment_status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub started_at: Option<DateTime<Utc>>,
    // Check-in location data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub en_route_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub arrived_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_place: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_lat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_lng: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completion_place: Option<String>,
    // Review data (if reviewed)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_overall_rating: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_punctuality: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_professionalism: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_communication: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_appearance: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review_text: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct GuardJobRow {
    pub id: Uuid,
    pub customer_id: Uuid,
    pub customer_name: Option<String>,
    pub customer_phone: Option<String>,
    pub location_lat: Option<f64>,
    pub location_lng: Option<f64>,
    pub address: String,
    pub description: Option<String>,
    pub special_instructions: Option<String>,
    pub status: RequestStatus,
    pub urgency: UrgencyLevel,
    pub offered_price: Option<rust_decimal::Decimal>,
    pub booked_hours: Option<i32>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub assignment_id: Uuid,
    pub assignment_status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub started_at: Option<DateTime<Utc>>,
    // Check-in location data
    pub en_route_at: Option<DateTime<Utc>>,
    pub en_route_lat: Option<f64>,
    pub en_route_lng: Option<f64>,
    pub arrived_lat: Option<f64>,
    pub arrived_lng: Option<f64>,
    pub en_route_place: Option<String>,
    pub arrived_place: Option<String>,
    pub started_lat: Option<f64>,
    pub started_lng: Option<f64>,
    pub started_place: Option<String>,
    pub completion_lat: Option<f64>,
    pub completion_lng: Option<f64>,
    pub completion_place: Option<String>,
    // Review data
    pub review_overall_rating: Option<f64>,
    pub review_punctuality: Option<f64>,
    pub review_professionalism: Option<f64>,
    pub review_communication: Option<f64>,
    pub review_appearance: Option<f64>,
    pub review_text: Option<String>,
}

impl From<GuardJobRow> for GuardJobResponse {
    fn from(row: GuardJobRow) -> Self {
        use rust_decimal::prelude::ToPrimitive;
        Self {
            id: row.id,
            customer_id: row.customer_id,
            customer_name: row.customer_name.unwrap_or_else(|| "-".to_string()),
            customer_phone: row.customer_phone,
            location_lat: row.location_lat,
            location_lng: row.location_lng,
            address: row.address,
            description: row.description,
            special_instructions: row.special_instructions,
            status: row.status,
            urgency: row.urgency,
            offered_price: row.offered_price.and_then(|d| d.to_f64()),
            booked_hours: row.booked_hours,
            created_at: row.created_at,
            updated_at: row.updated_at,
            assignment_id: row.assignment_id,
            assignment_status: row.assignment_status,
            assigned_at: row.assigned_at,
            arrived_at: row.arrived_at,
            completed_at: row.completed_at,
            started_at: row.started_at,
            en_route_at: row.en_route_at,
            en_route_lat: row.en_route_lat,
            en_route_lng: row.en_route_lng,
            arrived_lat: row.arrived_lat,
            arrived_lng: row.arrived_lng,
            en_route_place: row.en_route_place,
            arrived_place: row.arrived_place,
            started_lat: row.started_lat,
            started_lng: row.started_lng,
            started_place: row.started_place,
            completion_lat: row.completion_lat,
            completion_lng: row.completion_lng,
            completion_place: row.completion_place,
            review_overall_rating: row.review_overall_rating,
            review_punctuality: row.review_punctuality,
            review_professionalism: row.review_professionalism,
            review_communication: row.review_communication,
            review_appearance: row.review_appearance,
            review_text: row.review_text,
        }
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct GuardDashboardSummary {
    pub today_jobs_count: i64,
    pub today_earnings: f64,
    pub week_earnings: f64,
    pub last_week_earnings: f64,
    pub pending_jobs_count: i64,
    pub pending_acceptance_count: i64,
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
    pub guard_name: Option<String>,
    pub status: AssignmentStatus,
    pub assigned_at: DateTime<Utc>,
    pub arrived_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub started_at: Option<DateTime<Utc>>,
    pub completion_requested_at: Option<DateTime<Utc>>,
    // Check-in location data
    pub en_route_at: Option<DateTime<Utc>>,
    pub en_route_lat: Option<f64>,
    pub en_route_lng: Option<f64>,
    pub arrived_lat: Option<f64>,
    pub arrived_lng: Option<f64>,
    pub en_route_place: Option<String>,
    pub arrived_place: Option<String>,
    pub started_lat: Option<f64>,
    pub started_lng: Option<f64>,
    pub started_place: Option<String>,
    pub completion_lat: Option<f64>,
    pub completion_lng: Option<f64>,
    pub completion_place: Option<String>,
    // Review data
    pub review_overall_rating: Option<f64>,
    pub review_punctuality: Option<f64>,
    pub review_professionalism: Option<f64>,
    pub review_communication: Option<f64>,
    pub review_appearance: Option<f64>,
    pub review_text: Option<String>,
}

impl From<AssignmentRow> for AssignmentResponse {
    fn from(row: AssignmentRow) -> Self {
        Self {
            id: row.id,
            request_id: row.request_id,
            guard_id: row.guard_id,
            guard_name: row.guard_name,
            status: row.status,
            assigned_at: row.assigned_at,
            arrived_at: row.arrived_at,
            completed_at: row.completed_at,
            started_at: row.started_at,
            completion_requested_at: row.completion_requested_at,
            en_route_at: row.en_route_at,
            en_route_lat: row.en_route_lat,
            en_route_lng: row.en_route_lng,
            arrived_lat: row.arrived_lat,
            arrived_lng: row.arrived_lng,
            en_route_place: row.en_route_place,
            arrived_place: row.arrived_place,
            started_lat: row.started_lat,
            started_lng: row.started_lng,
            started_place: row.started_place,
            completion_lat: row.completion_lat,
            completion_lng: row.completion_lng,
            completion_place: row.completion_place,
            review_overall_rating: row.review_overall_rating,
            review_punctuality: row.review_punctuality,
            review_professionalism: row.review_professionalism,
            review_communication: row.review_communication,
            review_appearance: row.review_appearance,
            review_text: row.review_text,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct PaymentRow {
    pub id: Uuid,
    pub request_id: Uuid,
    pub customer_id: Uuid,
    pub amount: rust_decimal::Decimal,
    pub payment_method: String,
    pub status: String,
    pub paid_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub actual_hours_worked: Option<rust_decimal::Decimal>,
    pub final_amount: Option<rust_decimal::Decimal>,
    pub refund_amount: Option<rust_decimal::Decimal>,
    pub tip_amount: rust_decimal::Decimal,
}

impl From<PaymentRow> for PaymentResponse {
    fn from(row: PaymentRow) -> Self {
        Self {
            id: row.id,
            request_id: row.request_id,
            customer_id: row.customer_id,
            amount: row.amount,
            payment_method: row.payment_method,
            status: row.status,
            paid_at: row.paid_at,
            created_at: row.created_at,
            actual_hours_worked: row.actual_hours_worked,
            final_amount: row.final_amount,
            refund_amount: row.refund_amount,
            tip_amount: row.tip_amount,
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

// =============================================================================
// Admin Reviews (admin-only listing across all guards)
// =============================================================================

#[derive(Debug, Deserialize, IntoParams)]
pub struct AdminReviewsQuery {
    /// Filter by guard user_id
    pub guard_id: Option<Uuid>,
    /// Filter by exact star rating (1-5)
    pub rating: Option<i32>,
    /// Filter by visibility status: true | false
    pub is_visible: Option<bool>,
    /// Free-text search on customer_name / guard_name / review_text
    pub search: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AdminReviewResponse {
    pub id: Uuid,
    pub assignment_id: Uuid,
    pub request_id: Uuid,
    pub customer_id: Uuid,
    pub customer_name: Option<String>,
    pub guard_id: Uuid,
    pub guard_name: Option<String>,
    pub overall_rating: f64,
    pub punctuality: Option<f64>,
    pub professionalism: Option<f64>,
    pub communication: Option<f64>,
    pub appearance: Option<f64>,
    pub review_text: Option<String>,
    pub address: Option<String>,
    pub is_visible: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct AdminReviewRow {
    pub id: Uuid,
    pub assignment_id: Uuid,
    pub request_id: Uuid,
    pub customer_id: Uuid,
    pub customer_name: Option<String>,
    pub guard_id: Uuid,
    pub guard_name: Option<String>,
    pub overall_rating: rust_decimal::Decimal,
    pub punctuality: Option<rust_decimal::Decimal>,
    pub professionalism: Option<rust_decimal::Decimal>,
    pub communication: Option<rust_decimal::Decimal>,
    pub appearance: Option<rust_decimal::Decimal>,
    pub review_text: Option<String>,
    pub address: Option<String>,
    pub is_visible: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct PaginatedAdminReviews {
    pub data: Vec<AdminReviewResponse>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
    pub stats: AdminReviewStats,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AdminReviewStats {
    pub total: i64,
    pub visible: i64,
    pub avg_rating: f64,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct ToggleReviewVisibilityDto {
    pub is_visible: bool,
}

// =============================================================================
// Service Rates (Pricing)
// =============================================================================

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow, ToSchema)]
pub struct ServiceRate {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    #[schema(value_type = f64)]
    pub base_fee: rust_decimal::Decimal,
    pub min_hours: i32,
    pub notes: Option<String>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateServiceRateDto {
    pub name: String,
    pub description: Option<String>,
    #[schema(value_type = f64)]
    pub base_fee: rust_decimal::Decimal,
    pub min_hours: Option<i32>,
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateServiceRateDto {
    pub name: Option<String>,
    pub description: Option<String>,
    #[schema(value_type = Option<f64>)]
    pub base_fee: Option<rust_decimal::Decimal>,
    pub min_hours: Option<i32>,
    pub notes: Option<String>,
    pub is_active: Option<bool>,
}

// =============================================================================
// Available Guards (customer-facing guard discovery)
// =============================================================================

#[derive(Debug, Deserialize, IntoParams)]
pub struct AvailableGuardsQuery {
    /// Customer request latitude
    pub lat: f64,
    /// Customer request longitude
    pub lng: f64,
    /// Search radius in km (default 50)
    pub radius_km: Option<f64>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AvailableGuardResponse {
    pub id: Uuid,
    pub full_name: String,
    pub avatar_url: Option<String>,
    pub experience_years: Option<i32>,
    pub lat: f64,
    pub lng: f64,
    pub distance_km: f64,
    pub last_seen_at: DateTime<Utc>,
    pub completed_jobs: i64,
    pub rating: f64,
    pub review_count: i64,
}

#[derive(Debug, sqlx::FromRow)]
pub struct AvailableGuardRow {
    pub id: Uuid,
    pub full_name: String,
    pub avatar_url: Option<String>,
    pub experience_years: Option<i32>,
    pub lat: f64,
    pub lng: f64,
    pub distance_km: f64,
    pub last_seen_at: DateTime<Utc>,
    pub completed_jobs: Option<i64>,
    pub rating: Option<f64>,
    pub review_count: Option<i64>,
}

impl From<AvailableGuardRow> for AvailableGuardResponse {
    fn from(row: AvailableGuardRow) -> Self {
        Self {
            id: row.id,
            full_name: row.full_name,
            avatar_url: row.avatar_url,
            experience_years: row.experience_years,
            lat: row.lat,
            lng: row.lng,
            distance_km: row.distance_km,
            last_seen_at: row.last_seen_at,
            completed_jobs: row.completed_jobs.unwrap_or(0),
            rating: row.rating.unwrap_or(0.0),
            review_count: row.review_count.unwrap_or(0),
        }
    }
}

// =============================================================================
// Progress Reports
// =============================================================================

/// DB row for progress_reports table
#[derive(Debug, sqlx::FromRow)]
pub struct ProgressReportRow {
    pub id: Uuid,
    pub assignment_id: Uuid,
    pub guard_id: Uuid,
    pub hour_number: i32,
    pub message: Option<String>,
    pub photo_file_key: Option<String>,
    pub photo_mime_type: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// DB row for progress_report_media table
#[allow(dead_code)]
#[derive(Debug, sqlx::FromRow)]
pub struct ProgressReportMediaRow {
    pub id: Uuid,
    pub report_id: Uuid,
    pub file_key: String,
    pub mime_type: String,
    pub file_size: i32,
    pub sort_order: i32,
    pub created_at: DateTime<Utc>,
}

/// A single media item in the API response
#[derive(Debug, Serialize, ToSchema)]
pub struct ProgressReportMediaItem {
    pub id: Uuid,
    pub url: String,
    pub mime_type: String,
    pub file_size: i32,
    pub sort_order: i32,
}

/// API response for progress reports
#[derive(Debug, Serialize, ToSchema)]
pub struct ProgressReportResponse {
    pub id: Uuid,
    pub assignment_id: Uuid,
    pub guard_id: Uuid,
    pub hour_number: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    /// Legacy single photo URL (backward compat — first image in media)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub photo_url: Option<String>,
    /// All media items (photos + videos) for this report
    pub media: Vec<ProgressReportMediaItem>,
    pub created_at: DateTime<Utc>,
}
