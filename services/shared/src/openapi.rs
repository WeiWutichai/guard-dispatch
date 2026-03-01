use utoipa::Modify;
use utoipa::openapi::security::{Http, HttpAuthScheme, SecurityScheme};

/// Modifier that adds JWT Bearer authentication to the OpenAPI spec.
/// Reused by all services via `modifiers(&SecurityAddon)`.
pub struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        if let Some(components) = openapi.components.as_mut() {
            components.add_security_scheme(
                "bearer",
                SecurityScheme::Http({
                    let mut http = Http::new(HttpAuthScheme::Bearer);
                    http.bearer_format = Some("JWT".into());
                    http
                }),
            );
        }
    }
}

/// Modifier that sets the server URL prefix from `SWAGGER_PATH_PREFIX` env var.
///
/// When running behind nginx (e.g. `/auth/*` → auth-service), Swagger UI's
/// "Try it out" needs to send requests to `/auth/login` instead of `/login`.
/// Set `SWAGGER_PATH_PREFIX=/auth` in docker-compose to enable this.
///
/// Without the env var (local dev), no server prefix is added and the
/// service works standalone on its own port.
pub struct ServerPrefixAddon;

impl Modify for ServerPrefixAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        if let Ok(prefix) = std::env::var("SWAGGER_PATH_PREFIX") {
            openapi.servers = Some(vec![
                utoipa::openapi::Server::new(prefix),
            ]);
        }
    }
}
