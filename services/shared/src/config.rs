use crate::error::AppError;

#[derive(Debug, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
}

#[derive(Debug, Clone)]
pub struct RedisConfig {
    pub cache_url: String,
    pub pubsub_url: Option<String>,
}

#[derive(Debug, Clone)]
pub struct JwtConfig {
    pub secret: String,
    pub expiry_hours: i64,
}

#[derive(Debug, Clone)]
pub struct S3Config {
    pub endpoint: String,
    pub access_key: String,
    pub secret_key: String,
    pub bucket: String,
}

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub database: DatabaseConfig,
    pub redis: RedisConfig,
    pub jwt: JwtConfig,
    pub s3: Option<S3Config>,
}

fn require_env(key: &str) -> Result<String, AppError> {
    std::env::var(key).map_err(|_| AppError::Internal(format!("Missing env var: {key}")))
}

fn optional_env(key: &str) -> Option<String> {
    std::env::var(key).ok()
}

impl DatabaseConfig {
    pub fn from_env() -> Result<Self, AppError> {
        Ok(Self {
            url: require_env("DATABASE_URL")?,
            max_connections: optional_env("DATABASE_MAX_CONNECTIONS")
                .and_then(|v| v.parse().ok())
                .unwrap_or(20),
        })
    }
}

impl RedisConfig {
    pub fn from_env() -> Result<Self, AppError> {
        Ok(Self {
            cache_url: require_env("REDIS_CACHE_URL")?,
            pubsub_url: optional_env("REDIS_PUBSUB_URL"),
        })
    }
}

impl JwtConfig {
    pub fn from_env() -> Result<Self, AppError> {
        Ok(Self {
            secret: require_env("JWT_SECRET")?,
            expiry_hours: optional_env("JWT_EXPIRY_HOURS")
                .and_then(|v| v.parse().ok())
                .unwrap_or(24),
        })
    }
}

impl S3Config {
    pub fn from_env() -> Result<Self, AppError> {
        Ok(Self {
            endpoint: require_env("S3_ENDPOINT")?,
            access_key: require_env("S3_ACCESS_KEY")?,
            secret_key: require_env("S3_SECRET_KEY")?,
            bucket: require_env("S3_BUCKET")?,
        })
    }
}

impl AppConfig {
    pub fn from_env() -> Result<Self, AppError> {
        Ok(Self {
            database: DatabaseConfig::from_env()?,
            redis: RedisConfig::from_env()?,
            jwt: JwtConfig::from_env()?,
            s3: S3Config::from_env().ok(),
        })
    }
}
