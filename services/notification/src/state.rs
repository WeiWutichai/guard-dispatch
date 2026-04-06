use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Debug, Clone)]
pub struct FcmConfig {
    pub server_key: String,
    pub project_id: String,
}

impl FcmConfig {
    pub fn from_env() -> Result<Self, shared::error::AppError> {
        let server_key = std::env::var("FCM_SERVER_KEY").map_err(|_| {
            shared::error::AppError::Internal(
                "FCM_SERVER_KEY env var is required but not set".to_string(),
            )
        })?;
        let project_id = std::env::var("FCM_PROJECT_ID").map_err(|_| {
            shared::error::AppError::Internal(
                "FCM_PROJECT_ID env var is required but not set".to_string(),
            )
        })?;
        Ok(Self {
            server_key,
            project_id,
        })
    }
}

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
    pub fcm_config: FcmConfig,
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
