use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    #[allow(dead_code)]
    pub redis_cache: redis::Client,
    /// Pre-established multiplexed Redis connection for GPS PubSub.
    /// Clone is cheap — shares the underlying connection (per CLAUDE.md).
    pub redis_pubsub: redis::aio::MultiplexedConnection,
    pub jwt_config: JwtConfig,
}

impl HasJwtSecret for AppState {
    fn jwt_secret(&self) -> &str {
        &self.jwt_config.secret
    }

    fn decoding_key(&self) -> &jsonwebtoken::DecodingKey {
        &self.jwt_config.decoding_key
    }

    fn redis_conn(&self) -> &redis::aio::MultiplexedConnection {
        &self.redis_pubsub
    }
}

impl HasDbPool for AppState {
    fn db_pool(&self) -> &PgPool {
        &self.db
    }
}
