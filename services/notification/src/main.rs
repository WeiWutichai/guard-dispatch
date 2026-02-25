mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::routing::{delete, get, post, put};
use axum::Router;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::redis_client::create_redis_client;

use crate::state::{AppState, FcmConfig};

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
        .layer(CorsLayer::permissive())
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
