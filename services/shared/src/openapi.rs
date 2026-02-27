use utoipa::Modify;
use utoipa::openapi::security::{Http, HttpAuthScheme, SecurityScheme};

/// Modifier that adds JWT Bearer authentication to the OpenAPI spec.
/// Reused by all services via `modifiers(&shared::openapi::SecurityAddon)`.
pub struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        if let Some(components) = openapi.components.as_mut() {
            components.add_security_scheme(
                "bearer",
                SecurityScheme::Http(
                    Http::new(HttpAuthScheme::Bearer).bearer_format("JWT"),
                ),
            );
        }
    }
}
