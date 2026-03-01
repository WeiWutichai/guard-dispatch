# Reviews / รีวิว

## Route
`/reviews`

## Purpose / วัตถุประสงค์
Manage customer reviews and ratings of security guards. Admins can approve or reject reviews, send warnings to guards, and award performance badges. Provides quality oversight for the guard workforce.

จัดการรีวิวและคะแนนจากลูกค้าสำหรับเจ้าหน้าที่ รปภ. ผู้ดูแลสามารถอนุมัติหรือปฏิเสธรีวิว ส่งคำเตือนถึงเจ้าหน้าที่ และมอบตราสัญลักษณ์ผลงาน เพื่อควบคุมคุณภาพการบริการ

## UI Components
- 3 stat cards: Total Reviews, Average Rating, Pending Reviews
- Complex filter panel:
  - Rating filter (1-5 stars)
  - Status filter (pending/approved/rejected)
  - Guard filter (specific guard selection)
  - Area filter (service area)
- Review table with columns: customer, guard, rating, comment preview, status, date
- Review detail modal with full comment and context
- Warning modal for issuing guard warnings
- Badge award modal with 4 badge types (e.g., Excellence, Punctuality, Professionalism, Customer Favorite)

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Filter reviews by rating, status, guard, or area
- Search reviews by content or participant names
- Approve or reject pending reviews
- Open review detail modal for full context
- Send warning to guard based on negative reviews
- Award performance badges to guards (4 badge types available)

## i18n Keys
`t.reviews.*`

## Related Backend Service
- No dedicated backend service yet -- will require review endpoints

## Status
Mock Data

## Notes
- Badge system includes 4 types; badges are displayed on guard profiles after award
- Warning system creates an audit trail for guard performance tracking
- Review moderation is required before reviews become publicly visible
- Future: integrate with booking service to link reviews to specific completed tasks
- Future: implement automated flagging for reviews with extreme ratings or keywords
