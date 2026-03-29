# Service Selection Screen / หน้าเลือกบริการ

## File
`frontend/mobile/lib/screens/hirer/service_selection_screen.dart`

## Purpose / วัตถุประสงค์
Landing page for hirers (tab index 0). Shows two service type cards — Security Guard and Bodyguard — each with pricing, min hours, service area, rating, and a "Select" button that leads to the booking flow. Includes platform stats at the bottom.

หน้าแรกสำหรับผู้เรียก แสดงการ์ดบริการ 2 ประเภท: เจ้าหน้าที่รักษาความปลอดภัย และบอดี้การ์ด พร้อมราคา ชั่วโมงขั้นต่ำ และพื้นที่บริการ

## User Role
Customer (Hirer)

## Navigation
- From: HirerDashboardScreen (tab index 0)
- To: BookingScreen (via "Select" button on either service card)
- To: NotificationScreen (via bell icon in header)

## UI Elements

### Header (primary color, rounded bottom)
- Back icon button
- Shield icon + "PGuard" branding
- Greeting text: "Hello! Choose the security service you need"
- Notification bell icon (→ NotificationScreen)
- Person profile icon

### Body Content
- "Select Service" title + subtitle
- **Security Guard Card**:
  - `security_rounded` icon in primary container
  - Min 6 hours, Bangkok & vicinity, Avg Rating 4.8/5 (with clock/location/star icons)
  - Price range: ฿600-1200/day (bold primary)
  - "Select" button → BookingScreen
- **Bodyguard Card**:
  - `person_search_rounded` icon in primary container
  - Min 4 hours, Nationwide, Avg Rating 4.9/5
  - Price range: ฿800-1600/day
  - "Select" button → BookingScreen (same screen regardless of service type)
- Divider
- **Stats section**: 500+ Guards / 24/7 Support / 5K+ Customers (3 columns)

## Data / API Calls
- No API calls (static service info)
- Both "Select" buttons navigate to the same BookingScreen (no service type parameter passed)
- Future: pass service type to BookingScreen to customize booking form

## Status
Static UI with functional navigation to BookingScreen

## Notes
- StatelessWidget — no state
- Service card detail icons chosen by string content matching (hours/location/star detection)
- `BouncingScrollPhysics` for iOS-style scroll
- Stats section uses hardcoded values (500+, 24/7, 5K+)
