use axum::{Router, routing::get};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .init();

    // TODO: WebSocket handler for real-time chat messages
    // TODO: Multipart upload handler for images (JPEG/PNG/WEBP, max 10MB)
    // TODO: MinIO/S3 signed URL generation
    // file_key format: chat/{chat_id}/{uuid}.{ext}
    // Signed URL expiry: 1 hour
    let app = Router::new()
        .route("/health", get(health_check));
    // .route("/ws/chat",        get(ws_handler))
    // .route("/attachments",    post(upload_attachment))
    // .route("/attachments/{id}", get(get_signed_url))

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3006").await?;
    tracing::info!("chat-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
