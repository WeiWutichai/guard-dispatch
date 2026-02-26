---
name: websocket
description: Use this skill when implementing WebSocket connections in the guard-dispatch project. Triggers include: "WebSocket", "GPS tracking", "real-time location", "chat websocket", "ws connection", "สร้าง WebSocket", or any real-time bidirectional communication task.
---

# WebSocket Skill — Guard Dispatch

## สองกรณีที่ใช้ WebSocket ในโปรเจกต์นี้
1. **tracking-service** (Port 3003) — GPS location updates จาก รปภ.
2. **chat-service** (Port 3006) — Real-time messaging + รูปภาพ

## Performance Target
- GPS update: **< 3 วินาที** (Critical)
- Chat delivery: **< 1 วินาที**

---

## Pattern: GPS Tracking WebSocket

```rust
// services/tracking/src/handlers/ws.rs
use axum::{
    extract::{ws::{WebSocket, WebSocketUpgrade, Message}, State, Path},
    response::IntoResponse,
};
use redis::AsyncCommands;
use uuid::Uuid;

pub async fn tracking_ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
    Path(guard_id): Path<Uuid>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_tracking_socket(socket, state, guard_id))
}

async fn handle_tracking_socket(mut socket: WebSocket, state: AppState, guard_id: Uuid) {
    while let Some(msg) = socket.recv().await {
        match msg {
            Ok(Message::Text(text)) => {
                // Parse GPS payload
                let Ok(location) = serde_json::from_str::<LocationUpdate>(&text) else {
                    let _ = socket.send(Message::Text(r#"{"error":"invalid payload"}"#.into())).await;
                    continue;
                };

                // บันทึกลง DB
                let _ = sqlx::query!(
                    "INSERT INTO tracking.locations (guard_id, lat, lng) VALUES ($1, $2, $3)",
                    guard_id,
                    location.lat,
                    location.lng,
                )
                .execute(&state.db)
                .await;

                // Broadcast ผ่าน Redis Pub/Sub
                let mut conn = state.redis_pubsub.get_async_connection().await.unwrap();
                let payload = serde_json::to_string(&location).unwrap();
                let _: () = conn.publish(format!("tracking:{}", guard_id), payload).await.unwrap();

                let _ = socket.send(Message::Text(r#"{"status":"ok"}"#.into())).await;
            }
            Ok(Message::Close(_)) => break,
            Err(_) => break,
            _ => {}
        }
    }
}

#[derive(serde::Deserialize, serde::Serialize)]
struct LocationUpdate {
    lat: f64,
    lng: f64,
    timestamp: i64,
}
```

---

## Pattern: Chat WebSocket

```rust
// services/chat/src/handlers/ws.rs
use axum::extract::ws::{WebSocket, Message};
use std::sync::Arc;
use tokio::sync::broadcast;

// Room manager — เก็บ broadcast channel ต่อ chat_id
pub type Rooms = Arc<tokio::sync::RwLock<
    std::collections::HashMap<Uuid, broadcast::Sender<String>>
>>;

pub async fn chat_ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
    Path(chat_id): Path<Uuid>,
    auth: AuthUser,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_chat_socket(socket, state, chat_id, auth))
}

async fn handle_chat_socket(
    mut socket: WebSocket,
    state: AppState,
    chat_id: Uuid,
    auth: AuthUser,
) {
    // เข้า room
    let tx = {
        let mut rooms = state.rooms.write().await;
        rooms.entry(chat_id)
            .or_insert_with(|| broadcast::channel(100).0)
            .clone()
    };
    let mut rx = tx.subscribe();

    loop {
        tokio::select! {
            // รับ message จาก client
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        // บันทึกลง DB
                        sqlx::query!(
                            "INSERT INTO chat.messages (chat_id, sender_id, content)
                             VALUES ($1, $2, $3)",
                            chat_id,
                            Uuid::parse_str(&auth.0.sub).unwrap(),
                            text,
                        )
                        .execute(&state.db)
                        .await
                        .ok();

                        // Broadcast ไป clients อื่นใน room
                        let _ = tx.send(text.to_string());
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
            // ส่ง broadcast ไปยัง client นี้
            msg = rx.recv() => {
                if let Ok(text) = msg {
                    if socket.send(Message::Text(text.into())).await.is_err() {
                        break;
                    }
                }
            }
        }
    }
}
```

---

## Flutter: เชื่อมต่อ WebSocket

```dart
// GPS Tracking (รปภ. ส่ง location)
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('ws://10.0.2.2:80/tracking/$guardId'),
);

// ส่ง GPS
channel.sink.add(jsonEncode({
  'lat': position.latitude,
  'lng': position.longitude,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
}));

// Chat
final chatChannel = WebSocketChannel.connect(
  Uri.parse('ws://10.0.2.2:80/chat/$chatId'),
);

chatChannel.stream.listen((message) {
  // แสดงข้อความ
});
```

---

## Nginx Config สำหรับ WebSocket
```nginx
# nginx/nginx.conf — ต้องมี upgrade headers
location /tracking/ {
    proxy_pass http://rust-tracking:3003/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;  # 1 ชั่วโมง
}

location /chat/ {
    proxy_pass http://rust-chat:3006/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
}
```

## ข้อควรระวัง
- ต้องส่ง `Message::Close` ก่อน drop connection เสมอ
- GPS ใช้ Redis Pub/Sub broadcast — ไม่ใช่ broadcast channel ใน memory
- Chat ใช้ tokio broadcast channel ต่อ room (เร็วกว่าสำหรับ in-process)
- ทุก WebSocket handler ต้องผ่าน JWT validation
