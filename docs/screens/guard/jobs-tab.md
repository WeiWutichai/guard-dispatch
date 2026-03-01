# Guard Jobs Tab / แท็บงานเจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/tabs/guard_jobs_tab.dart`

## Purpose / วัตถุประสงค์
Displays active and completed guard assignments. The "Current" tab shows a detailed job card for the ongoing job with client info, reward, check-in functionality, and action buttons. The "Completed" tab shows a list of past jobs.

แสดงงานปัจจุบันและงานที่เสร็จแล้ว แท็บ "ปัจจุบัน" แสดงการ์ดงานโดยละเอียดพร้อมข้อมูลลูกค้า รางวัล และปุ่มเช็คอิน แท็บ "เสร็จสิ้น" แสดงรายการงานที่ผ่านมา

## User Role
Guard

## Navigation
- From: GuardDashboardScreen (tab index 1)
- To: CallScreen (via "Call Client" button)
- To: ChatScreen (via "Chat" button, passes client name and role)

## UI Elements

### AppBar
- Back button, "My Jobs" title
- TabBar with 2 tabs: Current (ปัจจุบัน) / Completed (เสร็จสิ้น)

### Current Jobs Tab
Job card containing:
- Status badge (green dot + "Working" label)
- Time range (e.g., 14:00 - 18:00)
- Client name (large bold)
- Location with pin icon
- Reward badge (primary color, e.g., ฿800)
- Bonus badge (warning color, e.g., ฿100 bonus)
- Job description text
- Additional details section (pet care, plants, utilities)
- Security equipment info
- **Check-In Card**: location_searching icon + info text + "Check In" button
- Action buttons row: "Call Client" (navigates to CallScreen) + "Chat" (navigates to ChatScreen)

### Completed Jobs Tab
- Flat list of completed job items
- Each item: client name, date, amount — row layout

## Data / API Calls
- No API calls (mock data hardcoded)
- Future: rust-booking-service GET /booking/assignments?guard_id=&status=active

## Status
Static UI (hardcoded mock job data)

## Notes
- StatefulWidget (DefaultTabController manages tab state)
- `GuardJobsStrings(isThai: isThai)` provides bilingual text
- Check-in button has no handler yet (future: GPS-based check-in via WebSocket)
- Completed jobs use hardcoded Thai names for sample data
