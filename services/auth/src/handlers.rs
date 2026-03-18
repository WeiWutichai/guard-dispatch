use axum::extract::{Multipart, Path, Query, State};
use axum::http::header::SET_COOKIE;
use axum::http::{HeaderMap, StatusCode};
use axum::Json;
use std::collections::HashMap;
use std::sync::Arc;
use uuid::Uuid;

use shared::auth::{
    build_clear_cookie, build_cookie, AuthUser, ACCESS_TOKEN_COOKIE, REFRESH_TOKEN_COOKIE,
};
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    AuthResponse, CustomerProfileResponse, GuardProfileFormData, GuardProfileResponse, PublicGuardProfileResponse,
    ListUsersQuery, LoginRequest, PaginatedUsers, PhoneLoginRequest, RefreshRequest,
    RegisterRequest, RegisterWithOtpRequest, RegisterWithOtpResponse,
    ReissueProfileTokenRequest, ReissueProfileTokenResponse, RequestOtpRequest,
    RequestOtpResponse, SubmitCustomerProfileRequest, UpdateApprovalStatusRequest,
    UpdateProfileRequest, UpdateRoleRequest, UpdateRoleResponse, UserResponse,
    VerifyOtpRequest, VerifyOtpResponse,
};
use crate::state::AppState;

/// Helper: build Set-Cookie headers for access + refresh tokens + logged_in marker.
fn auth_cookie_headers(auth: &AuthResponse) -> HeaderMap {
    let mut headers = HeaderMap::new();

    // Access token cookie — httpOnly, Secure
    let access_cookie = build_cookie(
        ACCESS_TOKEN_COOKIE,
        &auth.access_token,
        auth.expires_in,
        "/",
    );
    headers.append(SET_COOKIE, access_cookie.parse().expect("valid cookie"));

    // Refresh token cookie — httpOnly, Secure, restricted to /auth path
    let refresh_cookie = build_cookie(
        REFRESH_TOKEN_COOKIE,
        &auth.refresh_token,
        30 * 24 * 3600,
        "/auth",
    );
    headers.append(SET_COOKIE, refresh_cookie.parse().expect("valid cookie"));

    // Non-httpOnly marker cookie for the frontend to detect auth state
    // This does NOT contain any sensitive data — just "1"
    // Must include Secure flag to prevent leaking auth state over plain HTTP
    let marker_cookie = format!(
        "logged_in=1; Secure; SameSite=Lax; Path=/; Max-Age={}",
        auth.expires_in
    );
    headers.append(SET_COOKIE, marker_cookie.parse().expect("valid cookie"));

    headers
}

#[utoipa::path(
    post,
    path = "/register",
    tag = "Auth",
    request_body = RegisterRequest,
    responses(
        (status = 200, description = "User registered successfully", body = UserResponse),
        (status = 400, description = "Validation error", body = ErrorBody),
        (status = 409, description = "Email already exists", body = ErrorBody),
    ),
)]
pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let user = crate::service::register(&state.db, req).await?;
    Ok(Json(ApiResponse::success(user)))
}

#[utoipa::path(
    post,
    path = "/login",
    tag = "Auth",
    request_body = LoginRequest,
    responses(
        (status = 200, description = "Login successful, tokens returned", body = AuthResponse),
        (status = 401, description = "Invalid credentials", body = ErrorBody),
    ),
)]
pub async fn login(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<LoginRequest>,
) -> Result<(HeaderMap, Json<ApiResponse<AuthResponse>>), AppError> {
    let ip_address = headers
        .get("X-Real-IP")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());
    let device_info = headers
        .get("User-Agent")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let auth = crate::service::login(
        &state.db,
        &state.redis,
        &state.jwt_config,
        req,
        ip_address,
        device_info,
    )
    .await?;

    let cookie_headers = auth_cookie_headers(&auth);
    Ok((cookie_headers, Json(ApiResponse::success(auth))))
}

#[utoipa::path(
    post,
    path = "/login/phone",
    tag = "Auth",
    request_body = PhoneLoginRequest,
    responses(
        (status = 200, description = "Login successful, tokens returned", body = AuthResponse),
        (status = 401, description = "Invalid credentials", body = ErrorBody),
    ),
)]
pub async fn phone_login(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<PhoneLoginRequest>,
) -> Result<(HeaderMap, Json<ApiResponse<AuthResponse>>), AppError> {
    let ip_address = headers
        .get("X-Real-IP")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());
    let device_info = headers
        .get("User-Agent")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let auth = crate::service::login_with_phone(
        &state.db,
        &state.redis,
        &state.jwt_config,
        req,
        ip_address,
        device_info,
    )
    .await?;

    let cookie_headers = auth_cookie_headers(&auth);
    Ok((cookie_headers, Json(ApiResponse::success(auth))))
}

#[utoipa::path(
    post,
    path = "/refresh",
    tag = "Auth",
    request_body = RefreshRequest,
    responses(
        (status = 200, description = "Token refreshed successfully", body = AuthResponse),
        (status = 400, description = "Missing refresh token", body = ErrorBody),
        (status = 401, description = "Invalid or expired refresh token", body = ErrorBody),
    ),
)]
pub async fn refresh_token(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<RefreshRequest>,
) -> Result<(HeaderMap, Json<ApiResponse<AuthResponse>>), AppError> {
    // Accept refresh_token from body or cookie
    let refresh_tok = if req.refresh_token.is_empty() {
        // Try to read from cookie
        headers
            .get("Cookie")
            .and_then(|v| v.to_str().ok())
            .and_then(|cookies| {
                cookies
                    .split(';')
                    .map(|s| s.trim())
                    .find_map(|pair| {
                        let (key, value) = pair.split_once('=')?;
                        if key.trim() == REFRESH_TOKEN_COOKIE {
                            Some(value.trim().to_string())
                        } else {
                            None
                        }
                    })
            })
            .unwrap_or_default()
    } else {
        req.refresh_token.clone()
    };

    if refresh_tok.is_empty() {
        return Err(AppError::BadRequest("refresh_token is required".to_string()));
    }

    let auth = crate::service::refresh_token(
        &state.db,
        &state.redis,
        &state.jwt_config,
        &refresh_tok,
    )
    .await?;

    let cookie_headers = auth_cookie_headers(&auth);
    Ok((cookie_headers, Json(ApiResponse::success(auth))))
}

#[utoipa::path(
    get,
    path = "/me",
    tag = "Profile",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "User profile retrieved", body = UserResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn get_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let profile = crate::service::get_profile(&state.db, &state.redis, user.user_id).await?;
    Ok(Json(ApiResponse::success(profile)))
}

#[utoipa::path(
    put,
    path = "/me",
    tag = "Profile",
    security(("bearer" = [])),
    request_body = UpdateProfileRequest,
    responses(
        (status = 200, description = "Profile updated", body = UserResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn update_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<UpdateProfileRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    let profile =
        crate::service::update_profile(&state.db, &state.redis, user.user_id, req).await?;
    Ok(Json(ApiResponse::success(profile)))
}

#[utoipa::path(
    post,
    path = "/logout",
    tag = "Auth",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "Logged out, cookies cleared"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn logout(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<(HeaderMap, Json<ApiResponse<()>>), AppError> {
    crate::service::logout(&state.db, &state.redis, user.user_id).await?;

    // Clear auth cookies
    let mut headers = HeaderMap::new();
    let clear_access = build_clear_cookie(ACCESS_TOKEN_COOKIE, "/");
    headers.append(SET_COOKIE, clear_access.parse().expect("valid cookie"));
    let clear_refresh = build_clear_cookie(REFRESH_TOKEN_COOKIE, "/auth");
    headers.append(SET_COOKIE, clear_refresh.parse().expect("valid cookie"));
    // Clear the logged_in marker cookie (must include Secure to match the set cookie)
    let clear_marker = "logged_in=; Secure; SameSite=Lax; Path=/; Max-Age=0".to_string();
    headers.append(SET_COOKIE, clear_marker.parse().expect("valid cookie"));

    Ok((headers, Json(ApiResponse::success(()))))
}

// =============================================================================
// OTP Handlers
// =============================================================================

#[utoipa::path(
    post,
    path = "/otp/request",
    tag = "OTP",
    request_body = RequestOtpRequest,
    responses(
        (status = 200, description = "OTP sent successfully", body = RequestOtpResponse),
        (status = 400, description = "Invalid phone or rate limited", body = ErrorBody),
    ),
)]
pub async fn request_otp(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RequestOtpRequest>,
) -> Result<Json<ApiResponse<RequestOtpResponse>>, AppError> {
    let response = crate::service::request_otp(
        &state.db,
        &state.redis,
        &state.sms_config,
        &state.otp_config,
        &state.http_client,
        &req.phone,
    )
    .await?;
    Ok(Json(ApiResponse::success(response)))
}

#[utoipa::path(
    post,
    path = "/otp/verify",
    tag = "OTP",
    request_body = VerifyOtpRequest,
    responses(
        (status = 200, description = "OTP verified, phone_verified_token returned", body = VerifyOtpResponse),
        (status = 400, description = "Invalid or expired OTP", body = ErrorBody),
    ),
)]
pub async fn verify_otp(
    State(state): State<Arc<AppState>>,
    Json(req): Json<VerifyOtpRequest>,
) -> Result<Json<ApiResponse<VerifyOtpResponse>>, AppError> {
    let response = crate::service::verify_otp(
        &state.db,
        &state.redis,
        &state.jwt_config,
        &state.otp_config,
        &req.phone,
        &req.code,
    )
    .await?;
    Ok(Json(ApiResponse::success(response)))
}

#[utoipa::path(
    post,
    path = "/register/otp",
    tag = "Auth",
    request_body = RegisterWithOtpRequest,
    responses(
        (status = 202, description = "Account created — pending admin approval. No tokens issued.", body = RegisterWithOtpResponse),
        (status = 400, description = "Validation error or invalid token", body = ErrorBody),
        (status = 409, description = "Email or phone already exists", body = ErrorBody),
    ),
)]
pub async fn register_with_otp(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterWithOtpRequest>,
) -> Result<(StatusCode, Json<ApiResponse<RegisterWithOtpResponse>>), AppError> {
    let response = crate::service::register_with_otp(
        &state.db,
        &state.redis,
        &state.jwt_config,
        req,
    )
    .await?;
    Ok((StatusCode::ACCEPTED, Json(ApiResponse::success(response))))
}

// =============================================================================
// Admin Handlers
// =============================================================================

#[utoipa::path(
    get,
    path = "/users",
    tag = "Admin",
    security(("bearer" = [])),
    params(
        ("role" = Option<String>, Query, description = "Filter by role (guard, customer)"),
        ("approval_status" = Option<String>, Query, description = "Filter by status (pending, approved, rejected)"),
        ("search" = Option<String>, Query, description = "Search by name, email, or phone"),
        ("limit" = Option<i64>, Query, description = "Page size (default 20, max 100)"),
        ("offset" = Option<i64>, Query, description = "Offset for pagination"),
    ),
    responses(
        (status = 200, description = "List of users", body = PaginatedUsers),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
    ),
)]
pub async fn list_users(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListUsersQuery>,
) -> Result<Json<ApiResponse<PaginatedUsers>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    let result = crate::service::list_users(&state.db, query).await?;
    Ok(Json(ApiResponse::success(result)))
}

#[utoipa::path(
    patch,
    path = "/users/{id}/approval",
    tag = "Admin",
    security(("bearer" = [])),
    params(
        ("id" = Uuid, Path, description = "User ID to update"),
    ),
    request_body = UpdateApprovalStatusRequest,
    responses(
        (status = 200, description = "Approval status updated", body = UserResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
        (status = 404, description = "User not found", body = ErrorBody),
    ),
)]
pub async fn update_approval_status(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateApprovalStatusRequest>,
) -> Result<Json<ApiResponse<UserResponse>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    let updated = crate::service::update_approval_status(&state.db, &state.redis, id, req).await?;
    Ok(Json(ApiResponse::success(updated)))
}

// =============================================================================
// Guard Profile Handlers
// =============================================================================

/// Submit guard profile data (multipart/form-data).
/// Requires `Authorization: Bearer <profile_token>` header (short-lived JWT issued at registration).
/// Accepts text fields and optional document image files.
pub async fn submit_guard_profile(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    mut multipart: Multipart,
) -> Result<(StatusCode, Json<shared::models::ApiResponse<()>>), AppError> {
    // Validate profile_token from Authorization header
    let token = headers
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or_else(|| AppError::Unauthorized("Missing profile token".to_string()))?;

    let user_id = crate::service::validate_profile_token(token, &state.jwt_config, &state.redis, "guard_profile").await?;

    let mut form = GuardProfileFormData::default();
    let mut files: HashMap<String, Vec<u8>> = HashMap::new();

    // Parse multipart fields
    while let Some(field) = multipart.next_field().await.map_err(|e| {
        AppError::BadRequest(format!("Multipart parse error: {e}"))
    })? {
        let name = field.name().unwrap_or("").to_string();
        match name.as_str() {
            "full_name" => {
                form.full_name = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            "gender" => {
                form.gender = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            "date_of_birth" => {
                form.date_of_birth = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            "years_of_experience" => {
                let s = field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?;
                form.years_of_experience = s.parse::<i32>().ok();
            }
            "previous_workplace" => {
                form.previous_workplace = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            "bank_name" => {
                form.bank_name = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            "account_number" => {
                form.account_number = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            "account_name" => {
                form.account_name = Some(field.text().await.map_err(|e| AppError::BadRequest(e.to_string()))?);
            }
            // Document image fields
            "id_card" | "security_license" | "training_cert" | "criminal_check" | "driver_license" | "passbook_photo" => {
                let data = field.bytes().await.map_err(|e| AppError::BadRequest(e.to_string()))?;
                if !data.is_empty() {
                    files.insert(name, data.to_vec());
                }
            }
            _ => {
                // Ignore unknown fields
            }
        }
    }

    crate::service::submit_guard_profile(
        &state.db,
        &state.redis,
        &state.s3_client,
        &state.s3_bucket,
        user_id,
        form,
        files,
    )
    .await?;

    Ok((StatusCode::OK, Json(shared::models::ApiResponse::success(()))))
}

/// Reissue a profile_token for a pending guard who already verified OTP.
/// Allows retry of guard profile submission without repeating the OTP flow.
#[utoipa::path(
    post,
    path = "/profile/reissue",
    tag = "Profile",
    request_body = ReissueProfileTokenRequest,
    responses(
        (status = 200, description = "New profile_token issued", body = ReissueProfileTokenResponse),
        (status = 400, description = "Invalid phone format", body = ErrorBody),
        (status = 404, description = "No pending registration found", body = ErrorBody),
    ),
)]
pub async fn reissue_profile_token(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ReissueProfileTokenRequest>,
) -> Result<Json<ApiResponse<ReissueProfileTokenResponse>>, AppError> {
    let token = crate::service::reissue_profile_token(
        &state.db,
        &state.jwt_config,
        &state.redis,
        &req.phone,
        req.role,
    )
    .await?;

    Ok(Json(ApiResponse::success(ReissueProfileTokenResponse {
        profile_token: token,
        message: "Profile token issued".to_string(),
    })))
}

/// Set the role of a pending user (step 2 of 3-step registration).
/// Public endpoint — user identified by phone (no JWT needed).
#[utoipa::path(
    post,
    path = "/profile/role",
    tag = "Profile",
    request_body = UpdateRoleRequest,
    responses(
        (status = 200, description = "Role updated successfully", body = UpdateRoleResponse),
        (status = 400, description = "Invalid phone/role or user already has a role", body = ErrorBody),
    ),
)]
pub async fn update_role(
    State(state): State<Arc<AppState>>,
    Json(req): Json<UpdateRoleRequest>,
) -> Result<Json<ApiResponse<UpdateRoleResponse>>, AppError> {
    let (user_id, profile_token) = crate::service::update_user_role(
        &state.db,
        &state.redis,
        &state.jwt_config,
        &req.phone,
        req.role,
    )
    .await?;

    Ok(Json(ApiResponse::success(UpdateRoleResponse {
        message: "Role updated successfully".to_string(),
        user_id,
        profile_token,
    })))
}

#[utoipa::path(
    get,
    path = "/admin/guard-profile/{user_id}",
    tag = "Admin",
    security(("bearer" = [])),
    params(
        ("user_id" = Uuid, Path, description = "Guard user ID"),
    ),
    responses(
        (status = 200, description = "Guard profile with signed document URLs", body = GuardProfileResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
        (status = 404, description = "Guard profile not found", body = ErrorBody),
    ),
)]
pub async fn get_guard_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(user_id): Path<Uuid>,
) -> Result<Json<shared::models::ApiResponse<GuardProfileResponse>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    let profile = crate::service::get_guard_profile(
        &state.db,
        &state.s3_client,
        &state.s3_bucket,
        &state.s3_endpoint,
        &state.s3_public_url,
        user_id,
    )
    .await?;

    Ok(Json(shared::models::ApiResponse::success(profile)))
}

// =============================================================================
// Public Guard Profile (any authenticated user — no bank info)
// =============================================================================

#[utoipa::path(
    get,
    path = "/guards/{user_id}/profile",
    tag = "Profile",
    security(("bearer" = [])),
    params(
        ("user_id" = Uuid, Path, description = "Guard user ID"),
    ),
    responses(
        (status = 200, description = "Public guard profile with document URLs", body = PublicGuardProfileResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 404, description = "Guard profile not found", body = ErrorBody),
    ),
)]
pub async fn get_public_guard_profile(
    State(state): State<Arc<AppState>>,
    _user: AuthUser,
    Path(user_id): Path<Uuid>,
) -> Result<Json<shared::models::ApiResponse<PublicGuardProfileResponse>>, AppError> {
    let full_profile = crate::service::get_guard_profile(
        &state.db,
        &state.s3_client,
        &state.s3_bucket,
        &state.s3_endpoint,
        &state.s3_public_url,
        user_id,
    )
    .await?;

    let public_profile: PublicGuardProfileResponse = full_profile.into();
    Ok(Json(shared::models::ApiResponse::success(public_profile)))
}

// =============================================================================
// Customer Profile Handlers
// =============================================================================

/// Submit customer profile (company name + address).
/// Authenticated via single-use `profile_token` (Bearer header).
#[utoipa::path(
    post,
    path = "/profile/customer",
    tag = "Profile",
    request_body = SubmitCustomerProfileRequest,
    responses(
        (status = 200, description = "Customer profile saved", body = ()),
        (status = 400, description = "Validation error", body = ErrorBody),
        (status = 401, description = "Invalid or expired profile token", body = ErrorBody),
    ),
)]
pub async fn submit_customer_profile(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<SubmitCustomerProfileRequest>,
) -> Result<Json<shared::models::ApiResponse<()>>, AppError> {
    // Extract Bearer token from Authorization header
    let token = headers
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or_else(|| AppError::Unauthorized("Missing profile token".to_string()))?;

    let user_id = crate::service::validate_profile_token(
        token,
        &state.jwt_config,
        &state.redis,
        "customer_profile",
    )
    .await?;

    crate::service::submit_customer_profile(&state.db, &state.redis, user_id, req).await?;

    Ok(Json(shared::models::ApiResponse::success(())))
}

/// Get a customer's full profile (admin only).
#[utoipa::path(
    get,
    path = "/admin/customer-profile/{user_id}",
    tag = "Admin",
    security(("bearer" = [])),
    params(
        ("user_id" = Uuid, Path, description = "Customer user ID"),
    ),
    responses(
        (status = 200, description = "Customer profile", body = CustomerProfileResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
        (status = 404, description = "Customer profile not found", body = ErrorBody),
    ),
)]
pub async fn get_customer_profile(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(user_id): Path<Uuid>,
) -> Result<Json<shared::models::ApiResponse<CustomerProfileResponse>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    let profile = crate::service::get_customer_profile(&state.db, user_id).await?;
    Ok(Json(shared::models::ApiResponse::success(profile)))
}

/// List customer applicants (users who have submitted a customer profile).
/// Uses customer_profiles.approval_status for filtering (not auth.users.approval_status).
#[utoipa::path(
    get,
    path = "/admin/customer-applicants",
    tag = "Admin",
    security(("bearer" = [])),
    params(
        ("approval_status" = Option<String>, Query, description = "Filter by customer profile status (pending, approved, rejected)"),
        ("search" = Option<String>, Query, description = "Search by name, email, or phone"),
        ("limit" = Option<i64>, Query, description = "Page size (default 20, max 100)"),
        ("offset" = Option<i64>, Query, description = "Offset for pagination"),
    ),
    responses(
        (status = 200, description = "List of customer applicants", body = PaginatedUsers),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
    ),
)]
pub async fn list_customer_applicants(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListUsersQuery>,
) -> Result<Json<shared::models::ApiResponse<PaginatedUsers>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    let result = crate::service::list_customer_applicants(&state.db, query).await?;
    Ok(Json(shared::models::ApiResponse::success(result)))
}

/// Update a customer profile's approval status (admin only).
#[utoipa::path(
    patch,
    path = "/admin/customer-profile/{user_id}/approval",
    tag = "Admin",
    security(("bearer" = [])),
    params(
        ("user_id" = Uuid, Path, description = "Customer user ID"),
    ),
    request_body = UpdateApprovalStatusRequest,
    responses(
        (status = 200, description = "Customer profile approval updated"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — admin only", body = ErrorBody),
        (status = 404, description = "Customer profile not found", body = ErrorBody),
    ),
)]
pub async fn update_customer_approval(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(user_id): Path<Uuid>,
    Json(req): Json<UpdateApprovalStatusRequest>,
) -> Result<Json<shared::models::ApiResponse<()>>, AppError> {
    if user.role != "admin" {
        return Err(AppError::Forbidden("Admin access required".to_string()));
    }

    crate::service::update_customer_approval_status(
        &state.db,
        &state.redis,
        user_id,
        req.approval_status,
    )
    .await?;
    Ok(Json(shared::models::ApiResponse::success(())))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_auth_response() -> AuthResponse {
        AuthResponse {
            access_token: "access-jwt-token".to_string(),
            refresh_token: "refresh-uuid-token".to_string(),
            token_type: "Bearer".to_string(),
            expires_in: 86400, // 24 hours
        }
    }

    #[test]
    fn auth_cookie_headers_sets_three_cookies() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers.get_all(SET_COOKIE).iter().collect();
        assert_eq!(cookies.len(), 3);
    }

    #[test]
    fn auth_cookie_headers_access_token_is_httponly() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let access = cookies.iter().find(|c| c.starts_with("access_token=")).unwrap();
        assert!(access.contains("HttpOnly"), "access_token must be HttpOnly");
        assert!(access.contains("Secure"), "access_token must be Secure");
        assert!(access.contains("SameSite=Lax"), "access_token must be SameSite=Lax");
        assert!(access.contains("Path=/"), "access_token must have Path=/");
    }

    #[test]
    fn auth_cookie_headers_refresh_token_restricted_to_auth_path() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let refresh = cookies.iter().find(|c| c.starts_with("refresh_token=")).unwrap();
        assert!(refresh.contains("Path=/auth"), "refresh_token must have Path=/auth");
        assert!(refresh.contains("HttpOnly"));
        assert!(refresh.contains("Secure"));
    }

    #[test]
    fn auth_cookie_headers_logged_in_marker_is_not_httponly() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let marker = cookies.iter().find(|c| c.starts_with("logged_in=")).unwrap();
        assert!(!marker.contains("HttpOnly"), "logged_in must NOT be HttpOnly");
        assert!(marker.contains("Secure"), "logged_in must have Secure flag");
        assert!(marker.contains("logged_in=1"), "logged_in value must be '1'");
    }

    #[test]
    fn auth_cookie_headers_access_token_contains_jwt() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let access = cookies.iter().find(|c| c.starts_with("access_token=")).unwrap();
        assert!(access.contains("access-jwt-token"));
    }

    #[test]
    fn auth_cookie_headers_refresh_token_has_30_day_max_age() {
        let auth = sample_auth_response();
        let headers = auth_cookie_headers(&auth);
        let cookies: Vec<_> = headers
            .get_all(SET_COOKIE)
            .iter()
            .map(|v| v.to_str().unwrap().to_string())
            .collect();

        let refresh = cookies.iter().find(|c| c.starts_with("refresh_token=")).unwrap();
        let expected_max_age = 30 * 24 * 3600;
        assert!(
            refresh.contains(&format!("Max-Age={expected_max_age}")),
            "refresh_token must have 30-day Max-Age"
        );
    }
}
