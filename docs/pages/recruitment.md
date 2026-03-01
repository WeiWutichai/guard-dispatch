# Recruitment / สรรหาบุคลากร

## Route
`/recruitment`

## Purpose / วัตถุประสงค์
Manage the guard hiring pipeline using a Kanban-style board. Track candidates through recruitment stages from initial application to final hiring, with scoring across multiple dimensions.

จัดการกระบวนการสรรหาเจ้าหน้าที่ รปภ. ผ่านบอร์ดแบบ Kanban ติดตามผู้สมัครตั้งแต่ขั้นตอนสมัครจนถึงการจ้างงาน พร้อมการให้คะแนนหลายมิติ

## UI Components
- Kanban board with 7 stages:
  - Applied, Screening, Interview, Background Check, Training, Offer, Hired
- Candidate cards displaying: name, photo, score summary, current stage, applied date
- Candidate detail modal with scoring across 4 dimensions
- List view toggle (switch between Kanban and table layout)
- Stage progress indicators
- Offer letter and rejection action buttons

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Drag and drop candidates between recruitment stages
- Rate candidates across 4 scoring dimensions
- View detailed candidate profile and evaluation history
- Send offer to qualified candidates
- Reject candidates with reason
- Hire candidates (final stage transition)
- Toggle between Kanban board view and list view

## i18n Keys
`t.recruitment.*`

## Related Backend Service
- No dedicated backend service yet -- will require recruitment pipeline endpoints
- Hired candidates may integrate with auth service for account creation

## Status
Mock Data

## Notes
- Kanban drag-and-drop provides visual workflow management for the hiring pipeline
- 4 scoring dimensions allow structured evaluation of candidates
- Candidates who complete the pipeline (Hired) could be automatically added as guards
- List view provides an alternative tabular layout for managing large candidate pools
- Future: integrate with applicants page for a unified onboarding workflow
- Future: add email/notification triggers at stage transitions
