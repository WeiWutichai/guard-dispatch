mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::routing::{delete, get, post, put};
use axum::Router;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::openapi::SecurityAddon;
use shared::redis_client::create_redis_client;

use crate::state::{AppState, FcmConfig};

#[derive(OpenApi)]
#[openapi(
    info(title = "Guard Dispatch - Notification Service", version = "0.1.0"),
    paths(
        handlers::register_token,
        handlers::unregister_token,
        handlers::list_notifications,
        handlers::mark_as_read,
        handlers::send_notification,
    ),
    components(schemas(
        models::NotificationType,
        models::RegisterTokenRequest,
        models::SendNotificationRequest,
        models::NotificationLogResponse,
        models::FcmTokenResponse,
        handlers::DeleteTokenRequest,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon),
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
    let fcm_config = FcmConfig::from_env()?;

    let db = create_pool(&db_config).await?;
    let redis_cache = create_redis_client(&redis_config.cache_url)?;
    let redis_pubsub = create_redis_client(
        redis_config
            .pubsub_url
            .as_deref()
            .unwrap_or(&redis_config.cache_url),
    )?;
    let http_client = reqwest::Client::new();

    let state = Arc::new(AppState {
        db,
        redis_cache,
        redis_pubsub,
        jwt_config,
        fcm_config,
        http_client,
    });

    let app = Router::new()
        .route("/health", get(health_check))
        // FCM token management
        .route("/tokens", post(handlers::register_token))
        .route("/tokens", delete(handlers::unregister_token))
        // Notification CRUD
        .route("/notifications", get(handlers::list_notifications))
        .route(
            "/notifications/{id}/read",
            put(handlers::mark_as_read),
        )
        .route("/notifications/send", post(handlers::send_notification))
        .merge(SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi()))
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
