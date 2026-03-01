# Settings / ตั้งค่า

## Route
`/settings`

## Purpose / วัตถุประสงค์
Platform-wide configuration page with organized sections for personal profile, notification preferences, security settings, appearance customization, and company information management.

หน้าตั้งค่าแพลตฟอร์มแบบรวมศูนย์ จัดหมวดหมู่เป็นโปรไฟล์ส่วนตัว การแจ้งเตือน ความปลอดภัย การแสดงผล และข้อมูลบริษัท

## UI Components
- 5-tab sidebar navigation:
  - Profile: name, email, phone, avatar upload
  - Notifications: toggle switches for email, push, SMS notification types per event category
  - Security: password change form, two-factor authentication toggle, active sessions list
  - Appearance: theme switcher (light/dark/system), language selector (TH/EN), density options
  - Company: company name, address, tax ID, logo upload, contact information
- Form validation with inline error messages
- Save/cancel action buttons per section
- Confirmation dialogs for security-sensitive changes

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Update personal profile information
- Change password (requires current password verification)
- Toggle two-factor authentication on/off
- Manage notification preferences per event type
- Switch between light and dark themes
- Change display language (Thai/English)
- Update company information and logo
- View and terminate active sessions

## i18n Keys
`t.settings.*`

## Related Backend Service
- **Auth Service** (port 3001) -- profile and security settings
- **Notification Service** (port 3004) -- notification preferences

## Status
Mock Data

## Notes
- Password changes require current password verification before allowing update
- Theme switching integrates with ThemeProvider component
- Language switching integrates with LanguageProvider and i18n system
- File uploads (avatar, logo) must follow project rules: JPEG/PNG/WEBP only, 10MB max, magic bytes validation
- Future: connect to auth service for profile and password management
- Future: connect to notification service for preference persistence
- Future: implement session management with real session data from Redis
