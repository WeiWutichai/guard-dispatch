use redis::AsyncCommands;
use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    AttachmentResponse, AttachmentRow, ConversationResponse, ConversationRow,
    CreateConversationRequest, EnrichedConversationResponse, EnrichedConversationRow,
    IncomingChatMessage, ListMessagesQuery, MessageResponse, MessageRow, MessageType,
    MessageWithAttachmentRow, OutgoingChatMessage,
};

// =============================================================================
// Notification Helper (fire-and-forget, cross-schema INSERT)
// =============================================================================

fn spawn_chat_notification(
    db: PgPool,
    recipient_id: Uuid,
    sender_name: String,
    message_preview: String,
    conversation_id: Uuid,
) {
    tokio::spawn(async move {
        let title = format!("ข้อความจาก {sender_name}");
        let body = if message_preview.is_empty() {
            "📎 ไฟล์แนบ".to_string()
        } else {
            message_preview.chars().take(100).collect::<String>()
        };
        let payload = serde_json::json!({
            "conversation_id": conversation_id.to_string(),
        });
        let _ = sqlx::query(
            r#"
            INSERT INTO notification.notification_logs (user_id, title, body, notification_type, payload)
            VALUES ($1, $2, $3, 'chat_message'::notification_type, $4)
            "#,
        )
        .bind(recipient_id)
        .bind(&title)
        .bind(&body)
        .bind(&payload)
        .execute(&db)
        .await;
    });
}

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
    acting_role: &str,
) -> Result<Vec<EnrichedConversationResponse>, AppError> {
    // $2 = true when acting as customer → show guard name
    // $2 = false when acting as guard   → show customer name
    let is_customer = acting_role == "customer";

    let acting_role_str = acting_role.to_string();

    let rows = sqlx::query_as::<_, EnrichedConversationRow>(
        r#"
        SELECT c.id, c.request_id, c.created_at,
            (SELECT m.content FROM chat.messages m
             WHERE m.conversation_id = c.id
             ORDER BY m.created_at DESC LIMIT 1) AS last_message,
            (SELECT m.created_at FROM chat.messages m
             WHERE m.conversation_id = c.id
             ORDER BY m.created_at DESC LIMIT 1) AS last_message_at,
            CASE
                WHEN $2 THEN
                    (SELECT u2.full_name FROM booking.assignments a2
                     INNER JOIN auth.users u2 ON u2.id = a2.guard_id
                     WHERE a2.request_id = c.request_id LIMIT 1)
                ELSE
                    COALESCE(cp_cust.full_name, u_cust.full_name)
            END AS participant_name,
            CASE
                WHEN $2 THEN
                    (SELECT u2.avatar_url FROM booking.assignments a2
                     INNER JOIN auth.users u2 ON u2.id = a2.guard_id
                     WHERE a2.request_id = c.request_id LIMIT 1)
                ELSE
                    u_cust.avatar_url
            END AS participant_avatar,
            (SELECT COUNT(*) FROM chat.messages m2
             WHERE m2.conversation_id = c.id
               AND m2.sender_role IS DISTINCT FROM $3
               AND m2.created_at > COALESCE(
                   (SELECT rr.read_at FROM chat.read_receipts rr
                    WHERE rr.conversation_id = c.id
                      AND rr.user_id = $1
                      AND rr.user_role = $3),
                   '1970-01-01'::timestamptz
               )
            ) AS unread_count,
            gr.status::text AS request_status
        FROM chat.conversations c
        INNER JOIN chat.conversation_participants cp ON cp.conversation_id = c.id
        INNER JOIN booking.guard_requests gr ON gr.id = c.request_id
        INNER JOIN auth.users u_cust ON u_cust.id = gr.customer_id
        LEFT JOIN auth.customer_profiles cp_cust ON cp_cust.user_id = gr.customer_id
        WHERE cp.user_id = $1
        ORDER BY last_message_at DESC NULLS LAST
        "#,
    )
    .bind(user_id)
    .bind(is_customer)
    .bind(&acting_role_str)
    .fetch_all(db)
    .await?;

    Ok(rows
        .into_iter()
        .map(EnrichedConversationResponse::from)
        .collect())
}

// =============================================================================
// Send Message (text — used by WebSocket handler)
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

    let row = insert_message(db, sender_id, &msg).await?;
    let outgoing = OutgoingChatMessage::from(row);
    publish_chat_message(redis_pubsub, &outgoing).await;

    // Notify other participants (fire-and-forget)
    let recipients: Vec<Uuid> = sqlx::query_scalar(
        "SELECT user_id FROM chat.conversation_participants WHERE conversation_id = $1 AND user_id != $2",
    )
    .bind(msg.conversation_id)
    .bind(sender_id)
    .fetch_all(db)
    .await
    .unwrap_or_default();

    // Get sender name for notification title
    let sender_name: String =
        sqlx::query_scalar("SELECT COALESCE(full_name, 'User') FROM auth.users WHERE id = $1")
            .bind(sender_id)
            .fetch_optional(db)
            .await
            .ok()
            .flatten()
            .unwrap_or_else(|| "User".to_string());

    for recipient_id in recipients {
        spawn_chat_notification(
            db.clone(),
            recipient_id,
            sender_name.clone(),
            msg.content.clone().unwrap_or_default(),
            msg.conversation_id,
        );
    }

    Ok(outgoing)
}

// =============================================================================
// Insert Message (DB only, no publish — used by upload handler)
// =============================================================================

pub async fn insert_message(
    db: &PgPool,
    sender_id: Uuid,
    msg: &IncomingChatMessage,
) -> Result<MessageRow, AppError> {
    let message_type = msg.message_type.clone().unwrap_or(MessageType::Text);
    let mtype_str = serde_json::to_value(&message_type)
        .map_err(|e| AppError::Internal(format!("Failed to serialize message type: {e}")))?
        .as_str()
        .unwrap_or("text")
        .to_string();

    let row = sqlx::query_as::<_, MessageRow>(
        r#"
        INSERT INTO chat.messages (conversation_id, sender_id, content, message_type, sender_role)
        VALUES ($1, $2, $3, $4::message_type, $5)
        RETURNING id, conversation_id, sender_id, content, message_type, sender_role, created_at
        "#,
    )
    .bind(msg.conversation_id)
    .bind(sender_id)
    .bind(&msg.content)
    .bind(&mtype_str)
    .bind(&msg.sender_role)
    .fetch_one(db)
    .await?;

    Ok(row)
}

// =============================================================================
// Publish Chat Message to Redis PubSub
// =============================================================================

pub async fn publish_chat_message(
    redis_pubsub: &redis::aio::MultiplexedConnection,
    outgoing: &OutgoingChatMessage,
) {
    let channel = format!("chat:{}", outgoing.conversation_id);
    if let Ok(payload) = serde_json::to_string(outgoing) {
        let mut conn = redis_pubsub.clone();
        let _ = conn.publish::<_, _, ()>(&channel, &payload).await;
    }
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

    let rows = sqlx::query_as::<_, MessageWithAttachmentRow>(
        r#"
        SELECT m.id, m.conversation_id, m.sender_id, m.content, m.message_type, m.sender_role, m.created_at,
               a.file_url, a.mime_type AS file_mime_type
        FROM chat.messages m
        LEFT JOIN chat.attachments a ON a.message_id = m.id
        WHERE m.conversation_id = $1
        ORDER BY m.created_at DESC
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

pub async fn get_attachment(db: &PgPool, attachment_id: Uuid) -> Result<AttachmentRow, AppError> {
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

// =============================================================================
// Mark Conversation as Read
// =============================================================================

pub async fn mark_read(
    db: &PgPool,
    conversation_id: Uuid,
    user_id: Uuid,
    user_role: &str,
) -> Result<(), AppError> {
    sqlx::query(
        r#"
        INSERT INTO chat.read_receipts (conversation_id, user_id, user_role, read_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (conversation_id, user_id, user_role)
        DO UPDATE SET read_at = NOW()
        "#,
    )
    .bind(conversation_id)
    .bind(user_id)
    .bind(user_role)
    .execute(db)
    .await?;

    Ok(())
}
