# Application Status Screen / หน้าสถานะการสมัคร

## File
`frontend/mobile/lib/screens/guard/application_status_screen.dart`

## Purpose / วัตถุประสงค์
Displays the current review status of a guard's job application. Shows a color-coded status banner (pending/approved/rejected), submission timestamp, and three detail cards: personal info, uploaded documents, and bank account summary.

แสดงสถานะการตรวจสอบใบสมัครของเจ้าหน้าที่ แสดงแบนเนอร์สถานะ (รอตรวจสอบ/อนุมัติ/ปฏิเสธ) เวลาที่ส่ง และ 3 การ์ดรายละเอียด

## User Role
Guard

## Navigation
- From: GuardProfileTab (Application Status menu)
- To: No outbound navigation

## UI Elements

### AppBar (deepBlue)
- Back button, "Application Status" title

### Status Header (deepBlue bg, rounded bottom)
Status-dependent icon and color:
- **Pending** (warning/amber): hourglass icon + "Under Review" + "Documents are being verified" desc
- **Approved** (success/green): check_circle icon + "Approved" + "You can now work" desc
- **Rejected** (danger/red): cancel icon + "Rejected" + "Please contact support" desc

Submission timestamp row: clock icon + "Submitted on DD Month YYYY HH:MM"

### Personal Info Card
- person_outline icon, "Personal Information" title
- Rows: Full Name, Gender, Date of Birth, Experience (X years), Previous Workplace

### Documents Card
- folder_outlined icon, "Documents" title
- 6 items: ID Card, Security License, Training Cert, Criminal Check, Driver's License, Passbook Photo
- Each item: check_circle (success) or cancel (danger) icon + doc name + "Uploaded" / "Not Uploaded" label

### Bank Account Card
- account_balance_outlined icon, "Bank Account" title
- Rows: Bank Name, Account Number (masked: ***-*-*4567), Account Name

## Data / API Calls
- No API calls (sample data hardcoded in the widget)
- `status = 'pending'` hardcoded — future: read from rust-auth-service registration status endpoint

## Status
Static UI (hardcoded sample data, status always shows "pending")

## Notes
- StatelessWidget — no state
- `AppStatusStrings(isThai: isThai)` provides bilingual text
- `_buildCard()` helper used for all 3 detail cards (consistent styling)
- `_buildInfoRow()` helper: 140px width label column + expanded value column
- Documents all show as uploaded (mock — 6/6 with green check icons)
