# Guard Dashboard Screen / หน้าหลักเจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/guard_dashboard_screen.dart`

## Purpose / วัตถุประสงค์
Root scaffold for the guard role. Hosts 5 bottom navigation tabs using `IndexedStack` to preserve state across tab switches. This is the first screen a guard sees after successful authentication.

หน้าหลักสำหรับบทบาทเจ้าหน้าที่ รปภ. มีแถบนำทางด้านล่าง 5 แท็บ ใช้ `IndexedStack` เพื่อรักษา state ของแต่ละแท็บเมื่อสลับกัน

## User Role
Guard

## Navigation
- From: RoleSelectionScreen (after OTP) or GuardLoginScreen
- To: Each tab renders its own sub-screens

## Bottom Navigation Tabs
| Index | Icon | Tab Component | Label |
|---|---|---|---|
| 0 | `home_rounded` | GuardHomeTab | หน้าหลัก / Home |
| 1 | `assignment_rounded` | GuardJobsTab | งาน / Jobs |
| 2 | `chat_bubble_rounded` | ChatListScreen | แชท / Chat |
| 3 | `account_balance_wallet_rounded` | GuardIncomeTab | รายได้ / Income |
| 4 | `person_rounded` | GuardProfileTab | เพิ่มเติม / More |

## UI Elements
- Body: `IndexedStack` — all 5 tab widgets are built at once but only the active one is visible
- BottomNavigationBar: white background, primary color selected, shadow above
- Selected item: `AppColors.primary` with bold label (12px)
- Unselected item: `AppColors.textSecondary` with medium label (12px)
- `BottomNavigationBarType.fixed` — all items always visible (no shifting)

## State
- `_currentIndex` (int) — tracks active tab, updated via `setState` on `onTap`

## Data / API Calls
- No direct API calls — delegated to each tab

## Status
Functional (navigation structure complete)

## Notes
- StatefulWidget with `_GuardDashboardScreenState`
- Uses bilingual labels via `GuardDashboardStrings(isThai: isThai)`
- `IndexedStack` ensures tabs are not re-built on switch (preserves scroll position, form state)
