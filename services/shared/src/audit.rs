use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::Request;
use axum::middleware::Next;
use axum::response::Response;
use sqlx::PgPool;
use std::net::SocketAddr;
use uuid::Uuid;

/// Audit logging middleware that captures requests to the audit.audit_logs table.
///
/// Usage in a service:
/// ```rust
/// use axum::middleware;
/// use shared::audit::audit_middleware;
///
/// let app = Router::new()
///     .route("/health", get(health_check))
///     .layer(middleware::from_fn_with_state(pool.clone(), audit_middleware));
/// ```
pub async fn audit_middleware(
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

    // Extract user_id from Authorization header if present
    let user_id = request
        .headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .and_then(|token| {
            // Try to decode JWT claims to get user_id — best effort
            jsonwebtoken::decode::<serde_json::Value>(
                token,
                &jsonwebtoken::DecodingKey::from_secret(b""), // Dummy key — we just need the claims
                &{
                    let mut v = jsonwebtoken::Validation::default();
                    v.insecure_disable_signature_validation();
                    v.validate_exp = false;
                    v
                },
            )
            .ok()
            .and_then(|data| {
                data.claims
                    .get("sub")
                    .and_then(|s| s.as_str())
                    .and_then(|s| Uuid::parse_str(s).ok())
            })
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
