# Activity Log / Activity Log

## Route
`/activity`

## Purpose / วัตถุประสงค์
Audit and activity logging interface for monitoring system usage, device access, and chat message history. Provides searchable and filterable logs for security auditing and compliance purposes.

หน้าจอบันทึกกิจกรรมและการตรวจสอบสำหรับติดตามการใช้งานระบบ การเข้าถึงอุปกรณ์ และประวัติข้อความแชท รองรับการค้นหาและกรองบันทึกเพื่อการตรวจสอบความปลอดภัยและการปฏิบัติตามข้อกำหนด

## UI Components
- 2 tabs:
  - Device Access Logs: login/logout events, device info, IP addresses, timestamps
  - Chat Message Logs: message history, sender/receiver, conversation ID, timestamps
- Filter panel:
  - Date range picker
  - User filter (search by name or ID)
  - Action type filter
- Search bar for full-text log search
- Log detail view with expanded information
- Export buttons: CSV and PDF

## Data Source
Mock data -- will connect to audit schema across all services

## User Actions
- Switch between Device Access Logs and Chat Message Logs tabs
- Filter logs by date range, user, or action type
- Search logs by keyword
- View detailed log entries
- Export filtered logs as CSV or PDF

## i18n Keys
`t.activity.*`

## Related Backend Service
- **Audit schema** in PostgreSQL -- receives data from all 5 Rust services
- Audit middleware runs on every service (auth, booking, tracking, notification, chat)
- Audit logs include: user_id, action, entity_type (derived from URL path), IP address, timestamp

## Status
Mock Data

## Notes
- Audit middleware validates JWT signature before trusting user_id (no insecure validation)
- entity_type is derived from URL path segment (e.g., `/auth/login` produces "auth")
- IP address extraction: X-Real-IP header first, then X-Forwarded-For rightmost entry
- Audit log persistence is fire-and-forget via `tokio::spawn` to avoid blocking responses
- Future: connect to real audit data from all backend services
- Future: add real-time log streaming via WebSocket
- Future: implement log retention policies and automated archival
