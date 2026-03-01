# Work History Screen / หน้าประวัติการทำงาน

## File
`frontend/mobile/lib/screens/guard/work_history_screen.dart`

## Purpose / วัตถุประสงค์
Shows the guard's complete job history with filter tabs. Displays lifetime stats (total jobs, total hours, average rating) and a filterable list of job cards. All data is mock.

แสดงประวัติงานทั้งหมดของเจ้าหน้าที่พร้อมแท็บกรอง แสดงสถิติตลอดชีพ (งานทั้งหมด ชั่วโมงทั้งหมด คะแนนเฉลี่ย) และรายการงานที่กรองได้

## User Role
Guard

## Navigation
- From: GuardProfileTab (Work History menu)
- To: No outbound navigation

## UI Elements

### AppBar (deepBlue)
- Back button, "Work History" title

### Filter Tabs (custom pill row on deepBlue background)
- 4 options: All / Ongoing / Completed / Cancelled
- Active: white fill, deepBlue text (bold)
- Inactive: transparent, white70 text

### Summary Cards (3 equal columns)
- Total Jobs: 156 (work icon, AppColors.info)
- Total Hours: 624 (clock icon, AppColors.primary)
- Average Rating: 4.8 (star icon, amber)

### Job History List
- Section header "Job History"
- Filtered job cards (only `type == _selectedTabIndex` shown, or all for index 0)
- Each card:
  - Client avatar (person icon, AppColors.info tint)
  - Client name + location with pin icon
  - Status badge ("Completed", green)
  - Date, duration, star rating (row)
  - Earnings amount (bold, primary color)
- Empty state: work_history icon + "No jobs found" text (shown when filtered list is empty)

### Sample Data (4 completed jobs)
- All type=2 (Completed) — Ongoing/Cancelled tabs show empty state

## State
- `_selectedTabIndex` (0-3) — controls filter

## Data / API Calls
- No API calls (mock `_JobData` objects hardcoded)
- Future: rust-booking-service GET /booking/assignments?guard_id=&status=

## Status
Static UI (mock data, filter tabs functional for UI switching)

## Notes
- StatefulWidget with tab switching via `setState`
- `WorkHistoryStrings(isThai: isThai)` provides bilingual text and all sample data strings
- `_JobData` private class: client, location, date, duration, earning, rating, statusLabel, type
- All 4 sample jobs are type=2 (Completed), so Ongoing/Cancelled always show empty state
