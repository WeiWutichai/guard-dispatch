# Guard Login Screen / หน้าเข้าสู่ระบบเจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard_login_screen.dart`

## Purpose / วัตถุประสงค์
Legacy email/password login screen for security guards. Provides guard ID and password input fields with validation and loading state. Calls AuthService.loginGuard() for authentication. This screen may be replaced by the phone+OTP flow in the future.

หน้าเข้าสู่ระบบสำหรับเจ้าหน้าที่ รปภ. แบบเดิม (ID + รหัสผ่าน) มีช่องกรอก Guard ID และรหัสผ่านพร้อมการตรวจสอบ เรียก AuthService.loginGuard() เพื่อยืนยันตัวตน อาจถูกแทนที่ด้วยระบบ OTP ในอนาคต

## User Role
Guard

## Navigation
- From: RoleSelectionScreen (if using legacy login flow)
- To: GuardDashboardScreen (on successful login)

## UI Elements
- AppBar with back button and centered title
- Guard badge icon (teal color, rounded container)
- "Guard" title and "Security Guard" subtitle
- Login form card (surface color, rounded):
  - Guard ID TextField with person icon prefix
  - Password TextField with lock icon prefix, visibility toggle suffix
  - Error message text (red, shown on validation failure)
  - Login button (primary color, full width, loading spinner when submitting)

## Data / API Calls
- AuthService.loginGuard(guardId, password) -- authenticates guard credentials
- Future: rust-auth-service /auth/login endpoint

## Status
Stub (AuthService.loginGuard is a mock implementation)

## Notes
- StatefulWidget with loading state and error message management
- Password field supports visibility toggle via eye icon
- Validates that both fields are non-empty before submission
- Error messages: fields required, invalid credentials, login error
- Password submit action triggers login (onSubmitted handler)
- GuardLoginStrings provides bilingual text
