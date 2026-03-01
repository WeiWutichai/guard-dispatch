# Dashboard / แดชบอร์ด

## Route
`/`

## Purpose / วัตถุประสงค์
System overview page displaying key operational metrics, recent booking requests, and status summaries. Serves as the primary landing page after admin login, providing a quick snapshot of current system activity.

หน้าภาพรวมระบบที่แสดงตัวชี้วัดการดำเนินงานหลัก คำขอจองล่าสุด และสรุปสถานะ ทำหน้าที่เป็นหน้าแรกหลังเข้าสู่ระบบ ให้ภาพรวมกิจกรรมปัจจุบันอย่างรวดเร็ว

## UI Components
- 4 stat cards: Active Guards, Live Tasks, Completed Today, Total Requests (gradient backgrounds with icons)
- Recent requests table with columns: ID, customer, type, status, created date
- Status summary section showing request distribution by state
- Stat cards use `bg-gradient-to-br` with `rounded-2xl` and `hover:shadow-md`

## Data Source
- `bookingApi.listRequests()` -- API connected to booking service
- Stats derived from request data aggregation

## User Actions
- View recent booking requests in table format
- Click on a request row to view details
- Monitor real-time counts of guards, tasks, and requests

## i18n Keys
`t.dashboard.*`

## Related Backend Service
- **Booking Service** (port 3002) -- provides request data via `/booking/*` endpoints

## Status
API Connected

## Notes
- Dashboard data refreshes on page load; no automatic polling implemented yet
- Stat card values are computed client-side from the fetched request list
- Future enhancement: add real-time WebSocket updates for live metric changes
- Future enhancement: add chart visualizations for trends over time
