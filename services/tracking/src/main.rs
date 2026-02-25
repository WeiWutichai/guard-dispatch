use axum::{Router, routing::get};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .init();

    // TODO: Add WebSocket handler for GPS tracking
    // GPS data MUST flow through WebSocket only — no REST polling
    let app = Router::new()
        .route("/health", get(health_check));
    // .route("/ws/track", get(ws_handler));  ← WebSocket endpoint

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3003").await?;
    tracing::info!("tracking-service listening on {}", listener.local_addr()?);

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}
