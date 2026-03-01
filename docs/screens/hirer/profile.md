# Hirer Profile Screen / หน้าโปรไฟล์ผู้เรียก

## File
`frontend/mobile/lib/screens/hirer/hirer_profile_screen.dart`

## Purpose / วัตถุประสงค์
iOS Settings-style profile hub for hirers. Shows a profile card (avatar, name, company, hirer code) and grouped settings rows. Navigation hub for account settings, saved locations, payment methods, security, notifications, and support.

หน้าโปรไฟล์สไตล์ iOS Settings สำหรับผู้เรียก แสดงการ์ดโปรไฟล์และเมนูตั้งค่าที่จัดกลุ่ม

## User Role
Customer (Hirer)

## Navigation
- From: HirerDashboardScreen (tab index 3)
- To: HirerProfileSettingsScreen (Edit Profile menu)
- To: HirerProfileSettingsScreen (profile card tap)
- To: "Coming Soon" snackbar (Saved Locations, Payment Methods, Change PIN)
- To: NotificationScreen (Notifications menu)
- To: ContactSupportScreen (Support menu)
- To: PhoneInputScreen (Logout — clears navigation stack)

## UI Elements
- Large title "โปรไฟล์" / "Profile" (34px bold, iOS large title style)
- **Profile Card**: 60px circular avatar (pravatar.cc), hirer name (18px), company, hirer code, chevron → HirerProfileSettingsScreen

- **Group 1 — Account**:
  - Edit Profile (primary blue) → HirerProfileSettingsScreen
  - Saved Locations (purple) → "Coming soon" snackbar
  - Payment Methods (orange) → "Coming soon" snackbar

- **Group 2 — Security & Notifications**:
  - Change PIN (red) → "Coming soon" snackbar
  - Notifications (red) → NotificationScreen

- **Group 3 — Support**:
  - Support (green) → ContactSupportScreen (shared with guard role)

- **Logout button** (red text, full width) → PhoneInputScreen with `pushAndRemoveUntil`

## Data / API Calls
- No API calls (static profile display)
- Future: load hirer profile from rust-auth-service

## Status
Partially functional (navigations work; profile data is mock)

## Notes
- StatelessWidget
- Background: `Color(0xFFF2F2F7)` (iOS system gray)
- `_showComingSoon()` displays a floating `SnackBar` with 2-second duration
- Group 2 uses red `Color(0xFFFF3B30)` for both Lock and Notifications (iOS destructive/notification color)
- Same `_buildSettingsGroup` / `_buildLogoutButton` pattern as GuardProfileTab
- `HirerProfileStrings(isThai: isThai)` for bilingual text
