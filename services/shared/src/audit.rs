use axum::body::Body;
use axum::extract::State;
use axum::http::Request;
use axum::middleware::Next;
use axum::response::Response;
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::{decode_jwt_with_key, extract_cookie_value, HasJwtSecret, ACCESS_TOKEN_COOKIE};

/// Trait that AppState must implement to provide a database pool for audit logging.
pub trait HasDbPool {
    fn db_pool(&self) -> &PgPool;
}

impl<T: HasDbPool> HasDbPool for std::sync::Arc<T> {
    fn db_pool(&self) -> &PgPool {
        T::db_pool(self)
    }
}

/// Audit logging middleware that captures requests and persists to audit.audit_logs.
///
/// Properly validates JWT signature before trusting the user_id claim.
/// Inserts audit records asynchronously (fire-and-forget) to avoid blocking responses.
///
/// Usage in a service (requires state that implements HasJwtSecret + HasDbPool):
/// ```rust,no_run,ignore
/// use axum::middleware;
/// use shared::audit::audit_middleware;
///
/// let app = Router::new()
///     .route("/health", get(health_check))
///     .layer(middleware::from_fn_with_state(state.clone(), audit_middleware));
/// ```
pub async fn audit_middleware<S>(
    State(state): State<S>,
    request: Request<Body>,
    next: Next,
) -> Response
where
    S: HasJwtSecret + HasDbPool + Clone + Send + Sync + 'static,
{
    let method = request.method().to_string();
    let path = request.uri().path().to_string();

    // Prefer X-Real-IP (set by trusted Nginx), fallback to rightmost X-Forwarded-For
    let ip_address = request
        .headers()
        .get("X-Real-IP")
        .and_then(|v| v.to_str().ok())
        .or_else(|| {
            request
                .headers()
                .get("X-Forwarded-For")
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.rsplit(',').next())
                .map(|s| s.trim())
        })
        .map(|s| s.to_string());

    // Extract token from Bearer header or cookie, then validate with real secret
    let token = request
        .headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .map(|t| t.to_string())
        .or_else(|| {
            request
                .headers()
                .get("Cookie")
                .and_then(|v| v.to_str().ok())
                .and_then(|cookies| extract_cookie_value(cookies, ACCESS_TOKEN_COOKIE))
                .map(|t| t.to_string())
        });

    let decoding_key = state.decoding_key();
    let user_id = token.and_then(|t| {
        decode_jwt_with_key(&t, decoding_key)
            .ok()
            .map(|claims| claims.sub)
    });

    let response = next.run(request).await;

    let status_code = response.status().as_u16();
    let action = format!("{method} {path}");

    // Derive entity_type from URL path (first segment after /)
    // e.g., "/auth/login" → "auth", "/booking/requests" → "booking"
    let entity_type = path
        .trim_start_matches('/')
        .split('/')
        .next()
        .unwrap_or("unknown")
        .to_string();

    // Structured log for observability
    tracing::info!(
        audit = true,
        user_id = ?user_id,
        action = %action,
        entity_type = %entity_type,
        status = status_code,
        ip = ?ip_address,
        "audit log"
    );

    // Fire-and-forget async insert to audit.audit_logs — don't block the response
    let pool = state.db_pool().clone();
    tokio::spawn(async move {
        if let Err(e) = insert_audit_log(
            &pool,
            user_id,
            &action,
            &entity_type,
            status_code,
            ip_address.as_deref(),
        )
        .await
        {
            tracing::warn!(error = %e, "failed to persist audit log");
        }
    });

    response
}

async fn insert_audit_log(
    pool: &PgPool,
    user_id: Option<Uuid>,
    action: &str,
    entity_type: &str,
    _status_code: u16,
    ip_address: Option<&str>,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO audit.audit_logs (user_id, action, entity_type, ip_address)
        VALUES ($1, $2, $3, $4::INET)
        "#,
    )
    .bind(user_id)
    .bind(action)
    .bind(entity_type)
    .bind(ip_address)
    .execute(pool)
    .await?;

    Ok(())
}
