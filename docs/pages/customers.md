# Customers / ลูกค้า

## Route
`/customers`

## Purpose / วัตถุประสงค์
Manage approved customers who have been verified through the applicant review process. View customer profiles, booking history, complaints, and handle account status changes.

จัดการลูกค้าที่ผ่านการตรวจสอบและอนุมัติแล้ว ดูโปรไฟล์ลูกค้า ประวัติการจอง ข้อร้องเรียน และจัดการสถานะบัญชี

## UI Components
- 3 stat cards: Total Customers, Active, Inactive (gradient backgrounds)
- Customer table with columns: name, company, phone, status, total bookings, last booking date
- 4-tab profile modal:
  - Personal: contact info, company details
  - Booking History: past and current bookings
  - Complaints: filed complaints and resolutions
  - Account: account status, creation date, actions
- Status badges and action buttons

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Filter customers by status (active/inactive/suspended)
- Search customers by name or company
- View detailed customer profile via 4-tab modal
- Activate, deactivate, or suspend customer accounts
- Review booking history within profile modal
- View and manage customer complaints

## i18n Keys
`t.customers.*`

## Related Backend Service
- **Auth Service** (port 3001) -- customer account management
- **Booking Service** (port 3002) -- booking history data

## Status
Mock Data

## Notes
- Customers appear here only after being approved on the Applicants page
- The profile modal uses a tabbed layout to organize different aspects of customer data
- Account actions (activate/deactivate/suspend) are distinct from applicant approval status
- Future: connect to booking service for real booking history data
- Future: integrate complaint management with a dedicated support workflow
