# Hirer Dashboard Screen / หน้าหลักผู้เรียก

## File
`frontend/mobile/lib/screens/hirer/hirer_dashboard_screen.dart`

## Purpose / วัตถุประสงค์
Root scaffold for the customer (hirer) role. Hosts 4 bottom navigation tabs using `IndexedStack`. This is the first screen a customer sees after authentication.

หน้าหลักสำหรับบทบาทผู้เรียก รปภ. มีแถบนำทางด้านล่าง 4 แท็บ ใช้ `IndexedStack`

## User Role
Customer (Hirer)

## Navigation
- From: RoleSelectionScreen (after OTP)
- To: Each tab renders its own sub-screens

## Bottom Navigation Tabs
| Index | Icon | Tab Component | Label |
|---|---|---|---|
| 0 | `home_rounded` | ServiceSelectionScreen | หน้าแรก / Home |
| 1 | `chat_bubble_rounded` | ChatListScreen | ข้อความ / Messages |
| 2 | `history_rounded` | HirerHistoryScreen | ประวัติ / History |
| 3 | `person_rounded` | HirerProfileScreen | โปรไฟล์ / Profile |

## UI Elements
- Body: `IndexedStack` — all 4 tab widgets are built at once, only active one visible
- BottomNavigationBar: white background, primary color selected, shadow above
- All labels bilingual inline (no strings class — uses `isThai` ternary directly)
- `BottomNavigationBarType.fixed`, `elevation: 0`

## State
- `_selectedIndex` (int) — tracks active tab

## Data / API Calls
- No direct API calls — delegated to each tab

## Status
Functional (navigation structure complete)

## Notes
- StatefulWidget
- Unlike GuardDashboardScreen, hirer tabs only have 4 items (no income tab)
- Bilingual labels hardcoded inline (not via strings class)
- `IndexedStack` preserves tab state across switches
