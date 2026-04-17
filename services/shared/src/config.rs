use axum::http::header::{HeaderName, ACCEPT, AUTHORIZATION, CONTENT_TYPE, COOKIE, ORIGIN};
use axum::http::{HeaderValue, Method};
use tower_http::cors::CorsLayer;

use crate::error::AppError;

/// Build a CORS layer from CORS_ALLOWED_ORIGINS env var.
///
/// - If CORS_ALLOWED_ORIGINS is set, parse comma-separated origins.
/// - If not set, allow only localhost:3000 (safe dev default).
/// - Production must set CORS_ALLOWED_ORIGINS explicitly.
///
/// Note: `allow_credentials(true)` requires explicit header list —
/// `Any` (wildcard `*`) is forbidden by the CORS spec with credentials.
pub fn build_cors_layer() -> CorsLayer {
    let origins_str = std::env::var("CORS_ALLOWED_ORIGINS")
        .unwrap_or_else(|_| "http://localhost:3000".to_string());

    let origins: Vec<HeaderValue> = origins_str
        .split(',')
        .filter_map(|s| s.trim().parse().ok())
        .collect();

    CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::PATCH,
            Method::OPTIONS,
        ])
        .allow_headers([
            AUTHORIZATION,
            ACCEPT,
            CONTENT_TYPE,
            ORIGIN,
            COOKIE,
            HeaderName::from_static("x-requested-with"),
        ])
        .allow_credentials(true)
}

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

#[derive(Clone)]
pub struct JwtConfig {
    pub secret: String,
    /// Access token lifetime in minutes (default 15).
    pub expiry_minutes: i64,
    /// Pre-computed encoding key — avoids re-creating on every `encode_jwt` call.
    pub encoding_key: jsonwebtoken::EncodingKey,
    /// Pre-computed decoding key — avoids re-creating on every `decode_jwt` call.
    pub decoding_key: jsonwebtoken::DecodingKey,
}

impl std::fmt::Debug for JwtConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("JwtConfig")
            .field("expiry_minutes", &self.expiry_minutes)
            .field("secret", &"[REDACTED]")
            .finish()
    }
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
        let secret = require_env("JWT_SECRET")?;
        if secret.len() < 64 {
            return Err(AppError::Internal(
                "JWT_SECRET must be at least 64 characters".to_string(),
            ));
        }
        let encoding_key = jsonwebtoken::EncodingKey::from_secret(secret.as_bytes());
        let decoding_key = jsonwebtoken::DecodingKey::from_secret(secret.as_bytes());
        Ok(Self {
            secret,
            // Default 15 min (OWASP recommendation for high-sensitivity contexts).
            // Lowered from 60 → 15 (security-reviewer HIGH/MEDIUM finding) now that:
            //   - Mobile interceptor handles 401 → POST /auth/refresh/mobile → retry
            //   - WS reconnect tries refresh once before scheduling reconnect (a2f4c33)
            // Combined with the logout blocklist, this caps any stolen token's
            // exploitation window at 15 min instead of 60.
            expiry_minutes: optional_env("JWT_EXPIRY_MINUTES")
                .and_then(|v| v.parse().ok())
                .unwrap_or(15),
            encoding_key,
            decoding_key,
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    // Env var tests must run sequentially since they modify process state.
    // We use a static mutex to serialize them.
    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn with_env_vars<F: FnOnce()>(vars: &[(&str, &str)], f: F) {
        let _lock = ENV_LOCK.lock().unwrap();
        // Save previous values
        let previous: Vec<_> = vars
            .iter()
            .map(|(k, _)| (*k, std::env::var(k).ok()))
            .collect();
        // Set test values
        for (k, v) in vars {
            std::env::set_var(k, v);
        }
        f();
        // Restore
        for (k, prev) in &previous {
            match prev {
                Some(v) => std::env::set_var(k, v),
                None => std::env::remove_var(k),
            }
        }
    }

    fn clear_env_vars(keys: &[&str]) {
        for k in keys {
            std::env::remove_var(k);
        }
    }

    #[test]
    fn database_config_reads_from_env() {
        with_env_vars(&[("DATABASE_URL", "postgres://localhost/test")], || {
            let cfg = DatabaseConfig::from_env().unwrap();
            assert_eq!(cfg.url, "postgres://localhost/test");
            assert_eq!(cfg.max_connections, 20); // default
        });
    }

    #[test]
    fn database_config_custom_max_connections() {
        with_env_vars(
            &[
                ("DATABASE_URL", "postgres://localhost/test"),
                ("DATABASE_MAX_CONNECTIONS", "10"),
            ],
            || {
                let cfg = DatabaseConfig::from_env().unwrap();
                assert_eq!(cfg.max_connections, 10);
            },
        );
    }

    #[test]
    fn database_config_fails_without_url() {
        let _lock = ENV_LOCK.lock().unwrap();
        clear_env_vars(&["DATABASE_URL"]);
        let result = DatabaseConfig::from_env();
        assert!(result.is_err());
    }

    #[test]
    fn jwt_config_reads_from_env() {
        with_env_vars(
            &[(
                "JWT_SECRET",
                "super-secret-key-that-is-at-least-64-characters-long-for-hs256-security!",
            )],
            || {
                let cfg = JwtConfig::from_env().unwrap();
                assert_eq!(
                    cfg.secret,
                    "super-secret-key-that-is-at-least-64-characters-long-for-hs256-security!"
                );
                assert_eq!(cfg.expiry_minutes, 15); // default (15 min OWASP, per CLAUDE.md)
            },
        );
    }

    #[test]
    fn jwt_config_custom_expiry() {
        with_env_vars(
            &[
                (
                    "JWT_SECRET",
                    "a]strong-secret-that-is-at-least-64-characters-long-for-jwt-hs256-security!!",
                ),
                ("JWT_EXPIRY_MINUTES", "30"),
            ],
            || {
                let cfg = JwtConfig::from_env().unwrap();
                assert_eq!(cfg.expiry_minutes, 30);
            },
        );
    }

    #[test]
    fn jwt_config_fails_without_secret() {
        let _lock = ENV_LOCK.lock().unwrap();
        clear_env_vars(&["JWT_SECRET"]);
        let result = JwtConfig::from_env();
        assert!(result.is_err());
    }

    #[test]
    fn jwt_config_fails_with_short_secret() {
        with_env_vars(&[("JWT_SECRET", "too-short")], || {
            let result = JwtConfig::from_env();
            assert!(result.is_err());
        });
    }

    #[test]
    fn redis_config_reads_from_env() {
        with_env_vars(
            &[("REDIS_CACHE_URL", "redis://:pass@localhost:6379")],
            || {
                let cfg = RedisConfig::from_env().unwrap();
                assert_eq!(cfg.cache_url, "redis://:pass@localhost:6379");
                assert!(cfg.pubsub_url.is_none());
            },
        );
    }

    #[test]
    fn redis_config_with_pubsub() {
        with_env_vars(
            &[
                ("REDIS_CACHE_URL", "redis://cache"),
                ("REDIS_PUBSUB_URL", "redis://pubsub"),
            ],
            || {
                let cfg = RedisConfig::from_env().unwrap();
                assert_eq!(cfg.pubsub_url, Some("redis://pubsub".to_string()));
            },
        );
    }

    #[test]
    fn s3_config_reads_all_fields() {
        with_env_vars(
            &[
                ("S3_ENDPOINT", "http://minio:9000"),
                ("S3_ACCESS_KEY", "mykey"),
                ("S3_SECRET_KEY", "mysecret"),
                ("S3_BUCKET", "guard-dispatch-files"),
            ],
            || {
                let cfg = S3Config::from_env().unwrap();
                assert_eq!(cfg.endpoint, "http://minio:9000");
                assert_eq!(cfg.bucket, "guard-dispatch-files");
            },
        );
    }

    #[test]
    fn s3_config_fails_if_any_field_missing() {
        with_env_vars(
            &[
                ("S3_ENDPOINT", "http://minio:9000"),
                // Missing S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET
            ],
            || {
                clear_env_vars(&["S3_ACCESS_KEY", "S3_SECRET_KEY", "S3_BUCKET"]);
                let result = S3Config::from_env();
                assert!(result.is_err());
            },
        );
    }

    #[test]
    fn require_env_returns_error_for_missing_var() {
        let _lock = ENV_LOCK.lock().unwrap();
        clear_env_vars(&["DOES_NOT_EXIST_XYZ"]);
        let result = require_env("DOES_NOT_EXIST_XYZ");
        assert!(result.is_err());
    }

    #[test]
    fn optional_env_returns_none_for_missing_var() {
        let _lock = ENV_LOCK.lock().unwrap();
        clear_env_vars(&["DOES_NOT_EXIST_XYZ"]);
        assert_eq!(optional_env("DOES_NOT_EXIST_XYZ"), None);
    }
}
