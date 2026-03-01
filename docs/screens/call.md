# Call Screen / หน้าโทร

## File
`frontend/mobile/lib/screens/call_screen.dart`

## Purpose / วัตถุประสงค์
Placeholder voice/video call interface. Displays a large avatar, caller name, and call status text. Provides Mute, Video, and Speaker control buttons along with a red end-call button. MediaSoup integration is not yet implemented.

หน้าจอ placeholder สำหรับโทรด้วยเสียง/วิดีโอ แสดงอวาตาร์ขนาดใหญ่ ชื่อผู้โทร และสถานะการโทร มีปุ่มควบคุม Mute, Video, Speaker และปุ่มวางสายสีแดง ยังไม่ได้เชื่อมต่อ MediaSoup

## User Role
Both (Guard and Customer)

## Navigation
- From: ChatScreen (call icon in app bar) or GuardJobsTab (call client button)
- To: Previous screen (on end call tap via Navigator.pop)

## UI Elements
- Full-screen gradient background (primary color)
- Large CircleAvatar (60px radius) with person icon
- Caller name (28px bold white text)
- "Secure Call..." status text
- 3 control buttons in a row: Mute, Video, Speaker (white semi-transparent circles)
- Red end-call button (circle with call_end icon)

## Data / API Calls
- No API calls (placeholder screen)
- Future: MediaSoup server (Node.js, port 3005) for WebRTC video/audio

## Status
Placeholder (UI only, no call functionality)

## Notes
- StatelessWidget -- no state management
- Takes userName as required constructor parameter
- End-call button pops the navigation stack
- Control buttons have no functional handlers
- No bilingual strings -- labels are hardcoded in English ("Mute", "Video", "Speaker")
