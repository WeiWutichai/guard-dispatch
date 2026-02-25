mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::routing::get;
use axum::Router;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::redis_client::create_redis_client;

use crate::state::AppState;

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

    let db = create_pool(&db_config).await?;
    let redis_cache = create_redis_client(&redis_config.cache_url)?;
    let redis_pubsub = create_redis_client(
        redis_config
            .pubsub_url
            .as_deref()
            .unwrap_or(&redis_config.cache_url),
    )?;

    let state = Arc::new(AppState {
        db,
        redis_cache,
        redis_pubsub,
        jwt_config,
    });

    let app = Router::new()
        .route("/health", get(health_check))
        // WebSocket — GPS data MUST flow through WebSocket only (per CLAUDE.md)
        .route("/ws/track", get(handlers::ws_handler))
        // REST — Location queries
        .route("/locations/{guard_id}", get(handlers::get_latest_location))
        .route(
            "/locations/{guard_id}/history",
            get(handlers::get_location_history),
        )
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3003").await?;
    tracing::info!("tracking-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
