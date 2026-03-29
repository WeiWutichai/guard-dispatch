# PIN Lock Screen / หน้าปลดล็อกด้วย PIN

## File
`frontend/mobile/lib/screens/pin_lock_screen.dart`

## Purpose / วัตถุประสงค์
Presents a PIN entry screen on subsequent app launches. Users enter their 6-digit PIN or use biometric unlock (fingerprint/face) to access the app. Validates the entered PIN against the stored SHA-256 hash.

หน้าจอสำหรับกรอก PIN 6 หลักเมื่อเปิดแอปครั้งถัดไป รองรับปลดล็อกด้วยไบโอเมตริก (ลายนิ้วมือ/ใบหน้า) ตรวจสอบ PIN ที่กรอกเทียบกับ SHA-256 hash ที่เก็บไว้

## User Role
Both (Guard and Customer)

## Navigation
- From: App launch (when PIN is already stored)
- To: PhoneInputScreen (on successful validation)

## UI Elements
- PGuard logo and branding (app icon with shadow)
- "Enter your PIN" title and subtitle
- PinDotsIndicator widget (6 dots with error state animation)
- PinKeypad widget (numeric keypad, optional biometric button)
- Error text with animated opacity on wrong PIN
- Biometric success snackbar (green check icon)
- "PGUARD MOBILE" footer text
- Background decorative blobs

## Data / API Calls
- PinStorageService.validatePin() -- compares SHA-256 hash of input against stored hash
- PinStorageService.isBiometricEnabled -- checks if biometric unlock is available
- No backend API calls (local-only operation)

## Status
Static UI (biometric success is simulated for prototype)

## Notes
- PIN auto-validates when 6 digits are entered (200ms delay)
- On incorrect PIN, error shows for 600ms then clears input
- Biometric tap simulates success with snackbar, then navigates after 900ms
- Uses pushReplacement navigation to prevent back navigation to lock screen
- PinLockStrings provides bilingual text from l10n/app_strings.dart
