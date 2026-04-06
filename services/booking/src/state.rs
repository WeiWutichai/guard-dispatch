use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_config: JwtConfig,
    /// Redis client for creating per-WS PubSub subscription connections.
    pub redis_client: redis::Client,
    /// Multiplexed connection for PUBLISH commands (cheap to clone).
    pub redis_conn: redis::aio::MultiplexedConnection,
    /// Shared HTTP client for outbound requests (e.g. reverse geocoding).
    pub http_client: reqwest::Client,
    /// S3/MinIO client for file uploads (progress report photos).
    pub s3_client: aws_sdk_s3::Client,
    pub s3_bucket: String,
    pub s3_endpoint: String,
    pub s3_public_url: String,
}

impl HasJwtSecret for AppState {
    fn jwt_secret(&self) -> &str {
        &self.jwt_config.secret
    }

    fn decoding_key(&self) -> &jsonwebtoken::DecodingKey {
        &self.jwt_config.decoding_key
    }

    fn redis_conn(&self) -> &redis::aio::MultiplexedConnection {
        &self.redis_conn
    }
}

impl HasDbPool for AppState {
    fn db_pool(&self) -> &PgPool {
        &self.db
    }
}
