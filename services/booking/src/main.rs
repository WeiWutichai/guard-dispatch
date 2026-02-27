mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::routing::{get, post, put};
use axum::Router;
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
    let redis = create_redis_client(&redis_config.cache_url)?;

    let state = Arc::new(AppState {
        db,
        redis,
        jwt_config,
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
            "/assignments/{id}/status",
            put(handlers::update_assignment_status),
        )
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
