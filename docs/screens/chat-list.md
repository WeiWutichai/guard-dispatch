# Chat List Screen / หน้ารายการแชท

## File
`frontend/mobile/lib/screens/chat_list_screen.dart`

## Purpose / วัตถุประสงค์
Displays a list of active chat conversations. Each conversation shows the contact's avatar with an online/offline status indicator, the last message preview, and a timestamp. Tapping a conversation navigates to the full chat screen.

แสดงรายการการสนทนาที่ใช้งานอยู่ แต่ละรายการแสดงรูปอวาตาร์พร้อมสถานะออนไลน์/ออฟไลน์ ข้อความล่าสุด และเวลา แตะเพื่อเข้าสู่หน้าแชทเต็มรูปแบบ

## User Role
Both (Guard and Customer -- used as a tab in both dashboards)

## Navigation
- From: GuardDashboardScreen (Chat tab) or HirerDashboardScreen (Messages tab)
- To: ChatScreen (on conversation tap, passing userName and userRole)

## UI Elements
- Header bar (primary color, rounded bottom, P-Guard branding)
- Notification icon and profile icon in header
- Section title with subtitle
- Chat list items with:
  - CircleAvatar (28px radius) with network image
  - Online indicator dot (green=online, gray=offline) positioned bottom-right
  - Contact name (bold) and timestamp on same row
  - Last message preview (single line, ellipsis overflow)
  - Online/Offline status pill badge
- Divider between items

## Data / API Calls
- No API calls (mock data with 2 sample conversations)
- Future: rust-chat-service WebSocket for real-time message list

## Status
Static UI (hardcoded mock conversations)

## Notes
- StatelessWidget with mock data
- Chat items use InkWell for tap feedback
- Avatars loaded from pravatar.cc placeholder service
- Bilingual text via ChatStrings from l10n/app_strings.dart
- Reused in both Guard and Hirer dashboards as a shared screen
