# Wallet / กระเป๋าเงิน

## Route
`/wallet`

## Purpose / วัตถุประสงค์
Manage guard payments, balances, and withdrawal requests. Provides a financial overview with tools for processing withdrawals, reviewing transaction history, and configuring payment settings.

จัดการการชำระเงินของเจ้าหน้าที่ รปภ. ยอดเงินคงเหลือ และคำขอถอนเงิน แสดงภาพรวมทางการเงินพร้อมเครื่องมือดำเนินการถอนเงิน ตรวจสอบประวัติธุรกรรม และตั้งค่าการชำระเงิน

## UI Components
- 4 stat cards: Total Balance, Pending Withdrawals, Processed Today, Total Paid Out
- 4-tab layout:
  - Overview: balance summary and recent transactions
  - Withdrawals: pending withdrawal requests with approve/reject actions
  - Admin History: complete transaction log with filters
  - Settings: payment configuration (minimum withdrawal, processing schedule, fees)
- Transaction table with columns: guard name, amount, type, status, date
- Withdrawal approval/rejection controls with confirmation dialog

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- View overall financial balances and stats
- Review pending withdrawal requests
- Approve or reject withdrawal requests
- Browse complete transaction history
- Filter transactions by date, guard, or type
- Update payment settings (minimum amounts, schedules, fee percentages)

## i18n Keys
`t.wallet.*`

## Related Backend Service
- No dedicated backend service yet -- will require payment/wallet endpoints

## Status
Mock Data

## Notes
- Bank account input follows project rules: digits only, max 15 characters, autocorrect disabled
- Withdrawal approval should generate notification to the guard
- Financial data requires careful audit logging for compliance
- Future: integrate with external payment gateway for actual fund transfers
- Future: add export functionality for accounting reports
