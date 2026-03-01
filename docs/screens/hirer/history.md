# Hirer History Screen / หน้าประวัติการจองผู้เรียก

## File
`frontend/mobile/lib/screens/hirer/hirer_history_screen.dart`

## Purpose / วัตถุประสงค์
Shows the hirer's booking history with filter tabs. Each booking card shows the guard's avatar, name, service type, status badge, date, time range, and total paid. Filterable by All / Ongoing / Completed / Cancelled.

แสดงประวัติการจองของผู้เรียกพร้อมแท็บกรอง แต่ละรายการแสดงอวาตาร์เจ้าหน้าที่ ชื่อ ประเภทบริการ สถานะ วันที่ เวลา และยอดชำระ

## User Role
Customer (Hirer)

## Navigation
- From: HirerDashboardScreen (tab index 2)
- To: No outbound navigation

## UI Elements

### AppBar (white, centered title)
- "Booking History" / "ประวัติการจอง" title

### Filter Tabs (custom pill row, light gray background)
- 4 options: All / Ongoing / Completed / Cancelled
- Active: white fill, shadow, bold dark text
- Inactive: transparent, gray text

### Booking Cards (filtered list)
Each card:
- CircleAvatar (24px radius, network image)
- Guard name (bold) + service type (gray)
- Status badge (colored pill: green=Completed, red=Cancelled)
- Divider
- Date row: calendar icon + date
- Time row: clock icon + time range
- Total amount (bold primary, right-aligned)

### Sample Data (3 bookings)
| Guard | Service | Date | Time | Amount | Status |
|---|---|---|---|---|---|
| สมชาย วีรชน | Security Guard | 15 ก.พ. 2568 | 14:00-20:00 | ฿1,200 | Completed |
| วิชัย นามสมมุติ | Bodyguard | 10 ก.พ. 2568 | 18:00-00:00 | ฿3,200 | Completed |
| มานี มีทรัพย์ | Security Guard | 05 ก.พ. 2568 | 08:00-16:00 | ฿1,600 | Cancelled |

### Empty State
- `history_rounded` icon (gray, 64px)
- "No history found" / "ไม่มีรายการ" text
- Shown when filter has no matching items

## State
- `_selectedTabIndex` (0-3) — controls filter

## Data / API Calls
- No API calls (`_HistoryData` objects hardcoded)
- Future: rust-booking-service GET /booking/requests?customer_id=&status=

## Status
Static UI (mock data, filter switching functional)

## Notes
- StatefulWidget with `_selectedTabIndex` filter
- `_HistoryData` private class: name, service, date, time, price, status, statusColor, avatar, type (1=ongoing, 2=completed, 3=cancelled)
- Ongoing tab always shows empty state (no type=1 mock items)
- `HirerHistoryStrings(isThai: isThai)` for label text
