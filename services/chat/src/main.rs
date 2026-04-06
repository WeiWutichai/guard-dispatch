mod handlers;
mod models;
mod s3;
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

use shared::config::{DatabaseConfig, JwtConfig, RedisConfig, S3Config};
use shared::db::create_pool;
use shared::openapi::{SecurityAddon, ServerPrefixAddon};
use shared::redis_client::create_redis_client;

use crate::state::AppState;

#[derive(OpenApi)]
#[openapi(
    info(title = "Guard Dispatch - Chat Service", version = "0.1.0"),
    paths(
        handlers::ws_handler,
        handlers::create_conversation,
        handlers::list_conversations,
        handlers::list_messages,
        handlers::mark_read,
        handlers::upload_attachment,
        handlers::get_signed_url,
    ),
    components(schemas(
        models::MessageType,
        models::IncomingChatMessage,
        models::OutgoingChatMessage,
        models::CreateConversationRequest,
        models::ConversationResponse,
        models::EnrichedConversationResponse,
        models::MessageResponse,
        models::AttachmentResponse,
        handlers::AttachmentUploadForm,
        shared::error::ErrorBody,
        shared::error::ErrorDetail,
    )),
    modifiers(&SecurityAddon, &ServerPrefixAddon),
    tags(
        (name = "Chat WebSocket", description = "Real-time chat WebSocket"),
        (name = "Conversations", description = "Conversation management"),
        (name = "Messages", description = "Message history"),
        (name = "Attachments", description = "Image attachment upload & retrieval"),
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
    let s3_config = S3Config::from_env()?;

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

    let s3_public_url =
        std::env::var("S3_PUBLIC_URL").unwrap_or_else(|_| s3_config.endpoint.clone());

    let state = Arc::new(AppState {
        db,
        redis_cache,
        redis_pubsub,
        jwt_config,
        s3_client,
        s3_bucket: s3_config.bucket.clone(),
        s3_endpoint: s3_config.endpoint.clone(),
        s3_public_url,
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
        .route("/conversations/{id}/messages", get(handlers::list_messages))
        .route(
            "/conversations/{id}/read",
            axum::routing::put(handlers::mark_read),
        )
        // REST — Attachments (image upload + signed URL)
        .route("/attachments", post(handlers::upload_attachment))
        .route("/attachments/{id}", get(handlers::get_signed_url))
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

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3006").await?;
    tracing::info!("chat-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
