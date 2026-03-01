# Phone Input Screen / หน้ากรอกเบอร์โทรศัพท์

## File
`frontend/mobile/lib/screens/phone_input_screen.dart`

## Purpose / วัตถุประสงค์
Collects the user's Thai mobile phone number for OTP-based authentication. Validates that the number is exactly 10 digits (Thai format starting with 0). Displays the country code +66 prefix and role badge if the user has selected a role.

หน้าจอสำหรับกรอกเบอร์โทรศัพท์มือถือไทย 10 หลัก พร้อมรหัสประเทศ +66 เพื่อรับ OTP รองรับการแสดง badge ของบทบาท (เจ้าหน้าที่/ผู้เรียก) หากผู้ใช้เลือกไว้แล้ว

## User Role
Both (Guard and Customer)

## Navigation
- From: PinSetupScreen, PinLockScreen, or RoleSelectionScreen (with role parameter)
- To: OtpVerificationScreen (passing phone number and role)

## UI Elements
- Back button (rounded container with arrow icon)
- Role badge pill (shown if role is set -- guard=teal, customer=primary color)
- Title and subtitle text
- Glassmorphism phone input card with BackdropFilter blur
- Country code display (Thai flag + "+66")
- Phone number TextField (digits only, maxLength 10, letterSpacing 1.5)
- Info text: "We will send a 6-digit OTP to this number"
- Submit button ("Request OTP") with animated color change when valid
- Background decorative blobs (role-colored)

## Data / API Calls
- No direct API calls on this screen
- Passes phone number to OtpVerificationScreen

## Status
Static UI (input validation only, no backend call)

## Notes
- Phone input uses FilteringTextInputFormatter.digitsOnly
- Button color changes from gray (disabled) to role color (enabled) when 10 digits entered
- Auto-focuses the phone input field after 300ms delay
- Accepts optional `role` and `destination` parameters for flexible navigation flow
- PhoneInputStrings provides bilingual text
