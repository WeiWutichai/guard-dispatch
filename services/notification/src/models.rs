use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

// =============================================================================
// Enums
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "notification_type", rename_all = "snake_case")]
pub enum NotificationType {
    BookingCreated,
    GuardAssigned,
    GuardEnRoute,
    GuardArrived,
    BookingCompleted,
    BookingCancelled,
    ChatMessage,
    System,
}

// =============================================================================
// Request DTOs
// =============================================================================

#[derive(Debug, Deserialize, ToSchema)]
pub struct RegisterTokenRequest {
    pub token: String,
    pub device_type: String,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct SendNotificationRequest {
    pub user_id: Uuid,
    pub title: String,
    pub body: String,
    pub notification_type: NotificationType,
    pub payload: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct ListNotificationsQuery {
    pub unread_only: Option<bool>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    /// Filter by target role (guard/customer) from payload.
    pub role: Option<String>,
}

#[derive(Debug, Deserialize, IntoParams)]
pub struct RoleQuery {
    /// Filter by target role (guard/customer) from payload.
    pub role: Option<String>,
}

// =============================================================================
// Response DTOs
// =============================================================================

#[derive(Debug, Serialize, ToSchema)]
pub struct NotificationLogResponse {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub body: String,
    pub notification_type: NotificationType,
    pub payload: Option<serde_json::Value>,
    pub is_read: bool,
    pub sent_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct UnreadCountResponse {
    pub count: i64,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct FcmTokenResponse {
    pub id: Uuid,
    pub token: String,
    pub device_type: String,
    pub created_at: DateTime<Utc>,
}

// =============================================================================
// Database row types
// =============================================================================

#[derive(Debug, sqlx::FromRow)]
pub struct NotificationLogRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub body: String,
    pub notification_type: NotificationType,
    pub payload: Option<serde_json::Value>,
    pub is_read: bool,
    pub sent_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
}

impl From<NotificationLogRow> for NotificationLogResponse {
    fn from(row: NotificationLogRow) -> Self {
        Self {
            id: row.id,
            user_id: row.user_id,
            title: row.title,
            body: row.body,
            notification_type: row.notification_type,
            payload: row.payload,
            is_read: row.is_read,
            sent_at: row.sent_at,
            read_at: row.read_at,
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct FcmTokenRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub token: String,
    pub device_type: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
