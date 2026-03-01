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
    // NOTE: Notification service currently uses redis::Client.
    // TODO: Convert to redis::aio::MultiplexedConnection per CLAUDE.md pattern
    // when implementing Redis caching for notification queries.
    pub redis_cache: redis::Client,
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
}

impl HasDbPool for AppState {
    fn db_pool(&self) -> &PgPool {
        &self.db
    }
}
