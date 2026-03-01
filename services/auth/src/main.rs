mod handlers;
mod models;
mod service;
mod state;

use std::sync::Arc;

use axum::middleware;
use axum::routing::{get, post};
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
    info(title = "Guard Dispatch - Auth Service", version = "0.1.0"),
    paths(
        handlers::register,
        handlers::login,
        handlers::refresh_token,
        handlers::get_profile,
        handlers::update_profile,
        handlers::logout,
    ),
    components(schemas(
        models::RegisterRequest,
        models::LoginRequest,
        models::RefreshRequest,
        models::UpdateProfileRequest,
        models::AuthResponse,
        models::UserResponse,
        shared::models::UserRole,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon, &ServerPrefixAddon),
    tags(
        (name = "Auth", description = "Authentication endpoints"),
        (name = "Profile", description = "User profile management"),
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
    let redis_client = create_redis_client(&redis_config.cache_url)?;
    let redis = redis_client
        .get_multiplexed_tokio_connection()
        .await
        .map_err(|e| anyhow::anyhow!("Failed to connect to Redis: {e}"))?;

    let state = Arc::new(AppState {
        db,
        redis,
        jwt_config,
    });

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/register", post(handlers::register))
        .route("/login", post(handlers::login))
        .route("/refresh", post(handlers::refresh_token))
        .route(
            "/me",
            get(handlers::get_profile).put(handlers::update_profile),
        )
        .route("/logout", post(handlers::logout))
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

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await?;
    tracing::info!("auth-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
