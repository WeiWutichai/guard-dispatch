use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub redis_cache: redis::Client,
    pub redis_pubsub: redis::Client,
    pub jwt_config: JwtConfig,
    pub s3_client: aws_sdk_s3::Client,
    pub s3_bucket: String,
    pub s3_endpoint: String,
}

impl HasJwtSecret for AppState {
    fn jwt_secret(&self) -> &str {
        &self.jwt_config.secret
    }
}
