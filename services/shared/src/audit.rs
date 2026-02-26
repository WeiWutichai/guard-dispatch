use axum::body::Body;
use axum::extract::State;
use axum::http::Request;
use axum::middleware::Next;
use axum::response::Response;

use crate::auth::{decode_jwt, extract_cookie_value, HasJwtSecret, ACCESS_TOKEN_COOKIE};

/// Audit logging middleware that captures requests to the audit.audit_logs table.
///
/// Properly validates JWT signature before trusting the user_id claim.
///
/// Usage in a service (requires state that implements HasJwtSecret):
/// ```rust
/// use axum::middleware;
/// use shared::audit::audit_middleware;
///
/// let app = Router::new()
///     .route("/health", get(health_check))
///     .layer(middleware::from_fn_with_state(state.clone(), audit_middleware));
/// ```
pub async fn audit_middleware<S: HasJwtSecret + Clone + Send + Sync + 'static>(
    State(state): State<S>,
    request: Request<Body>,
    next: Next,
) -> Response {
    let method = request.method().to_string();
    let path = request.uri().path().to_string();
    let ip_address = request
        .headers()
        .get("X-Real-IP")
        .and_then(|v| v.to_str().ok())
        .or_else(|| {
            request
                .headers()
                .get("X-Forwarded-For")
                .and_then(|v| v.to_str().ok())
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

    let user_id = token.and_then(|t| {
        decode_jwt(&t, state.jwt_secret())
            .ok()
            .map(|claims| claims.sub)
    });

    let response = next.run(request).await;

    let status_code = response.status().as_u16();
    let action = format!("{method} {path}");

    // Best-effort async audit log — don't block the response
    tracing::info!(
        audit = true,
        user_id = ?user_id,
        action = %action,
        status = status_code,
        ip = ?ip_address,
        "audit log"
    );

    response
}
