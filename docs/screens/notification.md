# Notification Screen / หน้าการแจ้งเตือน

## File
`frontend/mobile/lib/screens/notification_screen.dart`

## Purpose / วัตถุประสงค์
Displays role-specific notifications in a list. Guard notifications include new job assignments, payment confirmations, and customer reviews. Customer (hirer) notifications include booking confirmations, new messages, and payment due reminders. Unread items are highlighted with a blue dot indicator.

แสดงรายการแจ้งเตือนตามบทบาท เจ้าหน้าที่: งานใหม่/การชำระเงิน/รีวิว ผู้เรียก: ยืนยันการจอง/ข้อความใหม่/ค้างชำระ รายการที่ยังไม่อ่านมีจุดสีน้ำเงินกำกับ

## User Role
Both (Guard and Customer -- content changes based on isGuard parameter)

## Navigation
- From: GuardHomeTab (notification icon), ServiceSelectionScreen, BookingScreen, or HirerProfileScreen
- To: No outbound navigation (list display only)

## UI Elements
- AppBar with back button and centered "Notifications" title
- Notification list items with:
  - Colored circular icon (work, payment, star, check, chat, wallet)
  - Title (bold if unread) and timestamp on same row
  - Message description text below title
  - Blue dot indicator for unread items (8px circle)
  - Tinted background for unread items

## Data / API Calls
- No API calls (mock notification data)
- Future: rust-notification-service + FCM push notifications

## Status
Static UI (hardcoded mock notifications)

## Notes
- Takes `isGuard` boolean parameter (default: false) to determine notification content
- Guard notifications: 3 items (new job=primary, payment=success, review=warning colors)
- Hirer notifications: 3 items (booking=success, message=info, payment=primary colors)
- NotificationStrings provides bilingual text from l10n/app_strings.dart
- StatelessWidget with no state management
