use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Path, Query, State};
use axum::response::IntoResponse;
use axum::Json;
use chrono::Utc;
use std::sync::Arc;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

use crate::models::{GpsEvent, GpsUpdate, HistoryQuery, LocationHistoryResponse, LocationResponse};
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
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_gps_socket(socket, state, user))
}

async fn handle_gps_socket(mut socket: WebSocket, state: Arc<AppState>, user: AuthUser) {
    tracing::info!("GPS WebSocket connected: guard_id={}", user.user_id);

    while let Some(msg) = socket.recv().await {
        let msg = match msg {
            Ok(Message::Text(text)) => text,
            Ok(Message::Close(_)) => break,
            Err(e) => {
                tracing::warn!("WebSocket recv error: {e}");
                break;
            }
            _ => continue,
        };

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
    // Guards can only see their own location; admins and customers (with active booking) can see any
    if user.role == "guard" && user.user_id != guard_id {
        return Err(AppError::Forbidden(
            "Guards can only access their own location".to_string(),
        ));
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
    // Guards can only see their own history; admins and customers (with active booking) can see any
    if user.role == "guard" && user.user_id != guard_id {
        return Err(AppError::Forbidden(
            "Guards can only access their own location history".to_string(),
        ));
    }

    let history = crate::service::get_location_history(&state.db, guard_id, query).await?;
    Ok(Json(ApiResponse::success(history)))
}
