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
        Ok(Self {
            server_key: std::env::var("FCM_SERVER_KEY")
                .unwrap_or_else(|_| "not-set".to_string()),
            project_id: std::env::var("FCM_PROJECT_ID")
                .unwrap_or_else(|_| "not-set".to_string()),
        })
    }
}

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
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
}
