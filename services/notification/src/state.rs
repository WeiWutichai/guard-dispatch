use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

use crate::fcm::FcmAuth;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    #[allow(dead_code)]
    pub redis_cache: redis::Client,
    /// Multiplexed Redis connection for token revocation blocklist checks.
    pub redis_cache_conn: redis::aio::MultiplexedConnection,
    #[allow(dead_code)]
    pub redis_pubsub: redis::Client,
    pub jwt_config: JwtConfig,
    /// FCM OAuth 2.0 auth — manages access token lifecycle automatically.
    pub fcm_auth: FcmAuth,
    pub http_client: reqwest::Client,
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
