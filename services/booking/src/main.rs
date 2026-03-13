mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::middleware;
use axum::routing::{get, post, put};
use axum::Router;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::openapi::{SecurityAddon, ServerPrefixAddon};
use shared::redis_client::create_redis_client;

use crate::state::AppState;

#[derive(OpenApi)]
#[openapi(
    info(title = "Guard Dispatch - Booking Service", version = "0.1.0"),
    paths(
        handlers::create_request,
        handlers::list_requests,
        handlers::get_request,
        handlers::cancel_request,
        handlers::assign_guard,
        handlers::update_assignment_status,
        handlers::accept_decline_assignment,
        handlers::review_completion,
        handlers::submit_review,
        handlers::get_assignments,
        handlers::available_guards,
        handlers::create_payment,
        handlers::start_job,
        handlers::get_active_job,
        handlers::get_customer_active_job,
        handlers::guard_dashboard,
        handlers::guard_jobs,
        handlers::guard_earnings,
        handlers::guard_work_history,
        handlers::guard_ratings,
        handlers::list_service_rates,
        handlers::get_service_rate,
        handlers::create_service_rate,
        handlers::update_service_rate,
        handlers::delete_service_rate,
    ),
    components(schemas(
        models::RequestStatus,
        models::UrgencyLevel,
        models::AssignmentStatus,
        models::CreateRequestDto,
        models::AssignGuardDto,
        models::UpdateAssignmentStatusDto,
        models::AcceptDeclineDto,
        models::ReviewCompletionDto,
        models::CreateReviewDto,
        models::SubmitReviewResponse,
        models::CreatePaymentDto,
        models::GuardRequestResponse,
        models::AssignmentResponse,
        models::PaymentResponse,
        models::ActiveJobResponse,
        models::AvailableGuardResponse,
        models::GuardJobResponse,
        models::GuardDashboardSummary,
        models::GuardEarnings,
        models::DailyEarning,
        models::WorkHistoryResponse,
        models::WorkHistoryItem,
        models::GuardRatingsSummary,
        models::ReviewItem,
        models::ServiceRate,
        models::CreateServiceRateDto,
        models::UpdateServiceRateDto,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon, &ServerPrefixAddon),
    tags(
        (name = "Requests", description = "Guard request management"),
        (name = "Assignments", description = "Guard assignment management"),
        (name = "Guards", description = "Available guards discovery"),
        (name = "Guard", description = "Guard-specific endpoints (dashboard, jobs, earnings)"),
        (name = "Payments", description = "Payment management"),
        (name = "Pricing", description = "Service rate management"),
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
    let jwt_config = JwtConfig::from_env()?;
    let redis_config = RedisConfig::from_env()?;

    let db = create_pool(&db_config).await?;

    // Redis for pub/sub (assignment status notifications)
    let redis_url = redis_config
        .pubsub_url
        .as_deref()
        .unwrap_or(&redis_config.cache_url);
    let redis_client = create_redis_client(redis_url)?;
    let redis_conn = redis_client
        .get_multiplexed_tokio_connection()
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to Redis: {e}"))?;

    let state = Arc::new(AppState {
        db,
        jwt_config,
        redis_client,
        redis_conn,
    });

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/requests", post(handlers::create_request).get(handlers::list_requests))
        .route("/requests/{id}", get(handlers::get_request))
        .route("/requests/{id}/cancel", put(handlers::cancel_request))
        .route("/requests/{id}/assign", post(handlers::assign_guard))
        .route(
            "/requests/{id}/assignments",
            get(handlers::get_assignments),
        )
        .route(
            "/requests/{id}/active-job",
            get(handlers::get_customer_active_job),
        )
        .route(
            "/assignments/{id}/status",
            put(handlers::update_assignment_status),
        )
        .route(
            "/assignments/{id}/accept",
            put(handlers::accept_decline_assignment),
        )
        .route("/assignments/{id}/start", put(handlers::start_job))
        .route(
            "/assignments/{id}/review-completion",
            put(handlers::review_completion),
        )
        .route(
            "/assignments/{id}/review",
            post(handlers::submit_review),
        )
        // WebSocket — real-time assignment status updates
        .route("/ws/assignments", get(handlers::ws_assignment_status))
        // Payments
        .route("/payments", post(handlers::create_payment))
        // Available guards (customer discovery)
        .route("/available-guards", get(handlers::available_guards))
        // Guard-specific endpoints
        .route("/guard/dashboard", get(handlers::guard_dashboard))
        .route("/guard/active-job", get(handlers::get_active_job))
        .route("/guard/jobs", get(handlers::guard_jobs))
        .route("/guard/earnings", get(handlers::guard_earnings))
        .route("/guard/work-history", get(handlers::guard_work_history))
        .route("/guard/ratings", get(handlers::guard_ratings))
        // Pricing endpoints (GET = public, POST/PUT/DELETE = admin JWT)
        .route(
            "/pricing/services",
            get(handlers::list_service_rates).post(handlers::create_service_rate),
        )
        .route(
            "/pricing/services/{id}",
            get(handlers::get_service_rate)
                .put(handlers::update_service_rate)
                .delete(handlers::delete_service_rate),
        )
        .merge({
            let swagger = SwaggerUi::new("/swagger-ui")
                .url("/api-docs/openapi.json", ApiDoc::openapi());
            match std::env::var("SWAGGER_PATH_PREFIX") {
                Ok(prefix) => swagger.config(
                    utoipa_swagger_ui::Config::from(format!("{prefix}/api-docs/openapi.json")),
                ),
                Err(_) => swagger,
            }
        })
        .layer(middleware::from_fn_with_state(state.clone(), shared::audit::audit_middleware::<Arc<AppState>>))
        .layer(shared::config::build_cors_layer())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3002").await?;
    tracing::info!("booking-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
