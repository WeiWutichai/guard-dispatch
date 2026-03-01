# Guard Registration Screen / หน้าสมัครเจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/guard_registration_screen.dart`

## Purpose / วัตถุประสงค์
3-step form wizard for guards to apply to join the platform. Collects personal information, document uploads, and bank account details. On submission, saves registration flag locally and shows a confirmation screen.

ฟอร์มนำทาง 3 ขั้นตอนสำหรับเจ้าหน้าที่สมัครเข้าร่วมแพลตฟอร์ม รวบรวมข้อมูลส่วนตัว เอกสาร และบัญชีธนาคาร เมื่อส่งแล้วบันทึกสถานะลงทะเบียนในเครื่องและแสดงหน้ายืนยัน

## User Role
Guard

## Navigation
- From: GuardHomeTab ("Register Now" button) or GuardProfileTab (Register as Guard menu)
- To: Returns to caller screen on back/completion (Navigator.pop)

## UI Elements

### AppBar (deepBlue)
- Back/previous step icon
- "Guard Registration" title

### Step Indicator
- 3-circle row on deepBlue background (rounded bottom)
- Completed steps: check icon, primary color fill
- Active step: primary color fill, white number
- Inactive steps: semi-transparent white, gray number
- Step labels: Personal / Documents / Bank

### Step 1: Personal Info
- Full name TextField
- Gender Dropdown (Male/Female/Other)
- Date of Birth date picker (tap to open calendar)
- Years of experience TextField (numeric)
- Previous workplace TextField

### Step 2: Document Uploads
- 5 document items with upload/remove toggle:
  - ID Card (บัตรประชาชน)
  - Security Guard License (ใบอนุญาต รปภ.)
  - Training Certificate (ใบรับรองการฝึกอบรม)
  - Criminal Background Check (ใบตรวจประวัติอาชญากรรม)
  - Driver's License (ใบขับขี่)
- Each item: status icon (check=uploaded, description_outlined=not), filename or "Not Attached", Upload/Remove button
- Upload is simulated — toggles `_documents[key]` boolean

### Step 3: Bank Account
- Bank name Dropdown (list of Thai banks)
- Account number TextField (digits only, max 15, `FilteringTextInputFormatter.digitsOnly`, no autocorrect)
- Account name TextField
- Passbook photo upload item

### Bottom Buttons
- Previous step: outlined button (shown from step 2+)
- Next step / Submit: filled primary button

### Submitted Screen (Step 4)
- Hourglass icon (AppColors.info)
- "Under Review" heading
- Submission timestamp
- Summary card: name, experience, documents count, bank

## State
- `_currentStep` (0-2)
- `_submitted` (bool)
- `_submittedAt` (DateTime?)
- Form controllers: `_nameController`, `_yearsExpController`, `_workplaceController`, `_accountNumberController`, `_accountNameController`
- `_selectedGender`, `_selectedDateOfBirth`, `_selectedBank`
- `_documents` `Map<String, bool>` — track uploaded state per doc

## Data / API Calls
- `AuthService.markRegistered('guard', name)` — writes registration flag to `SharedPreferences`
- Future: POST to rust-booking-service or rust-auth-service to submit guard application

## Status
Partially functional (local state saves; no backend submission)

## Notes
- StatefulWidget; `dispose()` cleans all controllers
- Bank account field uses `FilteringTextInputFormatter.digitsOnly` + `maxLength: 15` + `enableSuggestions: false` per CLAUDE.md security rules
- Date formatter supports both Thai Buddhist Era (+543 years) and Gregorian
- `_simulateUpload()` toggles document state without actual file picker
