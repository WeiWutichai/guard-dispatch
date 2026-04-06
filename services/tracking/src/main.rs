mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::middleware;
use axum::routing::get;
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
    info(title = "Guard Dispatch - Tracking Service", version = "0.1.0"),
    paths(
        handlers::ws_handler,
        handlers::get_latest_location,
        handlers::get_location_history,
        handlers::list_all_locations,
    ),
    components(schemas(
        models::GpsUpdate,
        models::GpsEvent,
        models::LocationResponse,
        models::LocationHistoryResponse,
        models::GuardLocationWithName,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon, &ServerPrefixAddon),
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
    let redis_pubsub_client = create_redis_client(
        redis_config
            .pubsub_url
            .as_deref()
            .unwrap_or(&redis_config.cache_url),
    )?;
    let redis_pubsub = redis_pubsub_client
        .get_multiplexed_tokio_connection()
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to Redis PubSub: {e}"))?;
    tracing::info!("Redis PubSub multiplexed connection established");

    let state = Arc::new(AppState {
        db,
        redis_cache,
        redis_pubsub,
        jwt_config,
    });

    // Background task: clean up old location history every 6 hours
    {
        let db = state.db.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(6 * 3600));
            interval.tick().await; // skip first immediate tick
            loop {
                interval.tick().await;
                match sqlx::query_scalar::<_, i64>("SELECT tracking.cleanup_old_history(90)")
                    .fetch_one(&db)
                    .await
                {
                    Ok(deleted) => {
                        if deleted > 0 {
                            tracing::info!("Location history cleanup: deleted {deleted} old rows");
                        }
                    }
                    Err(e) => tracing::error!("Location history cleanup failed: {e}"),
                }
            }
        });
    }

    let app = Router::new()
        .route("/health", get(health_check))
        // WebSocket — GPS data MUST flow through WebSocket only (per CLAUDE.md)
        .route("/ws/track", get(handlers::ws_handler))
        // REST — Location queries
        .route("/locations", get(handlers::list_all_locations))
        .route("/locations/{guard_id}", get(handlers::get_latest_location))
        .route(
            "/locations/{guard_id}/history",
            get(handlers::get_location_history),
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

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3003").await?;
    tracing::info!("tracking-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
