# Chat Media Presigned URL Expiry (history > 1h)

## Problem

`chat.messages` stores the presigned attachment `file_url`, and presigned URLs
expire after **1 hour** (`SIGNED_URL_EXPIRY_SECS = 3600` in
`services/chat/src/s3.rs`). `list_messages` returns the stored `file_url`
verbatim — there is no presign-on-read — so any image or video older than 1h
fails to load:

- **Images:** `CachedNetworkImage` shows its `errorWidget` (broken-image icon).
- **Videos:** `VideoPlayerController.initialize()` gets a 403 → `_failed = true`
  → broken-image icon (added in BUG-026 / Task 43).

Surfaced by the BUG-026 review (finding **F4**, severity low). The video fix
made this newly visible for video ("tap to play history video that no longer
loads"), but the underlying gap already affects historical **images** today —
so it is **not** specific to BUG-026.

## Current Behavior

- Fresh media (< 1h) loads fine on both sender and receiver.
- The render path already handles the failure gracefully (broken-image icon,
  no crash) — this is a load gap, not a stability bug.
- `ChatService.getAttachmentUrl(attachmentId)` (GET `/chat/attachments/{id}`)
  already returns a *fresh* signed URL but is **not wired into any caller**.

## Proposed Solutions (not yet implemented)

1. **Backend presign-on-read (preferred)** — in `list_messages`, presign the
   attachment key on each read instead of returning the stored `file_url`.
   Mirrors `auth get_profile` / `finalize_avatar_url` for avatars. Fixes images
   **and** videos in one place with **no client change**, and makes the stored
   `file_url` column effectively a cache/fallback.
2. **Client refresh-on-view** — before opening media, call the existing
   `ChatService.getAttachmentUrl(attachmentId)` to fetch a live URL. Requires
   the message payload to carry the attachment `id` (the render path currently
   consumes only `file_url` + `file_mime_type`), so `list_messages` would need
   to include an `id`/`attachment_id` field.

## Priority

Low — graceful degradation already in place (broken-image icon, no crash), and
recent/active conversations (the common case) are unaffected. Should be fixed
before heavy reliance on long-lived chat history media.

## Status

Open — backlog. Out of scope for BUG-026 (Task 43); that commit is a
mobile-only playback + sender-visibility fix. This is a backend
(`list_messages` presign-on-read) change touching all chat media history.
