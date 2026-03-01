# Chat Screen / หน้าแชท

## File
`frontend/mobile/lib/screens/chat_screen.dart`

## Purpose / วัตถุประสงค์
One-on-one messaging interface between a customer and a security guard. Displays text message bubbles (blue for own, gray for other), system event cards (check-in notifications), and hourly report cards with photos. Includes a message input bar with attachment button.

หน้าจอแชทระหว่างลูกค้าและเจ้าหน้าที่ รปภ. แสดงฟองข้อความ (สีน้ำเงิน=ของตัวเอง, สีเทา=อีกฝ่าย) การ์ดแจ้งเตือนระบบ (การเช็คอิน) และรายงานรายชั่วโมงพร้อมรูปภาพ มีแถบพิมพ์ข้อความพร้อมปุ่มแนบไฟล์

## User Role
Both (Guard and Customer)

## Navigation
- From: ChatListScreen (on conversation tap)
- To: CallScreen (via phone icon in app bar)

## UI Elements
- AppBar with contact avatar, name, online status, call and menu icons
- Message bubbles: own messages (primary blue, right-aligned), other messages (gray, left-aligned)
- System event card (green border, check-in icon, location details, GPS timestamp)
- Hourly report card (report number, time, location, photo image, status text)
- Message input bar:
  - Attachment icon button (attach_file)
  - Text input field with border
  - Send button (green circle with send icon)
- Background color: light gray (#F8F9FA)

## Data / API Calls
- No API calls (mock messages displayed in ListView)
- Future: rust-chat-service WebSocket for real-time messaging
- Future: MinIO/R2 signed URLs for attachment uploads

## Status
Static UI (hardcoded mock messages, system events, and reports)

## Notes
- StatefulWidget with TextEditingController for message input
- Message bubbles have asymmetric border radius (flat corner on sender side)
- Report cards include network images from Unsplash
- ChatStrings provides bilingual text
- Send button and attachment button have no functional handlers yet
