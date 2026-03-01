# PIN Setup Screen / หน้าตั้งรหัส PIN

## File
`frontend/mobile/lib/screens/pin_setup_screen.dart`

## Purpose / วัตถุประสงค์
Guides first-time users through a 3-step PIN creation flow: enter a 6-digit PIN, confirm the PIN, and optionally enable biometric authentication. The PIN is hashed with SHA-256 via PinStorageService before being persisted to FlutterSecureStorage.

หน้าจอสำหรับตั้งรหัส PIN 6 หลักเมื่อเปิดแอปครั้งแรก มี 3 ขั้นตอน: สร้าง PIN, ยืนยัน PIN, และเลือกเปิดใช้ไบโอเมตริก PIN ถูก hash ด้วย SHA-256 ผ่าน PinStorageService ก่อนจัดเก็บใน FlutterSecureStorage

## User Role
Both (Guard and Customer)

## Navigation
- From: App first launch (when no PIN is stored)
- To: PhoneInputScreen (after PIN setup completes)

## UI Elements
- Lock icon (changes to fingerprint icon on biometric step)
- Step header with title and subtitle (animated transition between steps)
- PinDotsIndicator widget (6 dots, fills as digits are entered)
- PinKeypad widget (custom numeric keypad with backspace)
- Error text (animated opacity, shown when confirmation PIN does not match)
- Biometric opt-in step: glassmorphism card with fingerprint icon, Skip button, Enable button
- Background decorative blobs (primary and teal colored circles)

## Data / API Calls
- PinStorageService.savePin() -- stores SHA-256 hashed PIN in FlutterSecureStorage
- PinStorageService.setBiometricEnabled() -- stores biometric preference
- No backend API calls (local-only operation)

## Status
Static UI (PIN stored locally, no backend integration)

## Notes
- Uses `_PinSetupStep` enum with values: create, confirm, biometricOpt
- PIN auto-submits when 6 digits are entered (200ms delay)
- On confirmation mismatch, error displays for 600ms then clears the input
- Bilingual support via PinSetupStrings from l10n/app_strings.dart
- Navigates with pushReplacement to prevent going back to setup
