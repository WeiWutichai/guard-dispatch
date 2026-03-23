use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Path, Query, State};
use axum::response::IntoResponse;
use axum::Json;
use chrono::Utc;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{
    GpsEvent, GpsUpdate, GuardLocationWithName, HistoryQuery, LocationHistoryResponse,
    LocationResponse, LocationsQuery,
};
use crate::state::AppState;

#[utoipa::path(
    get,
    path = "/ws/track",
    tag = "GPS Tracking",
    security(("bearer" = [])),
    responses(
        (status = 101, description = "WebSocket upgrade for real-time GPS tracking. Send GpsUpdate JSON messages."),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn ws_handler(
    State(state): State<Arc<AppState>>,
    ws: WebSocketUpgrade,
    user: AuthUser,
) -> Result<impl IntoResponse, AppError> {
    // Only guards can stream GPS data
    if user.role != "guard" {
        return Err(AppError::Forbidden(
            "Only guards can stream GPS data".to_string(),
        ));
    }

    Ok(ws.on_upgrade(move |socket| handle_gps_socket(socket, state, user)))
}

async fn handle_gps_socket(mut socket: WebSocket, state: Arc<AppState>, user: AuthUser) {
    tracing::info!("GPS WebSocket connected: guard_id={}", user.user_id);

    // Mark guard as online immediately (before any GPS data arrives).
    // This ensures stationary guards (no GPS delta) are still discoverable.
    if let Err(e) = crate::service::set_online(&state.db, user.user_id).await {
        tracing::error!("Failed to set guard online: {e}");
    }

    // Server-side rate limiting: max 1 update per second per connection
    let mut last_update = std::time::Instant::now() - std::time::Duration::from_secs(1);
    let min_interval = std::time::Duration::from_secs(1);

    // Ping/pong: detect zombie connections (e.g. guard killed app, lost signal)
    let ping_interval = std::time::Duration::from_secs(30);
    let pong_timeout = std::time::Duration::from_secs(10);
    let mut last_activity = std::time::Instant::now();
    let mut ping_sent_at: Option<std::time::Instant> = None;

    loop {
        // Calculate how long until next ping or pong timeout
        let wait_duration = if let Some(sent) = ping_sent_at {
            // Waiting for pong — timeout after pong_timeout
            pong_timeout.saturating_sub(sent.elapsed())
        } else {
            // Waiting for next ping interval
            ping_interval.saturating_sub(last_activity.elapsed())
        };

        let msg = match tokio::time::timeout(wait_duration, socket.recv()).await {
            Ok(Some(msg)) => msg,
            Ok(None) => break, // stream ended
            Err(_) => {
                // Timeout fired
                if ping_sent_at.is_some() {
                    // Pong not received in time — zombie connection
                    tracing::warn!("GPS WebSocket pong timeout: guard_id={}", user.user_id);
                    break;
                }
                // Send ping
                if socket.send(Message::Ping(vec![].into())).await.is_err() {
                    break;
                }
                ping_sent_at = Some(std::time::Instant::now());
                continue;
            }
        };

        let msg = match msg {
            Ok(Message::Text(text)) => {
                last_activity = std::time::Instant::now();
                ping_sent_at = None; // any data counts as alive
                text
            }
            Ok(Message::Pong(_)) => {
                last_activity = std::time::Instant::now();
                ping_sent_at = None;
                // Refresh recorded_at so stationary guards (no GPS delta)
                // don't fall off the 30-min filter in available-guards query
                let _ = crate::service::set_online(&state.db, user.user_id).await;
                continue;
            }
            Ok(Message::Close(_)) => break,
            Err(e) => {
                tracing::warn!("WebSocket recv error: {e}");
                break;
            }
            _ => continue,
        };

        // Rate limit: drop messages that arrive too fast
        let now = std::time::Instant::now();
        if now.duration_since(last_update) < min_interval {
            continue;
        }
        last_update = now;

        let update: GpsUpdate = match serde_json::from_str(&msg) {
            Ok(u) => u,
            Err(e) => {
                let _ = socket
                    .send(Message::Text(
                        serde_json::json!({"error": format!("Invalid GPS data: {e}")}).to_string().into(),
                    ))
                    .await;
                continue;
            }
        };

        // Validate GPS coordinates
        if let Err(e) = update.validate() {
            let _ = socket
                .send(Message::Text(
                    serde_json::json!({"error": e}).to_string().into(),
                ))
                .await;
            continue;
        }

        let event = GpsEvent {
            guard_id: user.user_id,
            lat: update.lat,
            lng: update.lng,
            accuracy: update.accuracy,
            heading: update.heading,
            speed: update.speed,
            recorded_at: Utc::now(),
        };

        // Run DB ops and Redis publish concurrently — they're independent
        let (upsert_res, history_res, publish_res) = tokio::join!(
            crate::service::upsert_location(&state.db, user.user_id, &update),
            crate::service::append_history(&state.db, user.user_id, &update),
            crate::service::publish_gps_event(&state.redis_pubsub, &event),
        );

        if let Err(e) = upsert_res {
            tracing::error!("Failed to upsert location: {e}");
        }
        if let Err(e) = history_res {
            tracing::error!("Failed to append history: {e}");
        }
        if let Err(e) = publish_res {
            tracing::error!("Failed to publish GPS event: {e}");
        }

        // Send acknowledgment back
        let _ = socket
            .send(Message::Text(
                serde_json::json!({"status": "ok", "recorded_at": event.recorded_at}).to_string().into(),
            ))
            .await;
    }

    // Mark guard as offline in DB so available_guards query excludes them immediately
    if let Err(e) = crate::service::set_offline(&state.db, user.user_id).await {
        tracing::error!("Failed to set guard offline: {e}");
    }
    tracing::info!("GPS WebSocket disconnected: guard_id={}", user.user_id);
}

#[utoipa::path(
    get,
    path = "/locations/{guard_id}",
    tag = "Locations",
    security(("bearer" = [])),
    params(("guard_id" = Uuid, Path, description = "Guard UUID")),
    responses(
        (status = 200, description = "Latest guard location", body = LocationResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guards can only see own location", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn get_latest_location(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(guard_id): Path<uuid::Uuid>,
) -> Result<Json<ApiResponse<LocationResponse>>, AppError> {
    // Guards can only see their own location
    if user.role == "guard" && user.user_id != guard_id {
        return Err(AppError::Forbidden(
            "Guards can only access their own location".to_string(),
        ));
    }

    // Customers can only see guards they have an active booking with
    if user.role == "customer" || (user.role == "guard" && user.user_id != guard_id) {
        let has_booking = crate::service::has_active_booking(&state.db, user.user_id, guard_id).await?;
        if !has_booking {
            return Err(AppError::Forbidden(
                "You can only track guards assigned to your active booking".to_string(),
            ));
        }
    }

    let location = crate::service::get_latest_location(&state.db, guard_id).await?;
    Ok(Json(ApiResponse::success(location)))
}

#[utoipa::path(
    get,
    path = "/locations/{guard_id}/history",
    tag = "Locations",
    security(("bearer" = [])),
    params(
        ("guard_id" = Uuid, Path, description = "Guard UUID"),
        HistoryQuery,
    ),
    responses(
        (status = 200, description = "Location history", body = Vec<LocationHistoryResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn get_location_history(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(guard_id): Path<uuid::Uuid>,
    Query(query): Query<HistoryQuery>,
) -> Result<Json<ApiResponse<Vec<LocationHistoryResponse>>>, AppError> {
    // Guards can only see their own history
    if user.role == "guard" && user.user_id != guard_id {
        return Err(AppError::Forbidden(
            "Guards can only access their own location history".to_string(),
        ));
    }

    // Customers can only see history for guards they have/had a booking with
    if user.role == "customer" {
        let has_booking = crate::service::has_active_booking(&state.db, user.user_id, guard_id).await?;
        if !has_booking {
            return Err(AppError::Forbidden(
                "You can only view history for guards assigned to your booking".to_string(),
            ));
        }
    }

    let history = crate::service::get_location_history(&state.db, guard_id, query).await?;
    Ok(Json(ApiResponse::success(history)))
}

#[utoipa::path(
    get,
    path = "/locations",
    tag = "Locations",
    security(("bearer" = [])),
    responses(
        (status = 200, description = "All active guard locations", body = Vec<GuardLocationWithName>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden — guards cannot access this endpoint", body = ErrorBody),
    ),
)]
pub async fn list_all_locations(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(params): Query<LocationsQuery>,
) -> Result<Json<ApiResponse<Vec<GuardLocationWithName>>>, AppError> {
    // Only admins and customers can view the admin map overview
    if user.role == "guard" {
        return Err(AppError::Forbidden(
            "Guards cannot access bulk location data".to_string(),
        ));
    }

    let online_only = params.online_only.unwrap_or(false);
    let locations = crate::service::get_all_locations(&state.db, online_only).await?;
    Ok(Json(ApiResponse::success(locations)))
}
