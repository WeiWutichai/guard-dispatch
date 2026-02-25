use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde::Serialize;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("{0}")]
    BadRequest(String),

    #[error("{0}")]
    Unauthorized(String),

    #[error("{0}")]
    Forbidden(String),

    #[error("{0}")]
    NotFound(String),

    #[error("{0}")]
    Conflict(String),

    #[error("{0}")]
    Internal(String),

    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("redis error: {0}")]
    Redis(#[from] redis::RedisError),
}

#[derive(Serialize)]
struct ErrorBody {
    error: ErrorDetail,
}

#[derive(Serialize)]
struct ErrorDetail {
    code: String,
    message: String,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code) = match &self {
            AppError::BadRequest(_) => (StatusCode::BAD_REQUEST, "BAD_REQUEST"),
            AppError::Unauthorized(_) => (StatusCode::UNAUTHORIZED, "UNAUTHORIZED"),
            AppError::Forbidden(_) => (StatusCode::FORBIDDEN, "FORBIDDEN"),
            AppError::NotFound(_) => (StatusCode::NOT_FOUND, "NOT_FOUND"),
            AppError::Conflict(_) => (StatusCode::CONFLICT, "CONFLICT"),
            AppError::Internal(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR"),
            AppError::Database(e) => {
                tracing::error!("Database error: {e}");
                (StatusCode::INTERNAL_SERVER_ERROR, "DATABASE_ERROR")
            }
            AppError::Redis(e) => {
                tracing::error!("Redis error: {e}");
                (StatusCode::INTERNAL_SERVER_ERROR, "CACHE_ERROR")
            }
        };

        let message = match &self {
            AppError::Database(_) | AppError::Redis(_) => {
                "An internal error occurred".to_string()
            }
            other => other.to_string(),
        };

        let body = ErrorBody {
            error: ErrorDetail {
                code: code.to_string(),
                message,
            },
        };

        (status, axum::Json(body)).into_response()
    }
}
