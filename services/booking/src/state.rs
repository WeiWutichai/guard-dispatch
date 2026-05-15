use shared::audit::HasDbPool;
use shared::auth::HasJwtSecret;
use shared::config::JwtConfig;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_config: JwtConfig,
    /// Redis client (pubsub instance) for opening per-WS subscriber
    /// connections via `get_async_pubsub()`. Was named `redis_client`;
    /// renamed for symmetry with chat-service and to make the intent
    /// explicit alongside `redis_cache_conn`.
    pub redis_pubsub_client: redis::Client,
    /// Multiplexed connection to the pubsub Redis instance used for
    /// PUBLISH commands (call signaling, assignment notifications).
    /// Cheap to clone — shares the underlying connection.
    pub redis_pubsub_conn: redis::aio::MultiplexedConnection,
    /// Multiplexed connection to the **cache** Redis instance — the same
    /// one `auth-service` writes `revoked_jti:{jti}` blocklist entries to.
    /// `HasJwtSecret::redis_conn()` returns this so `AuthUser` checks see
    /// revocations made at logout. (Bug fix: previously the single
    /// `redis_conn` field was used both as pub/sub publish channel AND
    /// as the blocklist source — and since it pointed at `redis-pubsub`
    /// rather than `redis-cache`, logged-out tokens kept working on every
    /// booking endpoint until their 15-min TTL elapsed.)
    pub redis_cache_conn: redis::aio::MultiplexedConnection,
    /// Shared HTTP client for outbound requests (e.g. reverse geocoding).
    pub http_client: reqwest::Client,
    /// S3/MinIO client for file uploads (progress report photos).
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

    fn redis_conn(&self) -> &redis::aio::MultiplexedConnection {
        &self.redis_cache_conn
    }
}

impl HasDbPool for AppState {
    fn db_pool(&self) -> &PgPool {
        &self.db
    }
}
