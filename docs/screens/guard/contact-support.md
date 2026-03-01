# Contact Support Screen / หน้าติดต่อสนับสนุน

## File
`frontend/mobile/lib/screens/guard/contact_support_screen.dart`

## Purpose / วัตถุประสงค์
Help and support center for guards. Shows contact channels (phone, LINE, email), an expandable FAQ accordion, and a bug/issue report section.

ศูนย์ช่วยเหลือและสนับสนุนสำหรับเจ้าหน้าที่ แสดงช่องทางติดต่อ (โทรศัพท์ LINE อีเมล) FAQ แบบขยายได้ และส่วนรายงานปัญหา

## User Role
Guard

## Navigation
- From: GuardProfileTab (Contact Support menu)
- To: No outbound navigation

## UI Elements

### AppBar (deepBlue)
- Back button, "Contact Support" title

### Header Section (deepBlue, rounded bottom)
- Headset icon in primary-tinted circle
- "How can we help?" title
- Subtitle description

### Contact Channels (3 cards)
- **Call Center**: phone icon (AppColors.info), number, operating hours
- **LINE Chat**: chat icon (AppColors.success), LINE ID, availability info
- **Email Support**: email icon (AppColors.warning), email address, response time
- Each card: 48px icon container, title, value (primary bold), description, chevron

### FAQ Section (expandable accordion)
- "Frequently Asked Questions" header
- 3 FAQ items with expand/collapse:
  - Question row: `?` circle badge, question text, up/down arrow
  - Answer: appears below on expand (56px left padding, gray text)
- FAQ content provided by `ContactSupportStrings` (bilingual)

### Report Issue Section (danger-tinted card)
- bug_report icon (AppColors.danger)
- "Report an Issue" title + description
- "Report" outlined button (danger color, no handler yet)

## State
- `_expandedFaq` Map<int, bool> — tracks expanded state per FAQ item index

## Data / API Calls
- No API calls (static contact info and FAQ content)
- Future: submit issue reports to support ticket system

## Status
Static UI (all contact info and FAQ hardcoded; report button has no handler)

## Notes
- StatefulWidget (FAQ accordion requires state)
- `ContactSupportStrings(isThai: isThai)` provides bilingual channel info, FAQ Q&A
- FAQ items use `InkWell` with `borderRadius` for ripple effect
- Contact cards have forward chevron but no navigation handlers (future: deep link to phone/LINE/email apps)
