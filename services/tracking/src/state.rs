use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    #[allow(dead_code)]
    pub redis_cache: redis::Client,
    /// Multiplexed connection to the **cache** Redis instance — the same one
    /// `auth-service` writes `revoked_jti:{jti}` blocklist entries to.
    /// `HasJwtSecret::redis_conn()` returns this so `AuthUser` checks see
    /// revocations made at logout. (Bug fix: previously returned
    /// `redis_pubsub`, which is a separate instance that never holds the
    /// blocklist — letting revoked tokens stay valid on tracking endpoints.)
    pub redis_cache_conn: redis::aio::MultiplexedConnection,
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
        &self.redis_cache_conn
    }
}

impl HasDbPool for AppState {
    fn db_pool(&self) -> &PgPool {
        &self.db
    }
}
