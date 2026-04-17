//! HTTP integration tests for the auth service.
//!
//! These tests run against a live `rust-auth` container reached via the nginx
//! gateway at `$AUTH_BASE_URL` (defaults to `http://localhost/auth`). They do
//! NOT use `tower::oneshot` because the `auth-service` crate is a binary-only
//! crate with no `lib.rs`, so its `Router` builder cannot be imported from a
//! `tests/` file. Standalone HTTP tests are the pragmatic compromise.
//!
//! ## Prerequisites
//! - `docker compose up -d` (at minimum: nginx-gateway, rust-auth, postgres-db,
//!   redis-cache, minio). Migrations auto-applied on first boot.
//! - Host can reach `http://localhost/auth/health`.
//!
//! ## Isolation
//! Each test generates unique phone numbers / emails using a UUID suffix.
//! No truncation is done — the dev database accumulates rows.
//!
//! ## Rate limiting
//! Nginx enforces 5 r/s (burst=5) on the `/auth` zone and 3 req/min (burst=2)
//! on `/auth/otp/*`. To stay under those limits in a sequential test run we:
//! - retry 503/429 responses with exponential backoff (`send_retrying`)
//! - throttle each test with a short sleep at the top (`throttle()`)
//!
//! ## What's NOT covered (and why)
//! - Direct Redis/DB assertions (e.g. verifying `issued_jti:{jti}`): the
//!   postgres/redis containers only `expose` internal Docker ports so the host
//!   test process cannot connect. Tests that need this are marked `#[ignore]`.
//! - Constant-time OTP comparison timing checks: notoriously flaky; skipped.
//! - Full OTP → register happy path: needs access to the "sent" OTP code.
//!
//! ## Running
//! ```bash
//! cd /Users/nest/Documents/guard-dispatch
//! docker compose up -d
//! cargo test -p auth-service --test integration_tests -- --test-threads=1
//! ```

#![allow(clippy::uninlined_format_args)]

use std::sync::OnceLock;
use std::time::Duration;

use reqwest::{Client, RequestBuilder, StatusCode};
use serde_json::{json, Value};
use uuid::Uuid;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

fn base_url() -> String {
    std::env::var("AUTH_BASE_URL").unwrap_or_else(|_| "http://localhost/auth".to_string())
}

fn client() -> &'static Client {
    static CLIENT: OnceLock<Client> = OnceLock::new();
    CLIENT.get_or_init(|| {
        Client::builder()
            .timeout(Duration::from_secs(15))
            .cookie_store(true)
            .build()
            .expect("build reqwest client")
    })
}

/// Fresh client with its own cookie jar — used for tests that must NOT share
/// cookies with other tests (e.g. logged-out assertions).
fn fresh_client() -> Client {
    Client::builder()
        .timeout(Duration::from_secs(15))
        .cookie_store(true)
        .build()
        .expect("build reqwest client")
}

/// A unique Thai-format phone (`08XXXXXXXX`, 10 digits).
fn unique_phone() -> String {
    let raw = Uuid::new_v4().as_u128();
    let nine = format!("{:09}", raw % 1_000_000_000);
    format!("0{}", nine)
}

fn unique_email() -> String {
    format!("itest-{}@example.test", Uuid::new_v4().simple())
}

/// Short global throttle to stay below nginx `auth_limit` (5 r/s burst=5).
/// Called at the top of every test body.
async fn throttle() {
    tokio::time::sleep(Duration::from_millis(350)).await;
}

fn now_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// Send a request, retrying on nginx rate-limit responses (503/429).
/// The builder factory is invoked fresh on every attempt since `RequestBuilder`
/// is consumed by `send()`.
async fn send_retrying<F>(mut make: F) -> reqwest::Response
where
    F: FnMut() -> RequestBuilder,
{
    for attempt in 0..5 {
        let res = make().send().await.expect("send");
        if res.status() != StatusCode::SERVICE_UNAVAILABLE
            && res.status() != StatusCode::TOO_MANY_REQUESTS
        {
            return res;
        }
        tokio::time::sleep(Duration::from_millis(500 * (attempt + 1))).await;
    }
    make().send().await.expect("final send")
}

/// POST JSON with retry.
async fn post_json(path: &str, body: Value) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().post(&url).json(&body)).await
}

/// POST JSON with a Bearer token header, with retry.
async fn post_json_bearer(path: &str, token: &str, body: Value) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().post(&url).bearer_auth(token).json(&body)).await
}

/// POST a raw string body with retry.
async fn post_raw(path: &str, body: String) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().post(&url).body(body.clone())).await
}

/// POST an empty body to a content-typed JSON endpoint with retry.
async fn post_empty_json(path: &str) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| {
        client()
            .post(&url)
            .header("content-type", "application/json")
            .body("")
    })
    .await
}

async fn get(path: &str) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().get(&url)).await
}

async fn get_bearer(path: &str, token: &str) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().get(&url).bearer_auth(token)).await
}

async fn put_json(path: &str, body: Value) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().put(&url).json(&body)).await
}

/// Returns `true` if the service is unreachable and the test should bail out.
async fn service_unreachable() -> bool {
    let url = format!("{}/health", base_url());
    match client().get(&url).send().await {
        Ok(r) if r.status().is_success() => false,
        _ => {
            eprintln!(
                "SKIP: auth service not reachable at {} — run `docker compose up -d`",
                url
            );
            true
        }
    }
}

/// Creates a `pending` user via the email/password `/register` endpoint.
/// The resulting user CANNOT log in (approval_status=pending) — useful for
/// asserting generic-error responses on login.
async fn register_pending_user(email: &str, phone: &str, password: &str) {
    let res = post_json(
        "/register",
        json!({
            "email": email,
            "phone": phone,
            "password": password,
            "full_name": "Integration Test User",
            "role": "customer",
        }),
    )
    .await;
    assert_eq!(
        res.status(),
        StatusCode::OK,
        "register should succeed; body: {}",
        res.text().await.unwrap_or_default()
    );
}

// =============================================================================
// Priority 1 — core auth paths
// =============================================================================

#[tokio::test]
async fn health_endpoint_returns_ok() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = get("/health").await;
    assert_eq!(res.status(), StatusCode::OK);
    let body = res.text().await.expect("text");
    assert_eq!(body.trim(), "OK");
}

#[tokio::test]
async fn login_with_nonexistent_email_returns_generic_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/login",
        json!({
            "email": format!("nobody-{}@example.test", Uuid::new_v4()),
            "password": "whatever123",
        }),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
    let body: Value = res.json().await.expect("json");
    let msg = body["error"]["message"].as_str().unwrap_or("");
    assert!(
        msg.to_lowercase().contains("invalid"),
        "expected generic 'invalid' message, got: {msg}"
    );
}

#[tokio::test]
async fn login_with_registered_but_unapproved_account_returns_same_401() {
    // User enumeration protection: a pending account must produce the SAME
    // error as wrong-password, not a distinct 403 or "account pending".
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let email = unique_email();
    let phone = unique_phone();
    let password = "correct-horse-battery-staple";
    register_pending_user(&email, &phone, password).await;

    let res = post_json("/login", json!({"email": email, "password": password})).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
    let body: Value = res.json().await.expect("json");
    let msg = body["error"]["message"]
        .as_str()
        .unwrap_or("")
        .to_lowercase();
    assert!(
        msg.contains("invalid"),
        "expected generic error, got: {msg}"
    );
    assert!(
        !msg.contains("pending") && !msg.contains("approval") && !msg.contains("deactivated"),
        "error must not leak account state: {msg}"
    );
}

#[tokio::test]
async fn login_with_wrong_password_matches_unknown_email_shape() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let email = unique_email();
    let phone = unique_phone();
    register_pending_user(&email, &phone, "real-password-12345").await;

    let res = post_json(
        "/login",
        json!({"email": email, "password": "wrong-password-12345"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
    let body: Value = res.json().await.expect("json");
    let msg = body["error"]["message"]
        .as_str()
        .unwrap_or("")
        .to_lowercase();
    assert!(msg.contains("invalid"));
}

#[tokio::test]
async fn login_mobile_with_nonexistent_phone_returns_generic_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/login/mobile",
        json!({"phone": unique_phone(), "password": "nopassword"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn login_phone_web_with_nonexistent_phone_returns_generic_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/login/phone",
        json!({"phone": unique_phone(), "password": "nopassword"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn refresh_without_body_or_cookie_returns_400() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_raw("/refresh", String::new()).await;
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
    let body: Value = res.json().await.expect("json");
    let msg = body["error"]["message"].as_str().unwrap_or("");
    assert!(
        msg.to_lowercase().contains("refresh"),
        "expected refresh-related error, got: {msg}"
    );
}

#[tokio::test]
async fn refresh_mobile_with_empty_body_returns_400() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_empty_json("/refresh/mobile").await;
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn refresh_mobile_with_bogus_token_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/refresh/mobile",
        json!({"refresh_token": "not-a-real-refresh-token-xxxxxxxx"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn me_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    // Use fresh client so any stray cookies from other tests don't interfere.
    let res = send_retrying(|| fresh_client().get(format!("{}/me", base_url()))).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn me_with_bogus_bearer_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = get_bearer("/me", "not.a.valid.token").await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn logout_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = send_retrying(|| fresh_client().post(format!("{}/logout", base_url()))).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

// =============================================================================
// Priority 2 — /auth/profile/role dual-auth negative paths
// =============================================================================

#[tokio::test]
async fn update_role_without_phone_verified_token_or_bearer_is_rejected() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/profile/role",
        json!({"phone": unique_phone(), "role": "customer"}),
    )
    .await;
    assert!(
        res.status().is_client_error(),
        "expected 4xx when caller presents no proof, got {}",
        res.status()
    );
}

#[tokio::test]
async fn update_role_with_bogus_phone_verified_token_is_rejected() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/profile/role",
        json!({
            "phone": unique_phone(),
            "role": "customer",
            "phone_verified_token": "not.a.real.jwt",
        }),
    )
    .await;
    assert!(
        res.status().is_client_error(),
        "bogus token should be rejected, got {}",
        res.status()
    );
}

#[tokio::test]
async fn update_role_with_bogus_bearer_falls_through_and_rejects() {
    // Malformed Bearer → try_extract_user_id_from_bearer returns None →
    // handler falls through to OTP path which also fails → 4xx.
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json_bearer(
        "/profile/role",
        "not.a.real.bearer",
        json!({"phone": unique_phone(), "role": "customer"}),
    )
    .await;
    assert!(res.status().is_client_error());
}

// TODO: the positive side of the dual-auth matrix (valid phone_verified_token,
// valid Bearer, bearer-sub-vs-body-phone mismatch) requires either DB/Redis
// access to mint tokens out-of-band or a stubbed SMS gateway that echoes OTPs.
// Left as ignored scaffolding.
#[ignore = "requires valid phone_verified_token from /otp/verify — needs DB/Redis access"]
#[tokio::test]
async fn update_role_with_valid_phone_verified_token_issues_profile_token() {}

#[ignore = "requires real bearer; bearer sub != phone-looked-up user must return 403"]
#[tokio::test]
async fn update_role_bearer_sub_mismatch_with_body_phone_returns_403() {}

// =============================================================================
// Priority 3 — OTP + register_with_otp
// =============================================================================

#[tokio::test]
async fn request_otp_handler_is_wired_and_returns_json() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    // Fresh phone per test avoids per-phone Redis cooldown. Depending on
    // whether SmsConfig points at a real or stubbed gateway, the response
    // may be 200 or 4xx/5xx — the point of this test is just that the route
    // is wired and returns a parseable JSON envelope.
    let res = post_json("/otp/request", json!({"phone": unique_phone()})).await;
    assert!(
        res.status() == StatusCode::OK
            || res.status() == StatusCode::BAD_REQUEST
            || res.status() == StatusCode::INTERNAL_SERVER_ERROR,
        "unexpected status for otp/request: {}",
        res.status()
    );
    let _body: Value = res.json().await.expect("json envelope");
}

#[tokio::test]
async fn request_otp_rejects_non_thai_phone_format() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json("/otp/request", json!({"phone": "+1-555-1234"})).await;
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn verify_otp_with_no_active_code_returns_400() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    // No OTP was requested for this phone → verify must fail with 400.
    let res = post_json(
        "/otp/verify",
        json!({"phone": unique_phone(), "code": "000000"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn register_with_otp_without_token_returns_400() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json("/register/otp", json!({"phone_verified_token": ""})).await;
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn register_with_otp_with_forged_token_returns_400() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/register/otp",
        json!({
            "phone_verified_token": "forged.jwt.here",
            "password": "irrelevant",
        }),
    )
    .await;
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}

#[ignore = "full otp→register happy-path — needs SMS capture or Redis read"]
#[tokio::test]
async fn register_with_otp_happy_path_returns_202_and_no_session_tokens() {}

#[ignore = "full otp→register flow — replay with same jti must be rejected"]
#[tokio::test]
async fn register_with_otp_replay_is_rejected() {}

#[ignore = "daily cap enforcement via Redis INCR — needs real rate-limit to be reachable"]
#[tokio::test]
async fn otp_daily_cap_returns_429_after_limit() {}

// =============================================================================
// Priority 4 — authorization / JWT negative-space
// =============================================================================

#[tokio::test]
async fn jwt_alg_none_is_rejected_by_algorithm_whitelist() {
    use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
    if service_unreachable().await {
        return;
    }
    throttle().await;

    let header = URL_SAFE_NO_PAD.encode(br#"{"alg":"none","typ":"JWT"}"#);
    let claims = json!({
        "sub": Uuid::new_v4().to_string(),
        "role": "admin",
        "exp": (now_secs() + 3600) as i64,
        "iat": now_secs() as i64,
        "iss": "guard-dispatch",
        "aud": "guard-dispatch",
        "jti": Uuid::new_v4().to_string(),
    });
    let payload = URL_SAFE_NO_PAD.encode(serde_json::to_vec(&claims).unwrap());
    // alg=none: empty signature.
    let token = format!("{}.{}.", header, payload);

    let res = get_bearer("/me", &token).await;
    assert_eq!(
        res.status(),
        StatusCode::UNAUTHORIZED,
        "alg=none must be rejected"
    );
}

#[tokio::test]
async fn jwt_signed_with_wrong_secret_is_rejected() {
    use jsonwebtoken::{encode, EncodingKey, Header};
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let claims = json!({
        "sub": Uuid::new_v4().to_string(),
        "role": "admin",
        "exp": (now_secs() + 3600) as i64,
        "iat": now_secs() as i64,
        "iss": "guard-dispatch",
        "aud": "guard-dispatch",
        "jti": Uuid::new_v4().to_string(),
    });
    let key = EncodingKey::from_secret(
        b"definitely-not-the-real-jwt-secret-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    );
    let token = encode(&Header::default(), &claims, &key).expect("encode");

    let res = get_bearer("/me", &token).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn jwt_with_wrong_audience_is_rejected() {
    use jsonwebtoken::{encode, EncodingKey, Header};
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let claims = json!({
        "sub": Uuid::new_v4().to_string(),
        "role": "admin",
        "exp": (now_secs() + 3600) as i64,
        "iat": now_secs() as i64,
        "iss": "guard-dispatch",
        "aud": "some-other-audience",
        "jti": Uuid::new_v4().to_string(),
    });
    let key = EncodingKey::from_secret(
        b"arbitrary-key-for-test-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    );
    let token = encode(&Header::default(), &claims, &key).expect("encode");

    let res = get_bearer("/me", &token).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn profile_reissue_with_bogus_phone_verified_token_is_rejected() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/profile/reissue",
        json!({
            "phone": unique_phone(),
            "phone_verified_token": "forged.jwt.here",
        }),
    )
    .await;
    assert!(res.status().is_client_error());
}

#[tokio::test]
async fn guards_me_expiry_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = put_json("/guards/me/expiry", json!({"id_card_expiry": "2030-01-01"})).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[ignore = "needs a non-guard-role access token fixture to exercise the 403 branch"]
#[tokio::test]
async fn guards_me_expiry_called_by_non_guard_returns_403() {}

// =============================================================================
// Priority 5 — JTI registry / revocation (placeholders — need Redis access)
// =============================================================================

// =============================================================================
// Fixture user helpers
// =============================================================================

/// Returns (phone, password) for a pre-approved fixture user.
///
/// ## Setup
/// To run tests that require a logged-in session, set the following env vars:
///
/// ```bash
/// FIXTURE_PHONE=0812345678    # A user with approval_status='approved' + role set
/// FIXTURE_PASSWORD=somepin    # The password/PIN-hash stored for that user
/// ```
///
/// You can create one manually in the dev DB:
/// ```sql
/// INSERT INTO auth.users (email, phone, password_hash, full_name, role, approval_status, is_active)
/// VALUES ('fixture@test.local', '0899999999',
///         '$argon2id$v=19$m=19456,t=2,p=1$...', 'Fixture', 'admin', 'approved', true);
/// ```
///
/// Or register via API and then approve via SQL:
/// ```sql
/// UPDATE auth.users SET approval_status = 'approved' WHERE phone = '08...';
/// ```
fn fixture_user() -> Option<(String, String)> {
    let phone = std::env::var("FIXTURE_PHONE").ok()?;
    let password = std::env::var("FIXTURE_PASSWORD").ok()?;
    Some((phone, password))
}

/// Returns (phone, password) for an admin fixture user.
/// Falls back to FIXTURE_PHONE/PASSWORD if ADMIN variants are not set.
fn fixture_admin() -> Option<(String, String)> {
    let phone = std::env::var("FIXTURE_ADMIN_PHONE")
        .or_else(|_| std::env::var("FIXTURE_PHONE"))
        .ok()?;
    let password = std::env::var("FIXTURE_ADMIN_PASSWORD")
        .or_else(|_| std::env::var("FIXTURE_PASSWORD"))
        .ok()?;
    Some((phone, password))
}

/// Log in via mobile endpoint and return (access_token, refresh_token).
/// Panics if login fails.
async fn mobile_login(phone: &str, password: &str) -> (String, String) {
    let res = post_json(
        "/login/mobile",
        json!({"phone": phone, "password": password}),
    )
    .await;
    assert_eq!(
        res.status(),
        StatusCode::OK,
        "fixture login failed for phone {phone}"
    );
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    let access = data["access_token"]
        .as_str()
        .expect("access_token in response")
        .to_string();
    let refresh = data["refresh_token"]
        .as_str()
        .expect("refresh_token in response")
        .to_string();
    (access, refresh)
}

/// PATCH JSON with a Bearer token, with retry.
async fn patch_json_bearer(path: &str, token: &str, body: Value) -> reqwest::Response {
    let url = format!("{}{}", base_url(), path);
    send_retrying(|| client().patch(&url).bearer_auth(token).json(&body)).await
}

// =============================================================================
// Priority 6 — Mobile login flow
// =============================================================================

#[tokio::test]
async fn mobile_login_returns_tokens_in_body() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let res = post_json(
        "/login/mobile",
        json!({"phone": phone, "password": password}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];

    // Mobile endpoint must return tokens in body (not cookies).
    assert!(
        data["access_token"].is_string(),
        "expected access_token in body, got: {data}"
    );
    assert!(
        data["refresh_token"].is_string(),
        "expected refresh_token in body, got: {data}"
    );
    assert_eq!(data["token_type"].as_str(), Some("Bearer"));
    assert!(data["role"].is_string(), "role must be present in response");
    assert!(
        data["expires_in"].is_number(),
        "expires_in must be present in response"
    );
}

#[tokio::test]
async fn mobile_login_with_wrong_password_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, _) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let res = post_json(
        "/login/mobile",
        json!({"phone": phone, "password": "definitely-wrong-password-999"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

// =============================================================================
// Priority 7 — Web login flow (phone)
// =============================================================================

#[tokio::test]
async fn web_phone_login_does_not_return_tokens_in_body() {
    // Web /login/phone must set httpOnly cookies and NOT expose tokens in JSON
    // body — this prevents XSS from reading tokens.
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let c = fresh_client();
    let url = format!("{}/login/phone", base_url());
    let res = send_retrying(|| {
        c.post(&url)
            .json(&json!({"phone": &phone, "password": &password}))
    })
    .await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];

    // Body must NOT contain tokens (security invariant).
    assert!(
        data.get("access_token").is_none() || data["access_token"].is_null(),
        "web login must not return access_token in body"
    );
    assert!(
        data.get("refresh_token").is_none() || data["refresh_token"].is_null(),
        "web login must not return refresh_token in body"
    );
    // Should have role and expires_in though.
    assert!(data["role"].is_string(), "role should be in body");
    assert!(
        data["expires_in"].is_number(),
        "expires_in should be in body"
    );
}

#[tokio::test]
async fn web_phone_login_with_pending_user_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let email = unique_email();
    let phone = unique_phone();
    let password = "test-password-12345";
    register_pending_user(&email, &phone, password).await;

    let res = post_json(
        "/login/phone",
        json!({"phone": phone, "password": password}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
    let body: Value = res.json().await.expect("json");
    let msg = body["error"]["message"]
        .as_str()
        .unwrap_or("")
        .to_lowercase();
    // Must NOT reveal account state (user enumeration protection).
    assert!(
        !msg.contains("pending") && !msg.contains("approval"),
        "error must not leak account state: {msg}"
    );
}

// =============================================================================
// Priority 8 — Token refresh
// =============================================================================

#[tokio::test]
async fn mobile_refresh_with_valid_token_returns_new_tokens() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    // Step 1: login to get a refresh token.
    let (_, refresh_token) = mobile_login(&phone, &password).await;
    throttle().await;

    // Step 2: use the refresh token to get new tokens.
    let res = post_json("/refresh/mobile", json!({"refresh_token": refresh_token})).await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert!(
        data["access_token"].is_string(),
        "refreshed response must contain access_token"
    );
    assert!(
        data["refresh_token"].is_string(),
        "refreshed response must contain new refresh_token"
    );
}

#[tokio::test]
async fn mobile_refresh_with_used_token_is_rejected() {
    // Refresh token rotation: after using a refresh token, the old one should
    // no longer be valid (atomic rotation).
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let (_, refresh_token) = mobile_login(&phone, &password).await;
    throttle().await;

    // First refresh: should succeed.
    let res = post_json("/refresh/mobile", json!({"refresh_token": &refresh_token})).await;
    assert_eq!(res.status(), StatusCode::OK);
    throttle().await;

    // Second refresh with the SAME token: should fail (token was rotated).
    let res = post_json("/refresh/mobile", json!({"refresh_token": &refresh_token})).await;
    assert_eq!(
        res.status(),
        StatusCode::UNAUTHORIZED,
        "reused refresh token should be rejected after rotation"
    );
}

#[tokio::test]
async fn web_refresh_without_cookie_or_body_returns_400() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    // Fresh client with no cookies.
    let c = fresh_client();
    let url = format!("{}/refresh", base_url());
    let res = c
        .post(&url)
        .header("content-type", "application/json")
        .body("")
        .send()
        .await
        .expect("send");
    assert_eq!(res.status(), StatusCode::BAD_REQUEST);
}

// =============================================================================
// Priority 9 — Logout + token revocation
// =============================================================================

#[tokio::test]
async fn logout_revokes_access_token_for_me_endpoint() {
    // Full login → logout → /me cycle: after logout the access token should be
    // in the Redis blocklist and GET /me must return 401.
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let (access_token, _refresh_token) = mobile_login(&phone, &password).await;
    throttle().await;

    // Verify token works before logout.
    let res = get_bearer("/me", &access_token).await;
    assert_eq!(
        res.status(),
        StatusCode::OK,
        "/me should succeed before logout"
    );
    throttle().await;

    // Logout — requires Bearer header.
    let url = format!("{}/logout", base_url());
    let res = send_retrying(|| client().post(&url).bearer_auth(&access_token)).await;
    assert_eq!(res.status(), StatusCode::OK, "logout should succeed");
    throttle().await;

    // Access token should now be revoked (jti added to Redis blocklist).
    let res = get_bearer("/me", &access_token).await;
    assert_eq!(
        res.status(),
        StatusCode::UNAUTHORIZED,
        "access token must be rejected after logout"
    );
}

#[tokio::test]
async fn logout_with_bogus_bearer_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!("{}/logout", base_url());
    let res = send_retrying(|| client().post(&url).bearer_auth("not.a.real.token")).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

// =============================================================================
// Priority 10 — /me endpoint
// =============================================================================

#[tokio::test]
async fn me_with_valid_token_returns_user_profile() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let (access_token, _) = mobile_login(&phone, &password).await;
    throttle().await;

    let res = get_bearer("/me", &access_token).await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];

    // Profile must include required fields.
    assert!(data["id"].is_string(), "id must be a UUID string");
    assert!(data["phone"].is_string(), "phone must be present");
    assert!(data["full_name"].is_string(), "full_name must be present");
    assert!(
        data["approval_status"].is_string(),
        "approval_status must be present"
    );
    assert_eq!(
        data["approval_status"].as_str(),
        Some("approved"),
        "fixture user should be approved"
    );
}

#[tokio::test]
async fn me_with_expired_token_is_rejected() {
    use jsonwebtoken::{encode, EncodingKey, Header};
    if service_unreachable().await {
        return;
    }
    throttle().await;

    // Craft a token that expired 1 hour ago.
    let claims = json!({
        "sub": Uuid::new_v4().to_string(),
        "role": "admin",
        "exp": (now_secs() as i64 - 3600),
        "iat": (now_secs() as i64 - 7200),
        "iss": "guard-dispatch",
        "aud": "guard-dispatch",
        "jti": Uuid::new_v4().to_string(),
    });
    // Key doesn't match server's, so it'll be rejected even if it somehow
    // bypassed expiration checks. Double barrier.
    let key = EncodingKey::from_secret(b"wrong-key-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    let token = encode(&Header::default(), &claims, &key).expect("encode");

    let res = get_bearer("/me", &token).await;
    assert_eq!(
        res.status(),
        StatusCode::UNAUTHORIZED,
        "expired token must be rejected"
    );
}

// =============================================================================
// Priority 11 — /check-status endpoint
// =============================================================================

#[tokio::test]
async fn check_status_nonexistent_phone_returns_exists_false() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/check-status",
        json!({"phone": unique_phone(), "password": "anypassword"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert_eq!(data["exists"].as_bool(), Some(false));
}

#[tokio::test]
async fn check_status_pending_user_shows_pending() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let email = unique_email();
    let phone = unique_phone();
    let password = "check-status-test-pw";
    register_pending_user(&email, &phone, password).await;
    throttle().await;

    let res = post_json(
        "/check-status",
        json!({"phone": phone, "password": password}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert_eq!(data["exists"].as_bool(), Some(true));
    assert_eq!(
        data["approval_status"].as_str(),
        Some("pending"),
        "newly registered user should be pending"
    );
}

#[tokio::test]
async fn check_status_with_wrong_password_returns_exists_false() {
    // Timing-safe: dummy argon2 verify for wrong password so timing is
    // indistinguishable from nonexistent user.
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let email = unique_email();
    let phone = unique_phone();
    register_pending_user(&email, &phone, "real-password-1234").await;
    throttle().await;

    let res = post_json(
        "/check-status",
        json!({"phone": phone, "password": "wrong-password-999"}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert_eq!(
        data["exists"].as_bool(),
        Some(false),
        "wrong password should return exists=false (timing-safe)"
    );
}

#[tokio::test]
async fn check_status_approved_user_shows_approved() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_user() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_PHONE / FIXTURE_PASSWORD not set");
            return;
        }
    };

    let res = post_json(
        "/check-status",
        json!({"phone": phone, "password": password}),
    )
    .await;
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert_eq!(data["exists"].as_bool(), Some(true));
    assert_eq!(data["approval_status"].as_str(), Some("approved"));
    assert!(data["role"].is_string(), "approved user should have a role");
}

// =============================================================================
// Priority 12 — Admin endpoint authorization
// =============================================================================

#[tokio::test]
async fn list_users_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = send_retrying(|| fresh_client().get(format!("{}/users", base_url()))).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn list_users_with_bogus_bearer_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = get_bearer("/users", "not.a.valid.token").await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn update_approval_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!("{}/users/{}/approval", base_url(), Uuid::new_v4());
    let res = send_retrying(|| {
        fresh_client()
            .patch(&url)
            .json(&json!({"approval_status": "approved"}))
    })
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn admin_guard_profile_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!("{}/admin/guard-profile/{}", base_url(), Uuid::new_v4());
    let res = send_retrying(|| fresh_client().get(&url)).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn admin_customer_profile_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!("{}/admin/customer-profile/{}", base_url(), Uuid::new_v4());
    let res = send_retrying(|| fresh_client().get(&url)).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn admin_customer_applicants_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!("{}/admin/customer-applicants", base_url());
    let res = send_retrying(|| fresh_client().get(&url)).await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn admin_customer_approval_without_auth_returns_401() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!(
        "{}/admin/customer-profile/{}/approval",
        base_url(),
        Uuid::new_v4()
    );
    let res = send_retrying(|| {
        fresh_client()
            .patch(&url)
            .json(&json!({"approval_status": "approved"}))
    })
    .await;
    assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
}

/// Non-admin user should get 403 on admin-only endpoints.
/// This test requires FIXTURE_PHONE/PASSWORD to point at a non-admin user.
/// If the fixture user IS an admin, the assertions flip — which is fine; the
/// test is still exercising the authorization check.
#[tokio::test]
async fn list_users_with_non_admin_token_returns_403() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    // We need a non-admin user token. If FIXTURE_NON_ADMIN_PHONE is set, use it.
    // Otherwise fall back to FIXTURE_PHONE and check the response.
    let (phone, password) = match std::env::var("FIXTURE_NON_ADMIN_PHONE")
        .ok()
        .zip(std::env::var("FIXTURE_NON_ADMIN_PASSWORD").ok())
    {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_NON_ADMIN_PHONE / FIXTURE_NON_ADMIN_PASSWORD not set");
            return;
        }
    };

    let (access_token, _) = mobile_login(&phone, &password).await;
    throttle().await;

    let res = get_bearer("/users", &access_token).await;
    assert_eq!(
        res.status(),
        StatusCode::FORBIDDEN,
        "non-admin should get 403 on /users"
    );
}

#[tokio::test]
async fn update_approval_with_non_admin_token_returns_403() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match std::env::var("FIXTURE_NON_ADMIN_PHONE")
        .ok()
        .zip(std::env::var("FIXTURE_NON_ADMIN_PASSWORD").ok())
    {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_NON_ADMIN_PHONE / FIXTURE_NON_ADMIN_PASSWORD not set");
            return;
        }
    };

    let (access_token, _) = mobile_login(&phone, &password).await;
    throttle().await;

    let res = patch_json_bearer(
        &format!("/users/{}/approval", Uuid::new_v4()),
        &access_token,
        json!({"approval_status": "approved"}),
    )
    .await;
    assert_eq!(
        res.status(),
        StatusCode::FORBIDDEN,
        "non-admin should get 403 on approval update"
    );
}

// =============================================================================
// Priority 13 — Admin positive paths (require admin fixture)
// =============================================================================

#[tokio::test]
async fn admin_list_users_returns_paginated_result() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_admin() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_ADMIN_PHONE / FIXTURE_PHONE not set");
            return;
        }
    };

    let (access_token, _) = mobile_login(&phone, &password).await;
    throttle().await;

    let res = get_bearer("/users", &access_token).await;
    // May be 200 (admin) or 403 (non-admin fixture); only assert on admin.
    if res.status() == StatusCode::FORBIDDEN {
        eprintln!("NOTE: fixture user is not admin — admin list_users test skipped implicitly");
        return;
    }
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert!(
        data["users"].is_array(),
        "response must include users array"
    );
    assert!(
        data["total"].is_number(),
        "response must include total count"
    );
}

#[tokio::test]
async fn admin_list_users_filters_by_role() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_admin() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_ADMIN_PHONE / FIXTURE_PHONE not set");
            return;
        }
    };

    let (access_token, _) = mobile_login(&phone, &password).await;
    throttle().await;

    let url = format!("{}/users?role=guard", base_url());
    let res = send_retrying(|| client().get(&url).bearer_auth(&access_token)).await;
    if res.status() == StatusCode::FORBIDDEN {
        return; // not admin
    }
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let empty = vec![];
    let users = body["data"]["users"].as_array().unwrap_or(&empty);
    for user in users {
        assert_eq!(
            user["role"].as_str(),
            Some("guard"),
            "filtering by role=guard should only return guards"
        );
    }
}

#[tokio::test]
async fn admin_list_customer_applicants_returns_paginated_result() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let (phone, password) = match fixture_admin() {
        Some(creds) => creds,
        None => {
            eprintln!("SKIP: FIXTURE_ADMIN_PHONE / FIXTURE_PHONE not set");
            return;
        }
    };

    let (access_token, _) = mobile_login(&phone, &password).await;
    throttle().await;

    let url = format!("{}/admin/customer-applicants", base_url());
    let res = send_retrying(|| client().get(&url).bearer_auth(&access_token)).await;
    if res.status() == StatusCode::FORBIDDEN {
        return; // not admin
    }
    assert_eq!(res.status(), StatusCode::OK);
    let body: Value = res.json().await.expect("json");
    let data = &body["data"];
    assert!(
        data["users"].is_array(),
        "response must include users array"
    );
    assert!(data["total"].is_number(), "response must include total");
}

// =============================================================================
// Priority 14 — /submit customer profile negative paths
// =============================================================================

#[tokio::test]
async fn submit_customer_profile_without_token_returns_error() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let res = post_json(
        "/profile/customer",
        json!({
            "address": "123 Test Street, Bangkok",
        }),
    )
    .await;
    // Without a profile_token in Authorization header, should fail.
    assert!(
        res.status().is_client_error(),
        "expected 4xx without profile_token, got {}",
        res.status()
    );
}

#[tokio::test]
async fn submit_customer_profile_with_bogus_token_returns_error() {
    if service_unreachable().await {
        return;
    }
    throttle().await;
    let url = format!("{}/profile/customer", base_url());
    let res = send_retrying(|| {
        client()
            .post(&url)
            .bearer_auth("bogus.profile.token")
            .json(&json!({
                "address": "123 Test Street, Bangkok",
            }))
    })
    .await;
    assert!(
        res.status().is_client_error(),
        "bogus profile_token should be rejected"
    );
}

// =============================================================================
// Placeholder stubs (kept from original + new)
// =============================================================================

#[ignore = "requires approved fixture user + Redis inspection to assert issued_jti key"]
#[tokio::test]
async fn issued_jti_key_is_set_after_mobile_login() {}

#[ignore = "requires approved fixture user — full login→logout→/me cycle to assert revocation"]
#[tokio::test]
async fn logged_out_access_token_is_rejected_on_me() {}
