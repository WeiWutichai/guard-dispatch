use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use shared::otp::OtpConfig;
use shared::sms::SmsConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub redis: redis::aio::MultiplexedConnection,
    pub jwt_config: JwtConfig,
    pub sms_config: SmsConfig,
    pub otp_config: OtpConfig,
    /// Shared HTTP client for outbound requests (SMS gateway, etc.).
    /// Reuses TCP connections across requests.
    pub http_client: reqwest::Client,
    /// S3/MinIO client for guard profile document storage.
    pub s3_client: aws_sdk_s3::Client,
    pub s3_bucket: String,
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
