use crate::error::AppError;

pub fn create_redis_client(url: &str) -> Result<redis::Client, AppError> {
    let client = redis::Client::open(url)
        .map_err(|e| AppError::Internal(format!("Failed to create Redis client: {e}")))?;

    tracing::info!("Redis client created for {url}");

    Ok(client)
}
