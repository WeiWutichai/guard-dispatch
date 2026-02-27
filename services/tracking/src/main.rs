mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::routing::get;
use axum::Router;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig};
use shared::db::create_pool;
use shared::openapi::SecurityAddon;
use shared::redis_client::create_redis_client;

use crate::state::AppState;

#[derive(OpenApi)]
#[openapi(
    info(title = "Guard Dispatch - Tracking Service", version = "0.1.0"),
    paths(
        handlers::ws_handler,
        handlers::get_latest_location,
        handlers::get_location_history,
    ),
    components(schemas(
        models::GpsUpdate,
        models::GpsEvent,
        models::LocationResponse,
        models::LocationHistoryResponse,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon),
    tags(
        (name = "GPS Tracking", description = "Real-time GPS WebSocket"),
        (name = "Locations", description = "Location query endpoints"),
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
        .merge(SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi()))
        .layer(shared::config::build_cors_layer())
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
