# Tasks / จัดการงาน

## Route
`/tasks`

## Purpose / วัตถุประสงค์
Manage guard booking request tasks throughout their lifecycle. View, filter, and update task statuses, assign guards to requests, and handle cancellations. Primary operational interface for dispatching guards.

จัดการงานคำขอจองเจ้าหน้าที่ รปภ. ตลอดวงจรงาน ดู กรอง และอัปเดตสถานะงาน มอบหมายเจ้าหน้าที่ให้คำขอ และจัดการการยกเลิก เป็นหน้าจอหลักสำหรับการจัดส่งเจ้าหน้าที่

## UI Components
- 4 stat cards: Total Tasks, Pending, In Progress, Completed (gradient backgrounds)
- Task cards displaying: request ID, customer info, location, status badge, urgency badge
- Status filter tabs or dropdown (All/Pending/Assigned/In Progress/Completed/Cancelled)
- Urgency filter (Normal/Urgent/Emergency)
- Search bar for finding tasks by ID or customer name
- Task detail view with assignment controls

## Data Source
- `bookingApi.listRequests()` -- API connected to booking service
- Task data fetched from `/booking/requests` endpoints

## User Actions
- Filter tasks by status (pending/assigned/in progress/completed/cancelled)
- Filter tasks by urgency level
- Search tasks by ID or customer name
- View task details
- Assign a guard to a pending task
- Update task status
- Cancel a task with reason

## i18n Keys
`t.tasks.*`

## Related Backend Service
- **Booking Service** (port 3002) -- request management via `/booking/*` endpoints

## Status
API Connected

## Notes
- Task status transitions follow a defined workflow: Pending -> Assigned -> In Progress -> Completed
- Guard assignment requires checking guard availability and proximity (future feature)
- Cancellation requires a reason and triggers notification to assigned guard
- Performance target: API responses under 200ms
- Database uses composite index on `(status, created_at DESC)` for efficient list queries
- Authorization: users can only access tasks they own, are assigned to, or if they are admin
