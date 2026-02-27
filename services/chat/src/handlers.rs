use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Multipart, Path, Query, State};
use axum::response::IntoResponse;
use axum::Json;
use std::sync::Arc;
use uuid::Uuid;

use shared::auth::AuthUser;
use shared::error::AppError;
use shared::models::ApiResponse;

use crate::models::{
    AttachmentResponse, ConversationResponse, CreateConversationRequest, IncomingChatMessage,
    ListMessagesQuery, MessageResponse,
};
use crate::state::AppState;

// =============================================================================
// WebSocket Chat
// =============================================================================

/// GET /ws/chat — WebSocket upgrade for real-time chat
pub async fn ws_handler(
    State(state): State<Arc<AppState>>,
    ws: WebSocketUpgrade,
    user: AuthUser,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_chat_socket(socket, state, user))
}

async fn handle_chat_socket(mut socket: WebSocket, state: Arc<AppState>, user: AuthUser) {
    tracing::info!("Chat WebSocket connected: user_id={}", user.user_id);

    while let Some(msg) = socket.recv().await {
        let text = match msg {
            Ok(Message::Text(text)) => text,
            Ok(Message::Close(_)) => break,
            Err(e) => {
                tracing::warn!("WebSocket recv error: {e}");
                break;
            }
            _ => continue,
        };

        let incoming: IncomingChatMessage = match serde_json::from_str(&text) {
            Ok(m) => m,
            Err(e) => {
                let _ = socket
                    .send(Message::Text(
                        serde_json::json!({"error": format!("Invalid message: {e}")}).to_string().into(),
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
                        serde_json::json!({"error": e.to_string()}).to_string().into(),
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

/// POST /conversations — Create a new conversation
pub async fn create_conversation(
    State(state): State<Arc<AppState>>,
    _user: AuthUser,
    Json(req): Json<CreateConversationRequest>,
) -> Result<Json<ApiResponse<ConversationResponse>>, AppError> {
    let conversation = crate::service::create_conversation(&state.db, req).await?;
    Ok(Json(ApiResponse::success(conversation)))
}

/// GET /conversations — List user's conversations
pub async fn list_conversations(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
) -> Result<Json<ApiResponse<Vec<ConversationResponse>>>, AppError> {
    let conversations = crate::service::list_conversations(&state.db, user.user_id).await?;
    Ok(Json(ApiResponse::success(conversations)))
}

/// GET /conversations/{id}/messages — Get message history
pub async fn list_messages(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
    Query(query): Query<ListMessagesQuery>,
) -> Result<Json<ApiResponse<Vec<MessageResponse>>>, AppError> {
    let messages = crate::service::list_messages(&state.db, id, user.user_id, query).await?;
    Ok(Json(ApiResponse::success(messages)))
}

/// POST /attachments — Upload image attachment (multipart)
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

    let conversation_id =
        conversation_id.ok_or_else(|| AppError::BadRequest("conversation_id is required".to_string()))?;

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

    let data =
        file_data.ok_or_else(|| AppError::BadRequest("file is required".to_string()))?;
    let mime = mime_type.unwrap_or_else(|| "application/octet-stream".to_string());

    // Validate file per CLAUDE.md rules (checks MIME + magic bytes + size)
    crate::s3::validate_upload(&mime, data.len(), &data)?;

    let ext = crate::s3::mime_to_extension(&mime);

    // file_key format: chat/{conversation_id}/{uuid}.{ext} (per CLAUDE.md)
    let file_uuid = Uuid::new_v4();
    let file_key = format!("chat/{conversation_id}/{file_uuid}.{ext}");

    let data_len = data.len();

    // Upload to S3/MinIO (consumes data, no clone needed)
    crate::s3::upload_file(&state.s3_client, &state.s3_bucket, &file_key, data, &mime)
        .await?;

    // Generate signed URL
    let file_url =
        crate::s3::get_signed_url(&state.s3_client, &state.s3_bucket, &file_key).await?;

    // Create image message
    let msg = crate::models::IncomingChatMessage {
        conversation_id,
        content: original_filename,
        message_type: Some(crate::models::MessageType::Image),
    };
    let outgoing =
        crate::service::send_message(&state.db, &state.redis_pubsub, user.user_id, msg).await?;

    // Save attachment metadata
    let attachment = crate::service::save_attachment(
        &state.db,
        outgoing.id,
        user.user_id,
        &file_key,
        &file_url,
        Some(data_len as i32),
        &mime,
    )
    .await?;

    Ok(Json(ApiResponse::success(attachment)))
}

/// GET /attachments/{id} — Get signed URL for an attachment
pub async fn get_signed_url(
    State(state): State<Arc<AppState>>,
    user: AuthUser,
    Path(id): Path<Uuid>,
) -> Result<Json<ApiResponse<AttachmentResponse>>, AppError> {
    let attachment = crate::service::get_attachment(&state.db, id).await?;

    // Authorization: only the uploader or a conversation participant can access
    let is_participant = crate::service::is_conversation_participant(
        &state.db,
        attachment.message_id,
        user.user_id,
    )
    .await?;

    if !is_participant && user.role != "admin" {
        return Err(AppError::Forbidden(
            "You do not have access to this attachment".to_string(),
        ));
    }

    // Regenerate signed URL (previous one may have expired)
    let fresh_url =
        crate::s3::get_signed_url(&state.s3_client, &state.s3_bucket, &attachment.file_key)
            .await?;

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
