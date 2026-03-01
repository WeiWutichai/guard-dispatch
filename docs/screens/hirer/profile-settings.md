# Hirer Profile Settings Screen / หน้าตั้งค่าโปรไฟล์ผู้เรียก

## File
`frontend/mobile/lib/screens/hirer/hirer_profile_settings_screen.dart`

## Purpose / วัตถุประสงค์
Editable profile settings for hirers. Allows updating personal info (name, phone, email, company, address) and notification preferences. Similar layout to the guard version but includes a Company field instead of Emergency Contact.

หน้าตั้งค่าโปรไฟล์ที่แก้ไขได้สำหรับผู้เรียก รองรับการอัปเดตข้อมูลส่วนตัว ชื่อบริษัท และการตั้งค่าการแจ้งเตือน

## User Role
Customer (Hirer)

## Navigation
- From: HirerProfileScreen (Edit Profile menu or profile card tap)
- To: Returns to caller on save (Navigator.pop)

## UI Elements

### AppBar (primary color)
- Back button, "Profile Settings" title

### Profile Photo Section
- 96px circular avatar with network image (pravatar.cc) + error fallback
- Camera icon overlay (bottom-right) — no handler
- "Change Photo" TextButton — no handler

### Personal Info Section
- Icon: `person_outline_rounded` (primary)
- Full Name (pre-filled: 'มานะ มีบุญ')
- Phone (pre-filled: '081-234-5678', phone keyboard)
- Email (email keyboard, hint)
- Company (text field with hint)
- Address (multi-line, 2 lines, hint)

### Notifications Section
- Icon: `notifications_outlined` (primary)
- 3 toggle rows with adaptive Switch:
  - Push Notifications (default: on)
  - SMS Notifications (default: off)
  - Booking Alerts (default: on) — replaces "Job Alerts" from guard version

### Save Button
- Full-width primary elevated button → `Navigator.pop(context)`

## Differences from Guard Profile Settings
- AppBar: primary color (vs deepBlue)
- No Emergency Contact section
- Has Company field instead
- Third notification toggle: "Booking Alerts" (not "Job Alerts")
- Avatar shows actual network image (not placeholder icon)

## State
- 5 `TextEditingController` instances (name, phone, email, company, address)
- 3 boolean toggles: `_pushNotif`, `_smsNotif`, `_bookingAlerts`

## Data / API Calls
- No API calls (Save button just pops — no backend submission)
- Future: PATCH rust-auth-service /auth/profile

## Status
Static UI (form fields show mock data; save does not persist to backend)

## Notes
- StatefulWidget; all controllers disposed in `dispose()`
- `HirerProfileSettingsStrings(isThai: isThai)` provides bilingual labels
- Image has `errorBuilder` that falls back to person icon (unlike guard version)
- Same `_buildSection()` / `_buildTextField()` / `_buildToggleRow()` helper pattern as guard version
