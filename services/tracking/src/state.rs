use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub redis_cache: redis::Client,
    pub redis_pubsub: redis::Client,
    pub jwt_config: JwtConfig,
}

impl HasJwtSecret for AppState {
    fn jwt_secret(&self) -> &str {
        &self.jwt_config.secret
    }
}
