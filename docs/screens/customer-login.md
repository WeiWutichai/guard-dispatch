# Customer Login Screen / หน้าเข้าสู่ระบบลูกค้า

## File
`frontend/mobile/lib/screens/customer_login_screen.dart`

## Purpose / วัตถุประสงค์
Legacy customer login screen that currently displays an "Under Development" placeholder. This screen exists as a stub for the customer authentication flow and is expected to be replaced by the phone+OTP flow.

หน้าเข้าสู่ระบบสำหรับลูกค้า (แบบเดิม) ปัจจุบันแสดงข้อความ "อยู่ระหว่างการพัฒนา" เป็น placeholder สำหรับระบบยืนยันตัวตนลูกค้า คาดว่าจะถูกแทนที่ด้วยระบบ OTP

## User Role
Customer (Hirer)

## Navigation
- From: RoleSelectionScreen (if using legacy login flow)
- To: None (under development placeholder)

## UI Elements
- AppBar with back button and centered title
- Home/work icon in primary-colored rounded container
- "Customer" title (Thai) and English subtitle
- Under development card (surface color, rounded):
  - Construction icon (gray)
  - "Under Development" text in Thai and English

## Data / API Calls
- No API calls (placeholder screen)

## Status
Static UI (placeholder, no functionality)

## Notes
- StatelessWidget with no state management
- Uses BouncingScrollPhysics for scroll behavior
- CustomerLoginStrings provides bilingual text
- This screen may be deprecated in favor of the PhoneInputScreen + OTP flow
