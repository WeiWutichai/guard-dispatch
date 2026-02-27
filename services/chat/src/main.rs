mod handlers;
mod models;
mod s3;
mod service;
mod state;

use std::sync::Arc;

use axum::routing::{get, post};
use axum::Router;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig, S3Config};
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
    let s3_config = S3Config::from_env()?;

    let db = create_pool(&db_config).await?;
    let redis_cache = create_redis_client(&redis_config.cache_url)?;
    let redis_pubsub = create_redis_client(
        redis_config
            .pubsub_url
            .as_deref()
            .unwrap_or(&redis_config.cache_url),
    )?;

    // Initialize S3/MinIO client
    let s3_creds = aws_sdk_s3::config::Credentials::new(
        &s3_config.access_key,
        &s3_config.secret_key,
        None,
        None,
        "env",
    );

    let s3_sdk_config = aws_sdk_s3::Config::builder()
        .endpoint_url(&s3_config.endpoint)
        .region(aws_sdk_s3::config::Region::new("us-east-1"))
        .credentials_provider(s3_creds)
        .force_path_style(true) // Required for MinIO
        .behavior_version_latest()
        .build();

    let s3_client = aws_sdk_s3::Client::from_conf(s3_sdk_config);

    let state = Arc::new(AppState {
        db,
        redis_cache,
        redis_pubsub,
        jwt_config,
        s3_client,
        s3_bucket: s3_config.bucket.clone(),
        s3_endpoint: s3_config.endpoint.clone(),
    });

    let app = Router::new()
        .route("/health", get(health_check))
        // WebSocket — real-time chat
        .route("/ws/chat", get(handlers::ws_handler))
        // REST — Conversations
        .route(
            "/conversations",
            post(handlers::create_conversation).get(handlers::list_conversations),
        )
        .route(
            "/conversations/{id}/messages",
            get(handlers::list_messages),
        )
        // REST — Attachments (image upload + signed URL)
        .route("/attachments", post(handlers::upload_attachment))
        .route("/attachments/{id}", get(handlers::get_signed_url))
        .layer(shared::config::build_cors_layer())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3006").await?;
    tracing::info!("chat-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
