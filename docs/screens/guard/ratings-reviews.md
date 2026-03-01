# Ratings & Reviews Screen / หน้าคะแนนและรีวิว

## File
`frontend/mobile/lib/screens/guard/ratings_reviews_screen.dart`

## Purpose / วัตถุประสงค์
Shows a guard's performance ratings from customers. Displays overall score, category breakdown bars, and a list of recent written reviews. All data is mock.

แสดงคะแนนประสิทธิภาพของเจ้าหน้าที่จากลูกค้า แสดงคะแนนรวม แถบแบ่งรายหมวด และรายการรีวิวล่าสุด ข้อมูลทั้งหมดเป็น mock

## User Role
Guard

## Navigation
- From: GuardProfileTab (Reviews menu)
- To: No outbound navigation

## UI Elements

### AppBar (deepBlue)
- Back button, "Ratings & Reviews" title

### Overall Rating Card (primary gradient)
- "Overall Rating" label
- Large 4.8 score (56px bold white)
- 5 star icons (4 filled `star_rounded`, 1 half `star_half_rounded`, amber color)
- "Based on X reviews" caption

### Rating Breakdown Card
- Title: "Rating Breakdown"
- 4 category rows, each with label, score badge (star + number), and LinearProgressIndicator:
  - Punctuality (ตรงต่อเวลา): 4.9
  - Professionalism (ความเป็นมืออาชีพ): 4.8
  - Communication (การสื่อสาร): 4.6
  - Appearance (การแต่งกาย): 4.9

### Recent Reviews Section
- Section title "Recent Reviews"
- 3 review cards, each containing:
  - CircleAvatar with person icon (AppColors.info tint)
  - Reviewer name + date
  - Star rating (numeric, bold)
  - Review text (14px, gray, line height 1.4)

## Data / API Calls
- No API calls (3 sample reviews hardcoded via `RatingsReviewsStrings`)
- Future: rust-notification-service or rust-booking-service GET /reviews?guard_id=

## Status
Static UI (all ratings and reviews are mock data)

## Notes
- StatelessWidget — no state management needed
- `RatingsReviewsStrings(isThai: isThai)` provides bilingual review content
- Progress bar value: `rating / 5.0` (0.0–1.0)
- `AppGradients.primaryGradient` for overall rating card background
