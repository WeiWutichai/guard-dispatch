use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Multipart, Path, Query, State};
use axum::response::IntoResponse;
use axum::Json;
use std::sync::Arc;
use uuid::Uuid;

use shared::auth::AuthUser;
use shared::error::{AppError, ErrorBody};
use shared::models::ApiResponse;

/// Schema-only struct for documenting multipart upload in Swagger UI.
/// Not used in code — Axum uses `Multipart` extractor directly.
#[allow(dead_code)]
#[derive(utoipa::ToSchema)]
pub struct AttachmentUploadForm {
    /// UUID of the conversation
    pub conversation_id: String,
    /// Image or video file (JPEG/PNG/WEBP max 10MB, MP4/MOV max 50MB)
    #[schema(format = "binary")]
    pub file: Vec<u8>,
}

use crate::models::{
    AttachmentResponse, ConversationResponse, CreateConversationRequest,
    EnrichedConversationResponse, IncomingChatMessage, ListConversationsQuery, ListMessagesQuery,
    MessageResponse,
};
use crate::state::AppState;

// =============================================================================
// WebSocket Chat
// =============================================================================

#[utoipa::path(
    get,
    path = "/ws/chat",
    tag = "Chat WebSocket",
    security(("bearer" = [])),
    responses(
        (status = 101, description = "WebSocket upgrade for real-time chat. Send IncomingChatMessage JSON after connection."),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn ws_handler(
    State(state): State<Arc<AppState>>,
    ws: WebSocketUpgrade,
    user: AuthUser,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_chat_socket(socket, state, user))
}

async fn handle_chat_socket(mut socket: WebSocket, state: Arc<AppState>, user: AuthUser) {
    tracing::info!("Chat WebSocket connected: user_id={}", user.user_id);

    // Rate limiting: max 5 messages per second per connection
    let mut last_message_at = std::time::Instant::now() - std::time::Duration::from_secs(1);
    let min_interval = std::time::Duration::from_millis(200); // 5 msg/s

    // Ping/pong: detect zombie connections (same pattern as GPS WebSocket)
    let ping_interval = std::time::Duration::from_secs(30);
    let pong_timeout = std::time::Duration::from_secs(10);
    let mut last_activity = std::time::Instant::now();
    let mut ping_sent_at: Option<std::time::Instant> = None;

    loop {
        let wait_duration = if let Some(sent) = ping_sent_at {
            pong_timeout.saturating_sub(sent.elapsed())
        } else {
            ping_interval.saturating_sub(last_activity.elapsed())
        };

        let msg = match tokio::time::timeout(wait_duration, socket.recv()).await {
            Ok(Some(msg)) => msg,
            Ok(None) => break,
            Err(_) => {
                if ping_sent_at.is_some() {
                    tracing::warn!("Chat WS pong timeout: user_id={}", user.user_id);
                    break;
                }
                if socket.send(Message::Ping(vec![].into())).await.is_err() {
                    break;
                }
                ping_sent_at = Some(std::time::Instant::now());
                continue;
            }
        };

        let text = match msg {
            Ok(Message::Text(text)) => {
                last_activity = std::time::Instant::now();
                ping_sent_at = None;
                text
            }
            Ok(Message::Pong(_)) => {
                last_activity = std::time::Instant::now();
                ping_sent_at = None;
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
        if now.duration_since(last_message_at) < min_interval {
            continue;
        }
        last_message_at = now;

        let incoming: IncomingChatMessage = match serde_json::from_str(&text) {
            Ok(m) => m,
            Err(e) => {
                let _ = socket
                    .send(Message::Text(
                        serde_json::json!({"error": format!("Invalid message: {e}")})
                            .to_string()
                            .into(),
                    ))
                    .await;
                continue;
            }
        };

        match crate::service::send_message(&state.db, &state.redis_pubsub, user.user_id, incoming)
            .await
        {
            Ok(outgoing) => {
                let json = serde_json::to_string(&outgoing).unwrap_or_default();
                let _ = socket.send(Message::Text(json.into())).await;
            }
            Err(e) => {
                let _ = socket
                    .send(Message::Text(
                        serde_json::json!({"error": e.to_string()})
                            .to_string()
                            .into(),
                    ))
                    .await;
            }
        }
    }

    tracing::info!("Chat WebSocket disconnected: user_id={}", user.user_id);
}

// =============================================================================
// REST Endpoints
// =============================================================================

#[utoipa::path(
    post,
    path = "/conversations",
    tag = "Conversations",
    security(("bearer" = [])),
    request_body = CreateConversationRequest,
    responses(
        (status = 200, description = "Conversation created", body = ConversationResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn create_conversation(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Json(req): Json<CreateConversationRequest>,
) -> Result<Json<ApiResponse<ConversationResponse>>, AppError> {
    // Authorization: caller must be a participant or admin
    if user.role != "admin" && !req.participant_ids.contains(&user.user_id) {
        return Err(AppError::Forbidden(
            "You must be a participant of the conversation".to_string(),
        ));
    }

    let conversation = crate::service::create_conversation(&state.db, req).await?;
    Ok(Json(ApiResponse::success(conversation)))
}

#[utoipa::path(
    get,
    path = "/conversations",
    tag = "Conversations",
    security(("bearer" = [])),
    params(ListConversationsQuery),
    responses(
        (status = 200, description = "List of conversations with last message and participant info", body = Vec<EnrichedConversationResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn list_conversations(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Query(query): Query<ListConversationsQuery>,
) -> Result<Json<ApiResponse<Vec<EnrichedConversationResponse>>>, AppError> {
    let acting_role = query.role.as_deref().unwrap_or(&user.role);
    let conversations =
        crate::service::list_conversations(&state.db, user.user_id, acting_role).await?;
    Ok(Json(ApiResponse::success(conversations)))
}

#[utoipa::path(
    get,
    path = "/conversations/{id}/messages",
    tag = "Messages",
    security(("bearer" = [])),
    params(
        ("id" = Uuid, Path, description = "Conversation UUID"),
        ListMessagesQuery,
    ),
    responses(
        (status = 200, description = "Message history", body = Vec<MessageResponse>),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
    ),
)]
pub async fn list_messages(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
    Query(query): Query<ListMessagesQuery>,
) -> Result<Json<ApiResponse<Vec<MessageResponse>>>, AppError> {
    let messages =
        crate::service::list_messages(&state.db, id, user.user_id, &user.role, query).await?;
    Ok(Json(ApiResponse::success(messages)))
}

#[utoipa::path(
    put,
    path = "/conversations/{id}/read",
    tag = "Conversations",
    security(("bearer" = [])),
    params(
        ("id" = Uuid, Path, description = "Conversation UUID"),
        ListConversationsQuery,
    ),
    responses(
        (status = 200, description = "Marked as read"),
        (status = 401, description = "Unauthorized", body = ErrorBody),
    ),
)]
pub async fn mark_read(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
    Query(query): Query<ListConversationsQuery>,
) -> Result<Json<ApiResponse<()>>, AppError> {
    // Authorization: only participants or admins can mark conversations as read
    if user.role != "admin" {
        let is_participant = crate::service::is_conversation_participant_by_conversation(
            &state.db,
            id,
            user.user_id,
        )
        .await?;
        if !is_participant {
            return Err(AppError::Forbidden(
                "You are not a participant of this conversation".to_string(),
            ));
        }
    }
    let acting_role = query.role.as_deref().unwrap_or(&user.role);
    crate::service::mark_read(&state.db, id, user.user_id, acting_role).await?;
    Ok(Json(ApiResponse::success(())))
}

#[utoipa::path(
    post,
    path = "/attachments",
    tag = "Attachments",
    security(("bearer" = [])),
    request_body(content = AttachmentUploadForm, content_type = "multipart/form-data"),
    responses(
        (status = 200, description = "Attachment uploaded", body = AttachmentResponse),
        (status = 400, description = "Invalid file or missing fields", body = ErrorBody),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Not a participant", body = ErrorBody),
    ),
)]
pub async fn upload_attachment(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    mut multipart: Multipart,
) -> Result<Json<ApiResponse<AttachmentResponse>>, AppError> {
    let mut conversation_id: Option<Uuid> = None;
    let mut file_data: Option<Vec<u8>> = None;
    let mut mime_type: Option<String> = None;
    let mut original_filename: Option<String> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(format!("Failed to read multipart: {e}")))?
    {
        let name = field.name().unwrap_or("").to_string();

        match name.as_str() {
            "conversation_id" => {
                let text = field
                    .text()
                    .await
                    .map_err(|e| AppError::BadRequest(format!("Invalid conversation_id: {e}")))?;
                conversation_id = Some(
                    text.parse::<Uuid>()
                        .map_err(|e| AppError::BadRequest(format!("Invalid UUID: {e}")))?,
                );
            }
            "file" => {
                mime_type = field.content_type().map(|s| s.to_string());
                original_filename = field.file_name().map(|s| s.to_string());
                file_data = Some(
                    field
                        .bytes()
                        .await
                        .map_err(|e| AppError::BadRequest(format!("Failed to read file: {e}")))?
                        .to_vec(),
                );
            }
            _ => {}
        }
    }

    let conversation_id = conversation_id
        .ok_or_else(|| AppError::BadRequest("conversation_id is required".to_string()))?;

    // Authorization: verify uploader is a participant in this conversation or admin
    if user.role != "admin" {
        let is_participant = crate::service::is_conversation_participant_by_conversation(
            &state.db,
            conversation_id,
            user.user_id,
        )
        .await?;
        if !is_participant {
            return Err(AppError::Forbidden(
                "You are not a participant in this conversation".to_string(),
            ));
        }
    }

    let data = file_data.ok_or_else(|| AppError::BadRequest("file is required".to_string()))?;
    let mime = mime_type.unwrap_or_else(|| "application/octet-stream".to_string());

    // Validate file (checks MIME + magic bytes + size — images 10MB, videos 50MB)
    crate::s3::validate_upload(&mime, data.len(), &data)?;

    let ext = crate::s3::mime_to_extension(&mime);

    // file_key format: chat/{conversation_id}/{uuid}.{ext} (per CLAUDE.md)
    let file_uuid = Uuid::new_v4();
    let file_key = format!("chat/{conversation_id}/{file_uuid}.{ext}");

    let data_len = data.len();

    // Upload to S3/MinIO (consumes data, no clone needed)
    crate::s3::upload_file(&state.s3_client, &state.s3_bucket, &file_key, data, &mime).await?;

    // Generate signed URL and rewrite host for client access (per CLAUDE.md presigned URL host rewrite)
    let raw_url = crate::s3::get_signed_url(&state.s3_client, &state.s3_bucket, &file_key).await?;
    let file_url = if state.s3_endpoint != state.s3_public_url {
        raw_url.replacen(&state.s3_endpoint, &state.s3_public_url, 1)
    } else {
        raw_url
    };

    // Determine message type based on MIME
    let message_type = if crate::s3::is_video_mime(&mime) {
        crate::models::MessageType::Video
    } else {
        crate::models::MessageType::Image
    };

    // Insert message (without publish — we'll publish with file_url after saving attachment)
    let msg = crate::models::IncomingChatMessage {
        conversation_id,
        content: original_filename,
        message_type: Some(message_type),
        sender_role: None,
    };
    let row = crate::service::insert_message(&state.db, user.user_id, &msg).await?;

    // Save attachment metadata
    let attachment = crate::service::save_attachment(
        &state.db,
        row.id,
        user.user_id,
        &file_key,
        &file_url,
        Some(data_len as i32),
        &mime,
    )
    .await?;

    // Publish to Redis with file_url included so receiving clients can display media
    let outgoing = crate::models::OutgoingChatMessage {
        id: row.id,
        conversation_id: row.conversation_id,
        sender_id: row.sender_id,
        content: row.content,
        message_type: row.message_type,
        sender_role: row.sender_role,
        created_at: row.created_at,
        file_url: Some(file_url),
        file_mime_type: Some(mime),
    };
    crate::service::publish_chat_message(&state.redis_pubsub, &outgoing).await;

    Ok(Json(ApiResponse::success(attachment)))
}

#[utoipa::path(
    get,
    path = "/attachments/{id}",
    tag = "Attachments",
    security(("bearer" = [])),
    params(("id" = Uuid, Path, description = "Attachment UUID")),
    responses(
        (status = 200, description = "Attachment with fresh signed URL", body = AttachmentResponse),
        (status = 401, description = "Unauthorized", body = ErrorBody),
        (status = 403, description = "Forbidden", body = ErrorBody),
        (status = 404, description = "Not found", body = ErrorBody),
    ),
)]
pub async fn get_signed_url(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiResponse<AttachmentResponse>>, AppError> {
    let attachment = crate::service::get_attachment(&state.db, id).await?;

    // Authorization: only the uploader or a conversation participant can access
    let is_participant =
        crate::service::is_conversation_participant(&state.db, attachment.message_id, user.user_id)
            .await?;

    if !is_participant && user.role != "admin" {
        return Err(AppError::Forbidden(
            "You do not have access to this attachment".to_string(),
        ));
    }

    // Regenerate signed URL (previous one may have expired) + host rewrite
    let raw_url =
        crate::s3::get_signed_url(&state.s3_client, &state.s3_bucket, &attachment.file_key).await?;
    let fresh_url = if state.s3_endpoint != state.s3_public_url {
        raw_url.replacen(&state.s3_endpoint, &state.s3_public_url, 1)
    } else {
        raw_url
    };

    Ok(Json(ApiResponse::success(AttachmentResponse {
        id: attachment.id,
        message_id: attachment.message_id,
        file_key: attachment.file_key,
        file_url: fresh_url,
        file_size: attachment.file_size,
        mime_type: attachment.mime_type,
        created_at: attachment.created_at,
    })))
}
