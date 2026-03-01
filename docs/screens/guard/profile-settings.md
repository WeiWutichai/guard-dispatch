# Guard Profile Settings Screen / หน้าตั้งค่าโปรไฟล์เจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/profile_settings_screen.dart`

## Purpose / วัตถุประสงค์
Editable profile settings screen for guards. Allows updating personal info (name, phone, email, address), emergency contact details, and notification preferences. Profile photo change is a UI placeholder.

หน้าตั้งค่าโปรไฟล์ที่แก้ไขได้สำหรับเจ้าหน้าที่ รองรับการอัปเดตข้อมูลส่วนตัว ผู้ติดต่อฉุกเฉิน และการตั้งค่าการแจ้งเตือน

## User Role
Guard

## Navigation
- From: GuardProfileTab (Settings menu) or GuardProfileTab (profile card tap)
- To: Returns to caller on save (Navigator.pop)

## UI Elements

### AppBar (deepBlue)
- Back button, "Profile Settings" title

### Profile Photo Section
- 96px circular avatar with primary border and person icon
- Camera icon overlay (bottom-right)
- "Change Photo" TextButton (no handler — UI placeholder)

### Personal Info Section
- Icon: `person_outline_rounded` (primary)
- Full Name TextField (pre-filled: 'สมชาย รักษาดี')
- Phone TextField (pre-filled: '089-123-4567', phone keyboard)
- Email TextField (email keyboard, hint)
- Address TextField (multi-line, 2 lines)

### Emergency Contact Section
- Icon: `emergency_outlined` (primary)
- Contact Name TextField
- Contact Phone TextField
- Relationship TextField

### Notifications Section
- Icon: `notifications_outlined` (primary)
- 3 toggle rows with adaptive Switch:
  - Push Notifications (default: on)
  - SMS Notifications (default: off)
  - Job Alerts (default: on)

### Save Button
- Full-width primary elevated button → `Navigator.pop(context)`

## State
- 7 `TextEditingController` instances for form fields
- 3 boolean toggles: `_pushNotif`, `_smsNotif`, `_jobAlerts`

## Data / API Calls
- No API calls (Save button just pops — no backend submission yet)
- Future: PATCH rust-auth-service /auth/profile

## Status
Static UI (form fields display mock data; save does not persist)

## Notes
- StatefulWidget; all controllers disposed in `dispose()`
- Each section uses `_buildSection()` helper with icon, title, and children
- `ProfileSettingsStrings(isThai: isThai)` provides bilingual text
- Toggle rows use `Switch.adaptive` (native iOS toggle on iOS, Material on Android)
