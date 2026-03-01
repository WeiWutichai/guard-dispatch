# Guard Selection Screen / หน้าเลือกเจ้าหน้าที่

## File
`frontend/mobile/lib/screens/hirer/guard_selection_screen.dart`

## Purpose / วัตถุประสงค์
Shows a list of available guards matching the booking criteria. Each card displays the guard's photo, name, tag (e.g., "Top Rated", "VIP"), ratings, job count, experience, distance, hourly rate, and a "Confirm" button that leads to PaymentScreen.

แสดงรายการเจ้าหน้าที่ที่ว่างตรงกับเงื่อนไขการจอง แต่ละการ์ดแสดงรูป ชื่อ แท็ก คะแนน ประสบการณ์ ระยะห่าง อัตรา และปุ่มยืนยัน

## User Role
Customer (Hirer)

## Navigation
- From: BookingScreen ("Find Guard" button)
- To: PaymentScreen (via "Confirm" button on any guard card)
- To: NotificationScreen (via bell icon)

## UI Elements

### Header (primary color, rounded bottom)
- SecureGuard branding, notification bell, person icon

### Sub-header
- Back button
- "Available Guards (4)" title (count hardcoded)

### Guard Cards (3 mock guards in a ListView)
Each card contains:
- 60×60 network image (rounded 12px, from pravatar.cc)
- Name (bold) + chevron_right icon
- Tag badge (primary color pill): "Top Rated" / "VIP" / "Available"
- Star rating + review count + job count (row)
- Experience + distance (row with clock and location icons)
- Skill tags: "Security" + "Professional" (gray pill badges)
- Hourly rate (฿100/hr or ฿200/hr, bold primary) + "Online 5m ago" caption
- "Confirm Booking" elevated button → PaymentScreen

### Sample Guards
| Name | Tag | Rating | Jobs | Exp | Distance | Rate |
|---|---|---|---|---|---|---|
| สมชาย วิรุฬน | Top Rated | 4.9 (127 reviews) | 234 | 5 years | 1.2 km | ฿100/hr |
| ประยุทธ์ กิจดี | VIP | 4.8 (88 reviews) | 156 | 7 years | 2.1 km | ฿200/hr |
| วิชัย ใจดี | Available | 4.7 (45 reviews) | 67 | 3 years | 3.5 km | ฿100/hr |

## Data / API Calls
- No API calls (3 hardcoded mock guard profiles)
- All 3 "Confirm" buttons navigate to the same PaymentScreen (no guard selection state passed)
- Future: rust-booking-service GET /booking/available-guards?...

## Status
Static UI with functional navigation to PaymentScreen

## Notes
- StatelessWidget — no state
- `BouncingScrollPhysics` for smooth scrolling
- Guard count shows "(4)" in header but only 3 guards in the list (discrepancy in mock data)
- Bilingual inline (isThai ternary, no strings class)
- Photos from pravatar.cc placeholder service
