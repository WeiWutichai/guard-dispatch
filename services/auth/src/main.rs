mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::extract::DefaultBodyLimit;
use axum::middleware;
use axum::routing::{get, patch, post, put};
use axum::Router;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use aws_sdk_s3::config::{BehaviorVersion, Builder as S3Builder, Credentials, Region};
use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::openapi::{SecurityAddon, ServerPrefixAddon};
use shared::otp::OtpConfig;
use shared::redis_client::create_redis_client;
use shared::sms::SmsConfig;

use crate::state::AppState;

#[derive(OpenApi)]
#[openapi(
    info(title = "Guard Dispatch - Auth Service", version = "0.1.0"),
    paths(
        handlers::register,
        handlers::login,
        handlers::phone_login,
        handlers::refresh_token,
        handlers::get_profile,
        handlers::update_profile,
        handlers::logout,
        handlers::request_otp,
        handlers::verify_otp,
        handlers::register_with_otp,
        handlers::list_users,
        handlers::update_approval_status,
        handlers::get_guard_profile,
        handlers::check_status,
        handlers::admin_update_guard_profile,
        handlers::submit_customer_profile,
        handlers::get_customer_profile,
        handlers::list_customer_applicants,
        handlers::update_customer_approval,
        handlers::reissue_profile_token,
        handlers::update_role,
        handlers::get_public_guard_profile,
    ),
    components(schemas(
        models::RegisterRequest,
        models::LoginRequest,
        models::PhoneLoginRequest,
        models::CheckStatusRequest,
        models::CheckStatusResponse,
        models::RefreshRequest,
        models::UpdateProfileRequest,
        models::AuthResponse,
        models::UserResponse,
        models::RequestOtpRequest,
        models::RequestOtpResponse,
        models::VerifyOtpRequest,
        models::VerifyOtpResponse,
        models::RegisterWithOtpRequest,
        models::RegisterWithOtpResponse,
        models::ListUsersQuery,
        models::UpdateApprovalStatusRequest,
        models::ReissueProfileTokenRequest,
        models::ReissueProfileTokenResponse,
        models::UpdateRoleRequest,
        models::UpdateRoleResponse,
        models::PaginatedUsers,
        shared::models::UserRole,
        shared::models::ApprovalStatus,
        models::GuardProfileResponse,
        models::AdminUpdateGuardProfileRequest,
        models::PublicGuardProfileResponse,
        models::SubmitCustomerProfileRequest,
        models::CustomerProfileResponse,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon, &ServerPrefixAddon),
    tags(
        (name = "Auth", description = "Authentication endpoints"),
        (name = "OTP", description = "OTP verification for registration"),
        (name = "Profile", description = "User profile management"),
        (name = "Admin", description = "Admin user management"),
    ),
)]
struct ApiDoc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .init();

    let db_config = DatabaseConfig::from_env()?;
    let redis_config = RedisConfig::from_env()?;
    let jwt_config = JwtConfig::from_env()?;
    let sms_config = SmsConfig::from_env()?;
    let otp_config = OtpConfig::from_env()?;

    let db = create_pool(&db_config).await?;
    let redis_client = create_redis_client(&redis_config.cache_url)?;
    let redis = redis_client
        .get_multiplexed_tokio_connection()
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to Redis: {e}"))?;

    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .connect_timeout(std::time::Duration::from_secs(5))
        .build()
        .map_err(|e| anyhow::anyhow!("Failed to build HTTP client: {e}"))?;

    // S3/MinIO client for guard profile document storage.
    // Fail-fast if required env vars are missing.
    let s3_endpoint = std::env::var("S3_ENDPOINT")
        .map_err(|_| anyhow::anyhow!("S3_ENDPOINT env var is required"))?;
    let s3_access_key = std::env::var("S3_ACCESS_KEY")
        .map_err(|_| anyhow::anyhow!("S3_ACCESS_KEY env var is required"))?;
    let s3_secret_key = std::env::var("S3_SECRET_KEY")
        .map_err(|_| anyhow::anyhow!("S3_SECRET_KEY env var is required"))?;
    let s3_bucket =
        std::env::var("S3_BUCKET").map_err(|_| anyhow::anyhow!("S3_BUCKET env var is required"))?;
    // Public URL for presigned URLs. Defaults to S3_ENDPOINT when not set
    // (useful when MinIO is directly accessible, e.g. in some CI environments).
    // In Docker dev: set to http://localhost/minio-files so the browser can load images.
    let s3_public_url = std::env::var("S3_PUBLIC_URL").unwrap_or_else(|_| s3_endpoint.clone());

    let s3_credentials = Credentials::new(&s3_access_key, &s3_secret_key, None, None, "env");
    let s3_config = S3Builder::new()
        .behavior_version(BehaviorVersion::latest())
        .endpoint_url(&s3_endpoint)
        .credentials_provider(s3_credentials)
        .region(Region::new("us-east-1"))
        .force_path_style(true) // Required for MinIO path-style addressing
        .build();
    let s3_client = aws_sdk_s3::Client::from_conf(s3_config);

    let state = Arc::new(AppState {
        db,
        redis,
        jwt_config,
        sms_config,
        otp_config,
        http_client,
        s3_client,
        s3_bucket,
        s3_endpoint,
        s3_public_url,
    });

    // Background task: clean up expired OTP codes every hour
    let cleanup_db = state.db.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(3600));
        loop {
            interval.tick().await;
            match sqlx::query(
                "DELETE FROM auth.otp_codes WHERE expires_at < NOW() - INTERVAL '1 hour'",
            )
            .execute(&cleanup_db)
            .await
            {
                Ok(result) => {
                    if result.rows_affected() > 0 {
                        tracing::info!("Cleaned up {} expired OTP codes", result.rows_affected());
                    }
                }
                Err(e) => {
                    tracing::error!("OTP cleanup failed: {e}");
                }
            }
        }
    });

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/register", post(handlers::register))
        .route("/login", post(handlers::login))
        .route("/login/phone", post(handlers::phone_login))
        .route("/check-status", post(handlers::check_status))
        .route("/otp/request", post(handlers::request_otp))
        .route("/otp/verify", post(handlers::verify_otp))
        .route("/register/otp", post(handlers::register_with_otp))
        .route("/refresh", post(handlers::refresh_token))
        .route(
            "/me",
            get(handlers::get_profile).put(handlers::update_profile),
        )
        .route("/logout", post(handlers::logout))
        .route("/users", get(handlers::list_users))
        .route(
            "/users/{id}/approval",
            patch(handlers::update_approval_status),
        )
        .merge(
            Router::new()
                .route("/profile/guard", post(handlers::submit_guard_profile))
                .layer(DefaultBodyLimit::max(10 * 1024 * 1024)), // 10MB for document uploads
        )
        .route("/profile/reissue", post(handlers::reissue_profile_token))
        .route("/profile/role", post(handlers::update_role))
        .route("/profile/customer", post(handlers::submit_customer_profile))
        .route(
            "/guards/{user_id}/profile",
            get(handlers::get_public_guard_profile),
        )
        .route("/guards/me/expiry", put(handlers::update_own_expiry))
        .route(
            "/admin/guard-profile/{user_id}",
            get(handlers::get_guard_profile).put(handlers::admin_update_guard_profile),
        )
        .route(
            "/admin/customer-profile/{user_id}",
            get(handlers::get_customer_profile),
        )
        .route(
            "/admin/customer-applicants",
            get(handlers::list_customer_applicants),
        )
        .route(
            "/admin/customer-profile/{user_id}/approval",
            patch(handlers::update_customer_approval),
        )
        .merge({
            let swagger =
                SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi());
            match std::env::var("SWAGGER_PATH_PREFIX") {
                Ok(prefix) => swagger.config(utoipa_swagger_ui::Config::from(format!(
                    "{prefix}/api-docs/openapi.json"
                ))),
                Err(_) => swagger,
            }
        })
        .layer(middleware::from_fn_with_state(
            state.clone(),
            shared::audit::audit_middleware::<Arc<AppState>>,
        ))
        .layer(shared::config::build_cors_layer())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await?;
    tracing::info!("auth-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
