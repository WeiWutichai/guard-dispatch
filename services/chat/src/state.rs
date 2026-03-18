use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub redis_cache: redis::Client,
    /// Pre-established multiplexed Redis connection for chat PubSub.
    /// Clone is cheap — shares the underlying connection (per CLAUDE.md).
    pub redis_pubsub: redis::aio::MultiplexedConnection,
    pub jwt_config: JwtConfig,
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
}

impl HasDbPool for AppState {
    fn db_pool(&self) -> &PgPool {
        &self.db
    }
}
