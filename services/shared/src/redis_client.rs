use crate::error::AppError;

pub fn create_redis_client(url: &str) -> Result<redis::Client, AppError> {
    let client = redis::Client::open(url)
        .map_err(|e| AppError::Internal(format!("Failed to create Redis client: {e}")))?;

    // Redact password from URL before logging to prevent credential leakage
    let redacted = redact_redis_url(url);
    tracing::info!("Redis client created for {redacted}");

    Ok(client)
}

/// Redact the password portion of a Redis URL for safe logging.
/// `redis://:password@host:port` → `redis://:***@host:port`
fn redact_redis_url(url: &str) -> String {
    // Pattern: redis://:PASSWORD@host...
    if let Some(at_pos) = url.find('@') {
        if let Some(colon_pos) = url.find("://:") {
            let prefix = &url[..colon_pos + 4]; // "redis://:"
            let suffix = &url[at_pos..]; // "@host:port/..."
            return format!("{prefix}***{suffix}");
        }
    }
    // If no password pattern found, return as-is (no password to redact)
    url.to_string()
}
