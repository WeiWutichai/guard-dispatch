# Guards / พนักงานรักษาความปลอดภัย

## Route
`/guards`

## Purpose / วัตถุประสงค์
Manage approved security guards who have passed the applicant review process. View guard profiles, monitor duty status, and handle activation or deactivation of guard accounts.

จัดการเจ้าหน้าที่รักษาความปลอดภัยที่ผ่านการอนุมัติแล้ว ดูโปรไฟล์เจ้าหน้าที่ ติดตามสถานะการปฏิบัติงาน และจัดการการเปิด/ปิดใช้งานบัญชี

## UI Components
- 4 stat cards: Total Guards, On Duty, Off Duty, On Leave (gradient backgrounds)
- Guard table with columns: name, phone, status, rating, area, last active
- Profile modal with document viewer and certificate display
- Status filter dropdown (All/On Duty/Off Duty/On Leave)
- Search bar for filtering by name or ID
- Add guard button

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Filter guards by duty status
- Search guards by name
- View detailed guard profile in modal (documents, certificates, work history)
- Add a new guard manually
- Activate or deactivate guard accounts
- View guard assignment history

## i18n Keys
`t.guards.*`

## Related Backend Service
- **Auth Service** (port 3001) -- user/guard account management
- **Booking Service** (port 3002) -- guard assignment data

## Status
Mock Data

## Notes
- Guards appear here only after being approved on the Applicants page
- Guard profiles include uploaded documents and certificates from the application process
- Status changes (on duty / off duty / on leave) will be driven by the tracking service in production
- Future: integrate with real-time GPS tracking data to show live duty status
