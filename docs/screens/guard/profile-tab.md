# Guard Profile Tab / แท็บโปรไฟล์เจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/tabs/guard_profile_tab.dart`

## Purpose / วัตถุประสงค์
iOS Settings-style profile hub for guards. Shows a profile card at the top (avatar, name, guard code, badges) followed by grouped settings rows. Each row navigates to a specific sub-screen.

หน้าโปรไฟล์สไตล์ iOS Settings สำหรับเจ้าหน้าที่ แสดงการ์ดโปรไฟล์ด้านบน ตามด้วยกลุ่มเมนูตั้งค่าที่นำไปยังหน้าย่อยต่าง ๆ

## User Role
Guard

## Navigation
- From: GuardDashboardScreen (tab index 4)
- To: ApplicationStatusScreen (Application Status menu)
- To: GuardRegistrationScreen (Register as Guard menu)
- To: ProfileSettingsScreen (Settings menu)
- To: RatingsReviewsScreen (Reviews menu)
- To: WorkHistoryScreen (Work History menu)
- To: ContactSupportScreen (Support menu)
- To: PhoneInputScreen (Logout — clears stack with `pushAndRemoveUntil`)

## UI Elements
- Large title "โปรไฟล์" / "Profile" (34px bold, iOS large title style)
- **Profile Card**: network avatar (pravatar.cc), name, guard code, "Verified" badge (green), "Not Registered" badge (gray), chevron → ProfileSettingsScreen
- **Group 1 — Account & Registration**:
  - Application Status (purple icon)
  - Register as Guard (orange icon)
- **Group 2 — Settings & Reviews**:
  - Settings (gray icon) → ProfileSettingsScreen
  - Reviews (yellow icon) → RatingsReviewsScreen
  - Work History (primary blue icon) → WorkHistoryScreen
- **Group 3 — Support**:
  - Contact Support (green icon) → ContactSupportScreen
- **Logout button** (red text, full width, destructive) → navigates to PhoneInputScreen and removes all previous routes

## Data / API Calls
- No API calls (static profile display with placeholder avatar)
- Future: load real guard profile from rust-auth-service

## Status
Static UI (navigations functional, data is mock)

## Notes
- StatelessWidget — no state management (uses `_navigateTo()` helper for all nav)
- Background color: `Color(0xFFF2F2F7)` (iOS system background gray)
- Settings groups use `Container` with `borderRadius: 12` and `InkWell` items (iOS card style)
- Divider between items: 0.5px height, offset left by 60px (below icon)
- `GuardProfileStrings(isThai: isThai)` provides bilingual text
- Logout uses `Navigator.pushAndRemoveUntil` to fully clear navigation stack
