# Guard Home Tab / แท็บหน้าหลักเจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/tabs/guard_home_tab.dart`

## Purpose / วัตถุประสงค์
The primary dashboard view for a guard. Checks registration status on load and shows different content depending on whether the guard is registered. Registered guards see a ready/not-ready toggle, earnings stats, and an alert card. Unregistered guards see a prompt to start registration.

แท็บหลักสำหรับเจ้าหน้าที่ รปภ. ตรวจสอบสถานะการลงทะเบียนเมื่อโหลด และแสดงเนื้อหาต่างกันตามสถานะ

## User Role
Guard

## Navigation
- From: GuardDashboardScreen (tab index 0)
- To: GuardRegistrationScreen (via "Register Now" button when not registered)

## UI Elements

### Header
- Back icon button (navigates to previous screen / role selection)
- Circular avatar (48px, person icon, primary color bg)
- Guard name and greeting text (from strings)
- Notification bell icon button (no handler yet)

### When NOT Registered
- Clock icon in gray circle
- "Not Registered" pill badge
- "Register to start" subtitle text
- "Register Now" full-width primary button → GuardRegistrationScreen

### When Registered
- **Status Toggle Card**: "Ready" / "Not Ready" label with green/red dot indicator and adaptive Switch
- **Stats Grid** (2 cards side by side):
  - Today's earnings (฿1,450 — mock) with today icon (AppColors.info)
  - This week's earnings (฿8,900 — mock) with analytics icon (AppColors.primary)
- **Alert Card**: Changes appearance based on `_isReady` toggle:
  - Ready: primary color border, `notifications_active` icon, "Waiting for new jobs" message + "View New Jobs" button
  - Not Ready: gray border, `notifications_off` icon, "Set yourself available" message

## State
- `_isReady` (bool) — controls ready/not-ready toggle
- `_isRegistered` (bool) — loaded from `AuthService.isRegistered('guard')` on init

## Data / API Calls
- `AuthService.isRegistered('guard')` — reads registration flag from `SharedPreferences`
- Future: rust-booking-service to set guard availability status
- Pull-to-refresh: `RefreshIndicator` re-calls `_loadStatus()`

## Status
Partially functional (registration check works; stats and job alerts use mock data)

## Notes
- StatefulWidget with `initState` loading registration status
- `AlwaysScrollableScrollPhysics` ensures pull-to-refresh works even when content is short
- `GuardHomeStrings(isThai: isThai)` provides bilingual text
- "View New Jobs" button has no handler yet
