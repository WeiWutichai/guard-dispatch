# Role Selection Screen / หน้าเลือกบทบาท

## File
`frontend/mobile/lib/screens/role_selection_screen.dart`

## Purpose / วัตถุประสงค์
Presents the user with two role options: hire a security guard (customer) or work as a security guard. Each role is displayed as a glassmorphism card with description, icon, and call-to-action button. Includes a language toggle and platform stats.

หน้าจอสำหรับเลือกบทบาท: เรียก รปภ. (ผู้เรียก) หรือ เข้าสู่ระบบเจ้าหน้าที่ (ผู้รักษาความปลอดภัย) แสดงในรูปแบบการ์ด glassmorphism พร้อมคำอธิบายและปุ่ม CTA รองรับสลับภาษา

## User Role
Both (Guard and Customer)

## Navigation
- From: OtpVerificationScreen (after successful OTP)
- To: HirerDashboardScreen (customer card tap) or GuardDashboardScreen (guard card tap)

## UI Elements
- Language toggle (top right, LanguageToggle widget)
- P-Guard logo and brand name with accent line
- Role selection title and subtitle (animated on language change)
- Hire Guard card: home_work icon, primary color, filled CTA button
- Guard Login card: badge icon, teal color, outlined CTA button
- Both cards use glassmorphism (BackdropFilter with blur, semi-transparent background)
- Footer section: platform branding and terms text
- Stats section in footer area
- Background decorative blobs

## Data / API Calls
- No API calls on this screen
- Navigation passes to respective dashboard screens

## Status
Static UI (no backend integration)

## Notes
- StatelessWidget -- no state management needed
- Cards use AnimatedSwitcher for smooth language transition
- ScrollView with BouncingScrollPhysics for overflow handling
- RoleSelectionStrings provides bilingual text from l10n/app_strings.dart
- Footer letter spacing adjusts based on language (0 for Thai, 1.5 for English)
