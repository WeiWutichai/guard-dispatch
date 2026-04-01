# Booking Screen / หน้าจองบริการ

## File
`frontend/mobile/lib/screens/hirer/booking_screen.dart`

## Purpose / วัตถุประสงค์
Full booking form for hiring a security guard. Collects service duration, start/end date/time, location, job description, required equipment, additional services, and shows a live price summary with guard count selector. Submitting navigates to GuardSelectionScreen.

ฟอร์มจองบริการเต็มรูปแบบสำหรับผู้เรียก รวบรวมระยะเวลา วันเริ่ม/สิ้นสุด สถานที่ รายละเอียดงาน อุปกรณ์ที่ต้องการ และแสดงสรุปราคา

## User Role
Customer (Hirer)

## Navigation
- From: ServiceSelectionScreen ("Select" button)
- To: GuardSelectionScreen ("Find Guard" button)
- To: NotificationScreen (via bell icon)

## UI Elements

### Header (primary color, rounded bottom)
- Back button, P-Guard branding, notifications icon, person icon

### Form Sections

**Service Time**
- Duration selector: 3 pill buttons (12 hours / 8 hours / Custom — custom selected by default)
- Start Date picker (date field placeholder, no real picker)
- Start Time picker (time field placeholder)
- End Date picker + End Time picker (2-column row)
- Duration info box: "Duration: 6 Hours • Rate ฿100/hr • Est. Total ฿600"

**Location**
- Address TextField with hint "Enter address or use current GPS"
- "Pin on map" button (map_outlined icon)
- "Use Current Location" button (my_location_rounded icon)
- Both location buttons have no handlers yet

**Job Details**
- Multi-line TextArea (4 lines), placeholder for job description

**Security Equipment** (checklist, 6 items)
- Flashlight, Handcuffs, Baton/Traffic baton, Uniform, Uniform+polo, Other
- Default selected: Flashlight + Handcuffs
- Tap to toggle selection (check_box_rounded when selected)

**Additional Services** (3 checkboxes, all unselected)
- Has Pets, Water Plants, Utility Check
- Checkboxes not functional (outline only, no toggle state)

**Price Summary Card** (primary border)
- Service estimate row: ฿600
- Guard count stepper: -/count/+ buttons (min 1, reactive)
- Tip/Bonus field (display only, not functional)
- Grand Total: ฿600 × guard count (reactive to guard count)

**Find Guard Button**
- Full-width primary button → GuardSelectionScreen

## State
- `_selectedDuration` (String) — current duration pill selection
- `_guardCount` (int) — number of guards, affects total price
- `_selectedEquipment` `Set<String>` — toggleable equipment items

## Data / API Calls
- No API calls (form data not submitted anywhere)
- Future: POST to rust-booking-service /booking/requests

## Status
Static UI with partial interactivity (duration selector, equipment toggle, guard count stepper functional; date/time pickers are placeholders)

## Notes
- StatefulWidget
- Bilingual inline (uses `isThai` ternary directly, no strings class)
- Date/time pickers are styled containers with placeholder text — no real picker implemented
- Additional services checkboxes are not interactive (always unchecked)
- Grand total = ฿600 × `_guardCount` (ignores tip field)
