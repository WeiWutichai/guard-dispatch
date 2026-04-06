use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

// =============================================================================
// Enums
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type, ToSchema)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "message_type", rename_all = "lowercase")]
pub enum MessageType {
    Text,
    Image,
    Video,
    System,
}

// =============================================================================
// WebSocket Messages
// =============================================================================

#[derive(Debug, Deserialize, ToSchema)]
pub struct IncomingChatMessage {
    pub conversation_id: Uuid,
    pub content: Option<String>,
    pub message_type: Option<MessageType>,
    pub sender_role: Option<String>,
}

#[derive(Debug, Serialize, Clone, ToSchema)]
pub struct OutgoingChatMessage {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: Uuid,
    pub content: Option<String>,
    pub message_type: MessageType,
    pub sender_role: Option<String>,
    pub created_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file_mime_type: Option<String>,
}

// =============================================================================
// Request DTOs
// =============================================================================

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateConversationRequest {
    pub request_id: Uuid,
    pub participant_ids: Vec<Uuid>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListConversationsQuery {
    /// Acting role: "guard" or "customer". Determines which counterpart name to show.
    pub role: Option<String>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListMessagesQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// =============================================================================
// Response DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct ConversationResponse {
    pub id: Uuid,
    pub request_id: Uuid,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct EnrichedConversationResponse {
    pub id: Uuid,
    pub request_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub last_message: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub participant_name: Option<String>,
    pub participant_avatar: Option<String>,
    pub unread_count: Option<i64>,
    pub request_status: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct MessageResponse {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: Uuid,
    pub content: Option<String>,
    pub message_type: MessageType,
    pub sender_role: Option<String>,
    pub created_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file_mime_type: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AttachmentResponse {
    pub id: Uuid,
    pub message_id: Uuid,
    pub file_key: String,
    pub file_url: String,
    pub file_size: Option<i32>,
    pub mime_type: String,
    pub created_at: DateTime<Utc>,
}

// =============================================================================
// Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct ConversationRow {
    pub id: Uuid,
    pub request_id: Uuid,
    pub created_at: DateTime<Utc>,
}

impl From<ConversationRow> for ConversationResponse {
    fn from(row: ConversationRow) -> Self {
        Self {
            id: row.id,
            request_id: row.request_id,
            created_at: row.created_at,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct EnrichedConversationRow {
    pub id: Uuid,
    pub request_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub last_message: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub participant_name: Option<String>,
    pub participant_avatar: Option<String>,
    pub unread_count: Option<i64>,
    pub request_status: Option<String>,
}

impl From<EnrichedConversationRow> for EnrichedConversationResponse {
    fn from(row: EnrichedConversationRow) -> Self {
        Self {
            id: row.id,
            request_id: row.request_id,
            created_at: row.created_at,
            last_message: row.last_message,
            last_message_at: row.last_message_at,
            participant_name: row.participant_name,
            participant_avatar: row.participant_avatar,
            unread_count: row.unread_count,
            request_status: row.request_status,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct MessageRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: Uuid,
    pub content: Option<String>,
    pub message_type: MessageType,
    pub sender_role: Option<String>,
    pub created_at: DateTime<Utc>,
}

impl From<MessageRow> for MessageResponse {
    fn from(row: MessageRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id,
            content: row.content,
            message_type: row.message_type,
            sender_role: row.sender_role,
            created_at: row.created_at,
            file_url: None,
            file_mime_type: None,
        }
    }
}

impl From<MessageRow> for OutgoingChatMessage {
    fn from(row: MessageRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id,
            content: row.content,
            message_type: row.message_type,
            sender_role: row.sender_role,
            created_at: row.created_at,
            file_url: None,
            file_mime_type: None,
        }
    }
}

/// Row type for list_messages with LEFT JOIN on attachments
#[derive(Debug, sqlx::FromRow)]
pub struct MessageWithAttachmentRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: Uuid,
    pub content: Option<String>,
    pub message_type: MessageType,
    pub sender_role: Option<String>,
    pub created_at: DateTime<Utc>,
    pub file_url: Option<String>,
    pub file_mime_type: Option<String>,
}

impl From<MessageWithAttachmentRow> for MessageResponse {
    fn from(row: MessageWithAttachmentRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id,
            content: row.content,
            message_type: row.message_type,
            sender_role: row.sender_role,
            created_at: row.created_at,
            file_url: row.file_url,
            file_mime_type: row.file_mime_type,
        }
    }
}

#[allow(dead_code)]
#[derive(Debug, sqlx::FromRow)]
pub struct AttachmentRow {
    pub id: Uuid,
    pub message_id: Uuid,
    pub uploader_id: Uuid,
    pub file_key: String,
    pub file_url: String,
    pub file_size: Option<i32>,
    pub mime_type: String,
    pub created_at: DateTime<Utc>,
}

impl From<AttachmentRow> for AttachmentResponse {
    fn from(row: AttachmentRow) -> Self {
        Self {
            id: row.id,
            message_id: row.message_id,
            file_key: row.file_key,
            file_url: row.file_url,
            file_size: row.file_size,
            mime_type: row.mime_type,
            created_at: row.created_at,
        }
    }
}
