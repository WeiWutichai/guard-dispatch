use sqlx::PgPool;
use uuid::Uuid;

use shared::error::AppError;

use crate::models::{
    FcmTokenRow, ListNotificationsQuery, NotificationLogResponse, NotificationLogRow,
    SendNotificationRequest,
};
use crate::fcm::FcmAuth;

// =============================================================================
// Register FCM Token
// =============================================================================

pub async fn register_token(
    db: &PgPool,
    user_id: Uuid,
    token: &str,
    device_type: &str,
) -> Result<(), AppError> {
    // Upsert — same token gets linked to current user
    sqlx::query(
        r#"
        INSERT INTO notification.fcm_tokens (user_id, token, device_type)
        VALUES ($1, $2, $3)
        ON CONFLICT (token)
        DO UPDATE SET user_id = $1, device_type = $3, updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(token)
    .bind(device_type)
    .execute(db)
    .await?;

    Ok(())
}

// =============================================================================
// Unregister FCM Token
// =============================================================================

pub async fn unregister_token(db: &PgPool, user_id: Uuid, token: &str) -> Result<(), AppError> {
    sqlx::query("DELETE FROM notification.fcm_tokens WHERE user_id = $1 AND token = $2")
        .bind(user_id)
        .bind(token)
        .execute(db)
        .await?;

    Ok(())
}

// =============================================================================
// List Notifications
// =============================================================================

pub async fn list_notifications(
    db: &PgPool,
    user_id: Uuid,
    query: ListNotificationsQuery,
) -> Result<Vec<NotificationLogResponse>, AppError> {
    let limit = query.limit.unwrap_or(20).min(100);
    let offset = query.offset.unwrap_or(0);
    let unread_only = query.unread_only.unwrap_or(false);
    let role = query.role.as_deref();

    let rows = sqlx::query_as::<_, NotificationLogRow>(
        r#"
        SELECT id, user_id, title, body, notification_type, payload, is_read, sent_at, read_at
        FROM notification.notification_logs
        WHERE user_id = $1
          AND ($4::text IS NULL OR payload->>'target_role' = $4 OR payload->>'target_role' IS NULL)
          AND (NOT $5 OR is_read = false)
        ORDER BY sent_at DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(user_id)
    .bind(limit)
    .bind(offset)
    .bind(role)
    .bind(unread_only)
    .fetch_all(db)
    .await?;

    Ok(rows
        .into_iter()
        .map(NotificationLogResponse::from)
        .collect())
}

// =============================================================================
// Get Unread Count
// =============================================================================

pub async fn get_unread_count(
    db: &PgPool,
    user_id: Uuid,
    role: Option<&str>,
) -> Result<i64, AppError> {
    let row: (i64,) = sqlx::query_as(
        r#"
        SELECT COUNT(*) FROM notification.notification_logs
        WHERE user_id = $1 AND is_read = false
          AND ($2::text IS NULL OR payload->>'target_role' = $2 OR payload->>'target_role' IS NULL)
        "#,
    )
    .bind(user_id)
    .bind(role)
    .fetch_one(db)
    .await?;

    Ok(row.0)
}

// =============================================================================
// Mark as Read
// =============================================================================

pub async fn mark_as_read(
    db: &PgPool,
    notification_id: Uuid,
    user_id: Uuid,
) -> Result<NotificationLogResponse, AppError> {
    let row = sqlx::query_as::<_, NotificationLogRow>(
        r#"
        UPDATE notification.notification_logs
        SET is_read = true, read_at = NOW()
        WHERE id = $1 AND user_id = $2
        RETURNING id, user_id, title, body, notification_type, payload, is_read, sent_at, read_at
        "#,
    )
    .bind(notification_id)
    .bind(user_id)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| AppError::NotFound("Notification not found".to_string()))?;

    Ok(NotificationLogResponse::from(row))
}

// =============================================================================
// Mark All as Read
// =============================================================================

pub async fn mark_all_as_read(
    db: &PgPool,
    user_id: Uuid,
    role: Option<&str>,
) -> Result<i64, AppError> {
    let result = sqlx::query(
        r#"
        UPDATE notification.notification_logs
        SET is_read = true, read_at = NOW()
        WHERE user_id = $1 AND is_read = false
          AND ($2::text IS NULL OR payload->>'target_role' = $2 OR payload->>'target_role' IS NULL)
        "#,
    )
    .bind(user_id)
    .bind(role)
    .execute(db)
    .await?;

    Ok(result.rows_affected() as i64)
}

// =============================================================================
// Send Notification (creates log + sends via FCM)
// =============================================================================

pub async fn send_notification(
    db: &PgPool,
    http_client: &reqwest::Client,
    fcm_auth: &FcmAuth,
    req: SendNotificationRequest,
) -> Result<NotificationLogResponse, AppError> {
    let ntype_str = serde_json::to_value(&req.notification_type)
        .map_err(|e| AppError::Internal(format!("Failed to serialize notification type: {e}")))?
        .as_str()
        .unwrap_or("system")
        .to_string();

    // Insert notification log
    let row = sqlx::query_as::<_, NotificationLogRow>(
        r#"
        INSERT INTO notification.notification_logs (user_id, title, body, notification_type, payload)
        VALUES ($1, $2, $3, $4::notification_type, $5)
        RETURNING id, user_id, title, body, notification_type, payload, is_read, sent_at, read_at
        "#,
    )
    .bind(req.user_id)
    .bind(&req.title)
    .bind(&req.body)
    .bind(&ntype_str)
    .bind(&req.payload)
    .fetch_one(db)
    .await?;

    // Get user's FCM tokens
    let tokens: Vec<FcmTokenRow> = sqlx::query_as::<_, FcmTokenRow>(
        r#"
        SELECT id, user_id, token, device_type, created_at, updated_at
        FROM notification.fcm_tokens
        WHERE user_id = $1
        "#,
    )
    .bind(req.user_id)
    .fetch_all(db)
    .await?;

    // Send FCM push to all user devices
    for token_row in &tokens {
        if let Err(e) = send_fcm_push(
            http_client,
            fcm_auth,
            &token_row.token,
            &req.title,
            &req.body,
            &req.payload,
        )
        .await
        {
            tracing::warn!(
                "Failed to send FCM push to token {}: {e}",
                token_row.token.get(..20).unwrap_or(&token_row.token)
            );
        }
    }

    Ok(NotificationLogResponse::from(row))
}

// =============================================================================
// FCM HTTP v1 API — OAuth 2.0 authenticated
// =============================================================================

async fn send_fcm_push(
    http_client: &reqwest::Client,
    fcm_auth: &FcmAuth,
    device_token: &str,
    title: &str,
    body: &str,
    data: &Option<serde_json::Value>,
) -> Result<(), AppError> {
    // Get a valid OAuth 2.0 access token (cached, auto-refreshes ~55 min)
    let access_token = fcm_auth.get_access_token().await?;

    let url = format!(
        "https://fcm.googleapis.com/v1/projects/{}/messages:send",
        fcm_auth.project_id()
    );

    let mut message = serde_json::json!({
        "message": {
            "token": device_token,
            "notification": {
                "title": title,
                "body": body,
            },
        }
    });

    if let Some(payload) = data {
        message["message"]["data"] = payload.clone();
    }

    let response = http_client
        .post(&url)
        .header("Authorization", format!("Bearer {access_token}"))
        .json(&message)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("FCM request failed: {e}")))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response
            .text()
            .await
            .unwrap_or_else(|_| "unknown".to_string());
        tracing::warn!("FCM API error: status={status}, body={body}");
    }

    Ok(())
}
