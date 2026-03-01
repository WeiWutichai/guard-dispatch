# OTP Verification Screen / หน้ายืนยัน OTP

## File
`frontend/mobile/lib/screens/otp_verification_screen.dart`

## Purpose / วัตถุประสงค์
Handles 6-digit OTP input with individual text fields that auto-focus on entry. Verifies the OTP through AuthService.verifyOtp(). Includes a 30-second countdown resend timer. Currently operates as a stub that accepts any 6-digit code.

หน้าจอสำหรับกรอก OTP 6 หลัก มีช่องกรอกแยกแต่ละตัวพร้อม auto-focus ตรวจสอบ OTP ผ่าน AuthService.verifyOtp() มีตัวนับถอยหลัง 30 วินาทีสำหรับส่งซ้ำ ปัจจุบันเป็น stub รับรหัส 6 หลักใดก็ได้

## User Role
Both (Guard and Customer)

## Navigation
- From: PhoneInputScreen
- To: RoleSelectionScreen (default) or custom destination widget

## UI Elements
- Back button
- SMS icon in role-colored container
- Title "Verify OTP" and masked phone display (e.g., 089-XXX-4567)
- 6 individual OTP input fields with auto-advance focus
- Error message (animated opacity) for incorrect OTP
- CircularProgressIndicator during verification
- Resend timer text (countdown from 30s) / Resend OTP button
- Prototype hint card (glassmorphism) explaining stub behavior
- Background decorative blobs

## Data / API Calls
- AuthService.verifyOtp(phone, otp) -- verifies OTP code (currently stub: always returns true)
- AuthService.markRegistered(role, phone) -- marks user as registered for the given role

## Status
Stub (accepts any 6-digit OTP code, no real SMS verification)

## Notes
- Uses KeyboardListener to handle backspace navigation between fields
- On successful verification, navigates with pushAndRemoveUntil to clear phone/OTP screens from stack
- Success snackbar shown for 1200ms before navigation
- On error, clears all fields after 800ms and refocuses first field
- Timer uses Timer.periodic with 1-second interval
- PhoneInputStrings and OtpStrings provide bilingual text
