# Guard Income Tab / แท็บรายได้เจ้าหน้าที่

## File
`frontend/mobile/lib/screens/guard/tabs/guard_income_tab.dart`

## Purpose / วัตถุประสงค์
Three-panel income management screen for guards. Shows income tracking with a monthly goal progress bar, bonus points accumulation, and a wallet section for withdrawals. All data is mock.

หน้าจัดการรายได้ 3 แผง: ติดตามรายได้พร้อมแถบความคืบหน้าเป้าหมายรายเดือน สะสมคะแนน bonus และกระเป๋าเงินสำหรับถอนเงิน ข้อมูลทั้งหมดเป็น mock

## User Role
Guard

## Navigation
- From: GuardDashboardScreen (tab index 3)
- No outbound navigation

## UI Elements

### AppBar
- Back button, "Income" title

### Sub-Tab Navigation
3 pill-style buttons at the top (not standard TabBar — custom Row):
- **Income Goals** (เป้าหมายรายได้)
- **Bonus & Points** (โบนัสและคะแนน)
- **Wallet** (กระเป๋าเงิน)

Active tab: primary color fill, white text. Inactive: white fill, border.

### Sub-Tab 1: Income Goals
- Section header: "Track Income"
- Monthly goal card: ฿18,750 / ฿25,000 with green "On Track" badge, LinearProgressIndicator (75%), completed jobs and days left footnotes
- Weekly stats card (primary gradient): ฿8,900 this week, +16.3%, avg per job, job count
- Daily income list: 3 items with date, job count, hours, amount, hourly rate

### Sub-Tab 2: Bonus & Points
- Points progress card (primary gradient): 120/200 points, LinearProgressIndicator
- Performance stats 2×2 grid: Performance (85%), Completed jobs (12), Accept rate (92%), Work hours (48h)

### Sub-Tab 3: Wallet
- Balance card (primary color): ฿5,420 withdrawable, pending approval info box
- Withdrawal form: min amount label, numeric TextField, bank account info row, withdraw button, free fee info
- Withdrawal history: 3 items with amount, date, bank info, success/failed Chip

## State
- `_activeSubTab` (int) — 0/1/2 for active sub-tab

## Data / API Calls
- No API calls (all mock data)
- Future: rust-booking-service for income data; bank service for withdrawals

## Status
Static UI (all figures hardcoded)

## Notes
- StatefulWidget with manual sub-tab switching via `setState`
- `GuardIncomeStrings(isThai: isThai)` provides bilingual text
- Wallet withdraw button has no handler — future integration with payment service
- `AppGradients.primaryGradient` used for weekly stats and points cards
