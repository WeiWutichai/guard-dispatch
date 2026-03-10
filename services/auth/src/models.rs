use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use shared::models::{ApprovalStatus, UserRole};
use utoipa::ToSchema;
use uuid::Uuid;

// =============================================================================
// Request DTOs
// =============================================================================

#[derive(Debug, Deserialize, ToSchema)]
pub struct RegisterRequest {
    pub email: String,
    pub phone: String,
    pub password: String,
    pub full_name: String,
    #[serde(default = "default_role")]
    pub role: UserRole,
}

fn default_role() -> UserRole {
    UserRole::Customer
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct PhoneLoginRequest {
    pub phone: String,
    pub password: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct RefreshRequest {
    #[serde(default)]
    pub refresh_token: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateProfileRequest {
    pub full_name: Option<String>,
    pub phone: Option<String>,
    pub avatar_url: Option<String>,
}

// =============================================================================
// Response DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct AuthResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in: i64,
    /// The authenticated user's role (e.g. "guard", "customer", "admin").
    pub role: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: String,
    pub phone: String,
    pub full_name: String,
    pub role: Option<UserRole>,
    pub avatar_url: Option<String>,
    pub is_active: bool,
    pub approval_status: ApprovalStatus,
    pub created_at: DateTime<Utc>,
    /// Customer-only: company name from customer_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub company_name: Option<String>,
    /// Customer-only: contact phone from customer_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub contact_phone: Option<String>,
    /// Guard-only: gender from guard_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gender: Option<String>,
    /// Guard-only: date of birth (ISO date string) from guard_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub date_of_birth: Option<String>,
    /// Guard-only: years of experience from guard_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub years_of_experience: Option<i32>,
    /// Guard-only: previous workplace from guard_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub previous_workplace: Option<String>,
    /// Customer-only: address from customer_profiles.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub customer_address: Option<String>,
    /// Customer profile approval status (separate from user approval_status).
    /// Present when the user has submitted a customer profile.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub customer_approval_status: Option<ApprovalStatus>,
}

// =============================================================================
// Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct UserRow {
    pub id: Uuid,
    pub email: String,
    pub phone: String,
    pub password_hash: String,
    pub full_name: String,
    pub role: Option<UserRole>,
    pub avatar_url: Option<String>,
    pub is_active: bool,
    pub approval_status: ApprovalStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<UserRow> for UserResponse {
    fn from(row: UserRow) -> Self {
        Self {
            id: row.id,
            email: row.email,
            phone: row.phone,
            full_name: row.full_name,
            role: row.role,
            avatar_url: row.avatar_url,
            is_active: row.is_active,
            approval_status: row.approval_status,
            created_at: row.created_at,
            company_name: None,
            contact_phone: None,
            gender: None,
            date_of_birth: None,
            years_of_experience: None,
            previous_workplace: None,
            customer_address: None,
            customer_approval_status: None,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct SessionRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
}

// =============================================================================
// OTP DTOs
// =============================================================================

#[derive(Debug, Deserialize, ToSchema)]
pub struct RequestOtpRequest {
    pub phone: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct RequestOtpResponse {
    pub message: String,
    pub expires_in: i64,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct VerifyOtpRequest {
    pub phone: String,
    pub code: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct VerifyOtpResponse {
    pub phone_verified_token: String,
    pub message: String,
}

/// Registration request using a verified phone token (after OTP verification).
///
/// For mobile phone-only registration, only `phone_verified_token` is required.
/// Role is optional — when omitted the account is created without a role
/// ("ยังไม่ได้ระบุ" in the admin UI) until the user completes onboarding.
#[derive(Debug, Deserialize, ToSchema)]
pub struct RegisterWithOtpRequest {
    pub phone_verified_token: String,
    pub password: Option<String>,
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub role: Option<UserRole>,
}

/// Response for a successful OTP-based registration (HTTP 202 Accepted).
///
/// The account is created with `approval_status = pending`. The user cannot
/// log in until an admin approves the account. No access/refresh tokens are issued.
///
/// For guard registrations only: a short-lived `profile_token` (15 min) is returned
/// so the mobile app can immediately submit the guard's profile data (experience,
/// documents, bank info) via `POST /profile/guard`.
#[derive(Debug, Serialize, ToSchema)]
pub struct RegisterWithOtpResponse {
    pub message: String,
    pub user_id: Uuid,
    /// Short-lived JWT for guard profile submission only (guard role only, 15 min TTL).
    /// Null for non-guard registrations.
    pub profile_token: Option<String>,
}

// =============================================================================
// Admin DTOs
// =============================================================================

/// Query parameters for listing users (admin endpoint).
#[derive(Debug, Deserialize, ToSchema)]
pub struct ListUsersQuery {
    pub role: Option<String>,
    pub approval_status: Option<String>,
    pub search: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// Request body for updating a user's approval status.
#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateApprovalStatusRequest {
    pub approval_status: ApprovalStatus,
}

/// Paginated list of users.
#[derive(Debug, Serialize, ToSchema)]
pub struct PaginatedUsers {
    pub users: Vec<UserResponse>,
    pub total: i64,
}

// =============================================================================
// Profile Token Reissue DTOs
// =============================================================================

/// Request to reissue a profile_token for a pending user who already passed OTP.
/// `role` determines the token purpose (`"guard_profile"` or `"customer_profile"`).
/// Defaults to guard when omitted (backward compatibility).
#[derive(Debug, Deserialize, ToSchema)]
pub struct ReissueProfileTokenRequest {
    pub phone: String,
    /// Optional role to determine profile token purpose. Defaults to guard.
    pub role: Option<UserRole>,
}

/// Response containing a fresh profile_token.
#[derive(Debug, Serialize, ToSchema)]
pub struct ReissueProfileTokenResponse {
    pub profile_token: String,
    pub message: String,
}

// =============================================================================
// Update Role DTOs (step 2 of 3-step registration)
// =============================================================================

/// Request to set the role of a pending user (registered with role=null).
/// Public endpoint — user identified by phone (no JWT, they have no tokens yet).
#[derive(Debug, Deserialize, ToSchema)]
pub struct UpdateRoleRequest {
    pub phone: String,
    pub role: UserRole,
}

/// Response after successfully setting a user's role.
/// Includes profile_token for both guard and customer profile submission.
#[derive(Debug, Serialize, ToSchema)]
pub struct UpdateRoleResponse {
    pub message: String,
    pub user_id: Uuid,
    /// Short-lived JWT (15 min) for profile submission (guard or customer).
    pub profile_token: Option<String>,
}

// =============================================================================
// Guard Profile DTOs
// =============================================================================

/// Guard profile data submitted immediately after OTP registration.
/// Sent as multipart/form-data alongside document image files.
#[derive(Debug, Default)]
pub struct GuardProfileFormData {
    pub full_name: Option<String>,
    pub gender: Option<String>,
    pub date_of_birth: Option<String>, // ISO date string "YYYY-MM-DD"
    pub years_of_experience: Option<i32>,
    pub previous_workplace: Option<String>,
    pub bank_name: Option<String>,
    pub account_number: Option<String>,
    pub account_name: Option<String>,
}

/// Guard profile as stored in `auth.guard_profiles`.
#[derive(Debug, sqlx::FromRow)]
pub struct GuardProfileRow {
    pub user_id: Uuid,
    pub gender: Option<String>,
    pub date_of_birth: Option<chrono::NaiveDate>,
    pub years_of_experience: Option<i32>,
    pub previous_workplace: Option<String>,
    pub id_card_key: Option<String>,
    pub security_license_key: Option<String>,
    pub training_cert_key: Option<String>,
    pub criminal_check_key: Option<String>,
    pub driver_license_key: Option<String>,
    pub bank_name: Option<String>,
    pub account_number: Option<String>,
    pub account_name: Option<String>,
    pub passbook_photo_key: Option<String>,
}

/// Guard profile response returned to the admin (document keys replaced with signed URLs).
#[derive(Debug, Serialize, ToSchema)]
pub struct GuardProfileResponse {
    pub user_id: Uuid,
    pub gender: Option<String>,
    pub date_of_birth: Option<String>,
    pub years_of_experience: Option<i32>,
    pub previous_workplace: Option<String>,
    pub id_card_url: Option<String>,
    pub security_license_url: Option<String>,
    pub training_cert_url: Option<String>,
    pub criminal_check_url: Option<String>,
    pub driver_license_url: Option<String>,
    pub bank_name: Option<String>,
    pub account_number: Option<String>,
    pub account_name: Option<String>,
    pub passbook_photo_url: Option<String>,
}

// =============================================================================
// Customer Profile DTOs
// =============================================================================

/// Customer profile data submitted after role selection.
/// Sent as JSON (no file uploads).
#[derive(Debug, Deserialize, ToSchema)]
pub struct SubmitCustomerProfileRequest {
    pub full_name: Option<String>,
    pub contact_phone: Option<String>,
    pub email: Option<String>,
    pub company_name: Option<String>,
    pub address: String,
}

/// Customer profile as stored in `auth.customer_profiles`.
#[derive(Debug, sqlx::FromRow)]
pub struct CustomerProfileRow {
    pub user_id: Uuid,
    pub full_name: Option<String>,
    pub contact_phone: Option<String>,
    pub email: Option<String>,
    pub company_name: Option<String>,
    pub address: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Customer profile response returned to admin (JOIN users + customer_profiles).
#[derive(Debug, Serialize, ToSchema)]
pub struct CustomerProfileResponse {
    pub user_id: Uuid,
    pub full_name: String,
    pub contact_phone: Option<String>,
    pub email: Option<String>,
    pub company_name: Option<String>,
    pub address: String,
    pub approval_status: ApprovalStatus,
    pub created_at: DateTime<Utc>,
}

// =============================================================================
// OTP Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct OtpRow {
    pub id: Uuid,
    pub phone: String,
    pub code: String,
    pub purpose: String,
    pub is_used: bool,
    pub attempts: i32,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}
