mod fcm;
mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::middleware;
use axum::routing::{delete, get, post, put};
use axum::Router;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::openapi::{SecurityAddon, ServerPrefixAddon};
use shared::redis_client::create_redis_client;

use crate::fcm::{FcmAuth, ServiceAccount};
use crate::state::AppState;

#[derive(OpenApi)]
#[openapi(
    info(title = "Guard Dispatch - Notification Service", version = "0.1.0"),
    paths(
        handlers::register_token,
        handlers::unregister_token,
        handlers::list_notifications,
        handlers::unread_count,
        handlers::mark_all_as_read,
        handlers::mark_as_read,
        handlers::send_notification,
    ),
    components(schemas(
        models::NotificationType,
        models::RegisterTokenRequest,
        models::SendNotificationRequest,
        models::NotificationLogResponse,
        models::UnreadCountResponse,
        models::FcmTokenResponse,
        handlers::DeleteTokenRequest,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon, &ServerPrefixAddon),
    tags(
        (name = "FCM Tokens", description = "Device token management"),
        (name = "Notifications", description = "Notification management"),
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
    // Load Firebase service account for FCM OAuth 2.0 authentication.
    // The JSON file path is set via FCM_SERVICE_ACCOUNT_PATH env var.
    // This replaces the old FCM_SERVER_KEY approach which used a static
    // legacy key — Google deprecated that in 2024.
    let sa_path = std::env::var("FCM_SERVICE_ACCOUNT_PATH").unwrap_or_else(|_| {
        "/app/secrets/firebase-service-account.json".to_string()
    });
    let service_account = ServiceAccount::from_file(&sa_path)?;
    tracing::info!(
        "FCM service account loaded: project={}, email={}",
        service_account.project_id,
        service_account.client_email
    );

    let db = create_pool(&db_config).await?;
    let redis_cache = create_redis_client(&redis_config.cache_url)?;
    let redis_cache_conn = redis_cache
        .get_multiplexed_tokio_connection()
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to Redis cache: {e}"))?;
    let redis_pubsub = create_redis_client(
        redis_config
            .pubsub_url
            .as_deref()
            .unwrap_or(&redis_config.cache_url),
    )?;
    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .connect_timeout(std::time::Duration::from_secs(5))
        .build()
        .expect("Failed to build HTTP client");

    let fcm_auth = FcmAuth::new(service_account, http_client.clone());

    let state = Arc::new(AppState {
        db,
        redis_cache,
        redis_cache_conn,
        redis_pubsub,
        jwt_config,
        fcm_auth,
        http_client,
    });

    let app = Router::new()
        .route("/health", get(health_check))
        // FCM token management
        .route("/tokens", post(handlers::register_token))
        .route("/tokens", delete(handlers::unregister_token))
        // Notification CRUD
        .route("/notifications", get(handlers::list_notifications))
        .route("/notifications/unread-count", get(handlers::unread_count))
        .route("/notifications/read-all", put(handlers::mark_all_as_read))
        .route("/notifications/{id}/read", put(handlers::mark_as_read))
        .route("/notifications/send", post(handlers::send_notification))
        // Internal endpoint for service-to-service push (no JWT required).
        // Only accessible from Docker internal network (not exposed via nginx).
        // Called by booking-service's spawn_notification() to trigger FCM push
        // after inserting a notification log.
        .route("/internal/push", post(handlers::internal_push))
        ;
    let app = if std::env::var("ENABLE_SWAGGER").is_ok() {
        let swagger =
            SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi());
        let swagger = match std::env::var("SWAGGER_PATH_PREFIX") {
            Ok(prefix) => swagger.config(utoipa_swagger_ui::Config::from(format!(
                "{prefix}/api-docs/openapi.json"
            ))),
            Err(_) => swagger,
        };
        app.merge(swagger)
    } else {
        app
    }
        .layer(middleware::from_fn_with_state(
            state.clone(),
            shared::audit::audit_middleware::<Arc<AppState>>,
        ))
        .layer(shared::config::build_cors_layer())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3004").await?;
    tracing::info!(
        "notification-service listening on {}",
        listener.local_addr()?
    );

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
