# Applicants / ผู้สมัคร

## Route
`/applicants`

## Purpose / วัตถุประสงค์
Review and manage guard and customer applicants through a tabbed interface. Admins can approve or reject applications, with approved guards moving to the Guards page and approved customers moving to the Customers page.

ตรวจสอบและจัดการผู้สมัครเจ้าหน้าที่ รปภ. และผู้เรียกใช้บริการผ่านระบบแท็บ ผู้ดูแลสามารถอนุมัติหรือปฏิเสธใบสมัคร โดยเจ้าหน้าที่ที่อนุมัติจะย้ายไปหน้าพนักงานรักษาความปลอดภัย และลูกค้าที่อนุมัติจะย้ายไปหน้าลูกค้า

## UI Components
- 3 tabs: All / Guard Applicants (เจ้าหน้าที่ รปภ.) / Customer Applicants (ผู้เรียก รปภ.)
- Dynamic table columns change per active tab:
  - "All" tab: shows Type column + experience + salary
  - "Guard" tab: shows experience + salary (no Type column)
  - "Customer" tab: shows companyName + bookingPurpose
- Stats cards scoped to active tab (counts only applicants of selected type)
- Review modal with different content per applicant type:
  - Guard modal: documents, certificates, work history
  - Customer modal: company info, booking purpose
- Status badges: pending (amber), approved (emerald), rejected (red)
- Type badges: guard (amber), customer (blue)

## Data Source
Mock data -- not yet connected to backend API

## Types
Discriminated union pattern:
- `GuardApplicant` (type: "guard") -- includes experience, salary, documents, certificates
- `CustomerApplicant` (type: "customer") -- includes companyName, bookingPurpose

## User Actions
- Switch between All / Guard / Customer tabs
- Filter applicants by status (pending/approved/rejected)
- Search applicants by name or details
- Open review modal to inspect applicant details
- Approve applicant (moves to respective Guards or Customers page)
- Reject applicant with notes/reason
- View approved note indicating destination menu

## i18n Keys
`t.applicants.*` -- includes `t.applicants.tabs.guard`, `t.applicants.tabs.customer`, `t.applicants.modal.*`

## Related Backend Service
- **Auth Service** (port 3001) -- needs user approval endpoint implementation

## Status
Mock Data

## Notes
- The `/members` route was removed; all member management is consolidated into this page using tabs
- When status is "approved", the UI displays a note indicating which menu the user has been moved to
- Guard applicants show different modal content than customer applicants (discriminated union drives UI rendering)
- Stats cards recalculate when switching tabs to show only relevant counts
- Future: connect to auth service user management endpoints for approval workflow
