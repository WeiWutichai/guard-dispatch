use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    AttachmentResponse, AttachmentRow, ConversationResponse, ConversationRow,
    CreateConversationRequest, IncomingChatMessage, ListMessagesQuery, MessageResponse, MessageRow,
    MessageType, OutgoingChatMessage,
};

// =============================================================================
// Create Conversation
// =============================================================================

pub async fn create_conversation(
    db: &PgPool,
    req: CreateConversationRequest,
) -> Result<ConversationResponse, AppError> {
    if req.participant_ids.is_empty() {
        return Err(AppError::BadRequest(
            "At least one participant is required".to_string(),
        ));
    }

    // Create conversation
    let conv = sqlx::query_as::<_, ConversationRow>(
        r#"
        INSERT INTO chat.conversations (request_id)
        VALUES ($1)
        RETURNING id, request_id, created_at
        "#,
    )
    .bind(req.request_id)
    .fetch_one(db)
    .await?;

    // Add participants
    for user_id in &req.participant_ids {
        sqlx::query(
            r#"
            INSERT INTO chat.conversation_participants (conversation_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT DO NOTHING
            "#,
        )
        .bind(conv.id)
        .bind(user_id)
        .execute(db)
        .await?;
    }

    Ok(ConversationResponse::from(conv))
}

// =============================================================================
// List Conversations for User
// =============================================================================

pub async fn list_conversations(
    db: &PgPool,
    user_id: Uuid,
) -> Result<Vec<ConversationResponse>, AppError> {
    let rows = sqlx::query_as::<_, ConversationRow>(
        r#"
        SELECT c.id, c.request_id, c.created_at
        FROM chat.conversations c
        INNER JOIN chat.conversation_participants cp ON cp.conversation_id = c.id
        WHERE cp.user_id = $1
        ORDER BY c.created_at DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(db)
    .await?;

    Ok(rows.into_iter().map(ConversationResponse::from).collect())
}

// =============================================================================
// Send Message
// =============================================================================

pub async fn send_message(
    db: &PgPool,
    redis_pubsub: &redis::aio::MultiplexedConnection,
    sender_id: Uuid,
    msg: IncomingChatMessage,
) -> Result<OutgoingChatMessage, AppError> {
    // Verify sender is participant
    let is_participant: Option<bool> = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM chat.conversation_participants
            WHERE conversation_id = $1 AND user_id = $2
        )
        "#,
    )
    .bind(msg.conversation_id)
    .bind(sender_id)
    .fetch_one(db)
    .await?;

    if !is_participant.unwrap_or(false) {
        return Err(AppError::Forbidden(
            "Not a participant of this conversation".to_string(),
        ));
    }

    let message_type = msg.message_type.unwrap_or(MessageType::Text);
    let mtype_str = serde_json::to_value(&message_type)
        .map_err(|e| AppError::Internal(format!("Failed to serialize message type: {e}")))?
        .as_str()
        .unwrap_or("text")
        .to_string();

    let row = sqlx::query_as::<_, MessageRow>(
        r#"
        INSERT INTO chat.messages (conversation_id, sender_id, content, message_type)
        VALUES ($1, $2, $3, $4::message_type)
        RETURNING id, conversation_id, sender_id, content, message_type, created_at
        "#,
    )
    .bind(msg.conversation_id)
    .bind(sender_id)
    .bind(&msg.content)
    .bind(&mtype_str)
    .fetch_one(db)
    .await?;

    let outgoing = OutgoingChatMessage::from(row);

    // Publish to Redis PubSub for real-time delivery
    let channel = format!("chat:{}", msg.conversation_id);
    let payload = serde_json::to_string(&outgoing)
        .map_err(|e| AppError::Internal(format!("Failed to serialize message: {e}")))?;

    // Clone is cheap — shares the underlying multiplexed connection
    let mut conn = redis_pubsub.clone();
    let _ = conn.publish::<_, _, ()>(&channel, &payload).await;

    Ok(outgoing)
}

// =============================================================================
// List Messages
// =============================================================================

pub async fn list_messages(
    db: &PgPool,
    conversation_id: Uuid,
    user_id: Uuid,
    user_role: &str,
    query: ListMessagesQuery,
) -> Result<Vec<MessageResponse>, AppError> {
    // Admin can access any conversation; others must be a participant
    if user_role != "admin" {
        let is_participant: Option<bool> = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM chat.conversation_participants
                WHERE conversation_id = $1 AND user_id = $2
            )
            "#,
        )
        .bind(conversation_id)
        .bind(user_id)
        .fetch_one(db)
        .await?;

        if !is_participant.unwrap_or(false) {
            return Err(AppError::Forbidden(
                "Not a participant of this conversation".to_string(),
            ));
        }
    }

    let limit = query.limit.unwrap_or(50).min(200);
    let offset = query.offset.unwrap_or(0);

    let rows = sqlx::query_as::<_, MessageRow>(
        r#"
        SELECT id, conversation_id, sender_id, content, message_type, created_at
        FROM chat.messages
        WHERE conversation_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(conversation_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(db)
    .await?;

    Ok(rows.into_iter().map(MessageResponse::from).collect())
}

// =============================================================================
// Save Attachment Metadata
// =============================================================================

pub async fn save_attachment(
    db: &PgPool,
    message_id: Uuid,
    uploader_id: Uuid,
    file_key: &str,
    file_url: &str,
    file_size: Option<i32>,
    mime_type: &str,
) -> Result<AttachmentResponse, AppError> {
    let row = sqlx::query_as::<_, AttachmentRow>(
        r#"
        INSERT INTO chat.attachments (message_id, uploader_id, file_key, file_url, file_size, mime_type)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, message_id, uploader_id, file_key, file_url, file_size, mime_type, created_at
        "#,
    )
    .bind(message_id)
    .bind(uploader_id)
    .bind(file_key)
    .bind(file_url)
    .bind(file_size)
    .bind(mime_type)
    .fetch_one(db)
    .await?;

    Ok(AttachmentResponse::from(row))
}

// =============================================================================
// Check conversation participant (by message_id for attachment authz)
// =============================================================================

pub async fn is_conversation_participant(
    db: &PgPool,
    message_id: Uuid,
    user_id: Uuid,
) -> Result<bool, AppError> {
    let result: Option<bool> = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM chat.conversation_participants cp
            INNER JOIN chat.messages m ON m.conversation_id = cp.conversation_id
            WHERE m.id = $1 AND cp.user_id = $2
        )
        "#,
    )
    .bind(message_id)
    .bind(user_id)
    .fetch_one(db)
    .await?;

    Ok(result.unwrap_or(false))
}

// =============================================================================
// Check conversation participant (by conversation_id for upload authz)
// =============================================================================

pub async fn is_conversation_participant_by_conversation(
    db: &PgPool,
    conversation_id: Uuid,
    user_id: Uuid,
) -> Result<bool, AppError> {
    let result: Option<bool> = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM chat.conversation_participants
            WHERE conversation_id = $1 AND user_id = $2
        )
        "#,
    )
    .bind(conversation_id)
    .bind(user_id)
    .fetch_one(db)
    .await?;

    Ok(result.unwrap_or(false))
}

// =============================================================================
// Get Attachment (for signed URL generation)
// =============================================================================

pub async fn get_attachment(
    db: &PgPool,
    attachment_id: Uuid,
) -> Result<AttachmentRow, AppError> {
    sqlx::query_as::<_, AttachmentRow>(
        r#"
        SELECT id, message_id, uploader_id, file_key, file_url, file_size, mime_type, created_at
        FROM chat.attachments
        WHERE id = $1
        "#,
    )
    .bind(attachment_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Attachment not found".to_string()))
}
