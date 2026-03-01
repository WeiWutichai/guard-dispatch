# Payment Screen / หน้าชำระเงิน

## File
`frontend/mobile/lib/screens/hirer/payment_screen.dart`

## Purpose / วัตถุประสงค์
Final checkout step for booking a guard. Shows a payment summary card, a security/trust banner, and 4 payment method options. The pay button is visually present but disabled (semi-transparent). No actual payment processing occurs.

ขั้นตอนสุดท้ายของการจอง แสดงสรุปยอดชำระ แบนเนอร์ความปลอดภัย และ 4 วิธีชำระเงิน ปุ่มชำระเงินมีการแสดงผลแต่ไม่ทำงาน

## User Role
Customer (Hirer)

## Navigation
- From: GuardSelectionScreen ("Confirm Booking" button)
- To: No further navigation (pay button has no handler)
- To: NotificationScreen (via bell icon)
- Back: Previous screen via back button

## UI Elements

### Header (primary color, rounded bottom)
- SecureGuard branding, notification bell, person icon

### Back + Title Row
- Back button, "Payment" title

### Payment Summary Card (primary border)
- Service fee: "Service (6 hrs × 1)" = ฿1,000
- Tip/Bonus: ฿200
- Divider
- Grand Total: ฿1,200 (large primary bold)

### Secure Payment Banner
- `check_circle_rounded` icon (primary)
- "Secure Payment" title
- Explanation: funds held by platform, released on completion, refundable if service fails

### Payment Methods (4 options, no selection state)
- PromptPay: qr_code icon, "Scan QR for payment"
- Credit Card: credit_card icon, "Visa, MasterCard, JCB"
- Debit Card: account_balance_wallet icon, "All local banks"
- Mobile Banking: smartphone icon, "Mobile Banking App"
- No radio button / selection — display only

### Pay Button
- Full-width button: "Pay ฿1,200"
- Background: `AppColors.primary.withValues(alpha: 0.4)` — appears disabled/semi-transparent
- `onPressed: () {}` — no handler (intentionally non-functional)

## Data / API Calls
- No API calls (all amounts hardcoded)
- Future: Payment gateway integration (PromptPay/Omise/2C2P)

## Status
Static UI (no payment processing, button visible but non-functional)

## Notes
- StatelessWidget
- Bilingual inline (isThai ternary, no strings class)
- Pay button's semi-transparent appearance visually communicates "not yet implemented"
- All amounts hardcoded: ฿1,000 service + ฿200 tip = ฿1,200 total
