//! FCM HTTP v1 API — OAuth 2.0 Service Account authentication.
//!
//! Google requires a short-lived OAuth 2.0 access token for FCM v1 API calls.
//! The token is obtained by signing a JWT with the service account's RSA
//! private key and exchanging it at Google's token endpoint. The access token
//! is valid for 1 hour; we cache it and refresh 5 minutes before expiry.
//!
//! Flow:
//!   1. Load service account JSON (private_key, client_email, token_uri)
//!   2. Build a JWT: iss=client_email, scope=fcm, aud=token_uri, exp=now+1h
//!   3. Sign with RS256 using the private key
//!   4. POST to token_uri with grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
//!   5. Response: { access_token, token_type, expires_in }
//!   6. Cache the access_token; refresh when expires_in < 300s

use chrono::Utc;
use serde::{Deserialize, Serialize};
use shared::error::AppError;
use std::sync::Arc;
use tokio::sync::RwLock;

const FCM_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_REFRESH_BUFFER_SECS: i64 = 300; // refresh 5 min before expiry

/// Parsed service account JSON fields we need.
#[derive(Debug, Clone)]
pub struct ServiceAccount {
    pub project_id: String,
    pub client_email: String,
    pub private_key: String,
    pub token_uri: String,
}

impl ServiceAccount {
    /// Load from a JSON file path (set via `FCM_SERVICE_ACCOUNT_PATH` env var).
    pub fn from_file(path: &str) -> Result<Self, AppError> {
        let content = std::fs::read_to_string(path).map_err(|e| {
            AppError::Internal(format!("Failed to read service account file '{path}': {e}"))
        })?;

        #[derive(Deserialize)]
        struct RawServiceAccount {
            project_id: String,
            client_email: String,
            private_key: String,
            token_uri: String,
        }

        let raw: RawServiceAccount = serde_json::from_str(&content).map_err(|e| {
            AppError::Internal(format!("Failed to parse service account JSON: {e}"))
        })?;

        Ok(Self {
            project_id: raw.project_id,
            client_email: raw.client_email,
            private_key: raw.private_key,
            token_uri: raw.token_uri,
        })
    }
}

/// Cached OAuth 2.0 access token with expiry tracking.
#[derive(Debug, Clone)]
struct CachedToken {
    access_token: String,
    /// Absolute timestamp when this token expires.
    expires_at: i64,
}

/// Thread-safe OAuth token manager. Caches the access token and refreshes
/// automatically when it's within 5 minutes of expiry.
#[derive(Debug, Clone)]
pub struct FcmAuth {
    service_account: ServiceAccount,
    http_client: reqwest::Client,
    cached: Arc<RwLock<Option<CachedToken>>>,
}

impl FcmAuth {
    pub fn new(service_account: ServiceAccount, http_client: reqwest::Client) -> Self {
        Self {
            service_account,
            http_client,
            cached: Arc::new(RwLock::new(None)),
        }
    }

    /// Get a valid OAuth 2.0 access token, refreshing if needed.
    pub async fn get_access_token(&self) -> Result<String, AppError> {
        // Fast path: read lock → check if cached token is still valid
        {
            let cached = self.cached.read().await;
            if let Some(ref t) = *cached {
                let now = Utc::now().timestamp();
                if t.expires_at - now > TOKEN_REFRESH_BUFFER_SECS {
                    return Ok(t.access_token.clone());
                }
            }
        }

        // Slow path: write lock → refresh token
        let mut cached = self.cached.write().await;

        // Double-check after acquiring write lock (another task may have refreshed)
        if let Some(ref t) = *cached {
            let now = Utc::now().timestamp();
            if t.expires_at - now > TOKEN_REFRESH_BUFFER_SECS {
                return Ok(t.access_token.clone());
            }
        }

        let new_token = self.exchange_jwt_for_token().await?;
        let access_token = new_token.access_token.clone();
        *cached = Some(new_token);
        Ok(access_token)
    }

    /// Sign a JWT and exchange it for an OAuth 2.0 access token at Google's
    /// token endpoint.
    async fn exchange_jwt_for_token(&self) -> Result<CachedToken, AppError> {
        let now = Utc::now().timestamp();
        let exp = now + 3600; // 1 hour

        // Build the JWT claims
        #[derive(Serialize)]
        struct GoogleClaims {
            iss: String,
            scope: String,
            aud: String,
            iat: i64,
            exp: i64,
        }

        let claims = GoogleClaims {
            iss: self.service_account.client_email.clone(),
            scope: FCM_SCOPE.to_string(),
            aud: self.service_account.token_uri.clone(),
            iat: now,
            exp,
        };

        // Sign with RS256 using the service account's private key
        let encoding_key =
            jsonwebtoken::EncodingKey::from_rsa_pem(self.service_account.private_key.as_bytes())
                .map_err(|e| AppError::Internal(format!("Failed to parse RSA private key: {e}")))?;

        let header = jsonwebtoken::Header::new(jsonwebtoken::Algorithm::RS256);
        let jwt = jsonwebtoken::encode(&header, &claims, &encoding_key)
            .map_err(|e| AppError::Internal(format!("Failed to sign Google JWT: {e}")))?;

        // Exchange JWT for access token
        #[derive(Deserialize)]
        struct TokenResponse {
            access_token: String,
            expires_in: i64,
        }

        let response = self
            .http_client
            .post(&self.service_account.token_uri)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", &jwt),
            ])
            .send()
            .await
            .map_err(|e| AppError::Internal(format!("Google token exchange failed: {e}")))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response
                .text()
                .await
                .unwrap_or_else(|_| "unknown".to_string());
            return Err(AppError::Internal(format!(
                "Google token exchange returned {status}: {body}"
            )));
        }

        let token_resp: TokenResponse = response
            .json()
            .await
            .map_err(|e| AppError::Internal(format!("Failed to parse token response: {e}")))?;

        tracing::info!(
            "FCM OAuth token refreshed (expires_in={}s, project={})",
            token_resp.expires_in,
            self.service_account.project_id
        );

        Ok(CachedToken {
            access_token: token_resp.access_token,
            expires_at: now + token_resp.expires_in,
        })
    }

    /// Get the project ID (needed for the FCM v1 API URL).
    pub fn project_id(&self) -> &str {
        &self.service_account.project_id
    }
}
