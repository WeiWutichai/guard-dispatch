# Automation / กฎอัตโนมัติ

## Route
`/automation`

## Purpose / วัตถุประสงค์
Create and manage business rule automation for the dispatch system. Define trigger-action rules that automate repetitive tasks such as guard assignment, notification sending, and status updates based on configurable conditions.

สร้างและจัดการกฎอัตโนมัติสำหรับระบบเรียก รปภ. กำหนดกฎ trigger-action ที่ทำงานอัตโนมัติ เช่น การมอบหมายเจ้าหน้าที่ การส่งแจ้งเตือน และการอัปเดตสถานะตามเงื่อนไขที่กำหนด

## UI Components
- Rule list with columns: name, trigger type, action type, status toggle, last executed, execution count
- Status toggle switch for enabling/disabling individual rules
- Rule builder modal:
  - Trigger configuration: event type, conditions, filters
  - Action configuration: action type, parameters, targets
- Execution history table showing past rule executions with results
- Test rule button for dry-run validation

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Create new automation rules via rule builder modal
- Edit existing rules (trigger conditions and actions)
- Delete rules with confirmation
- Enable or disable rules via status toggle
- View execution history for each rule
- Test rules with dry-run execution
- Filter rules by type or status

## i18n Keys
`t.automation.*`

## Related Backend Service
- No dedicated backend service yet -- will require automation engine
- Rules would interact with booking, notification, and tracking services

## Status
Mock Data

## Notes
- Rule builder uses a trigger-action pattern: define when (trigger) and what (action)
- Example rules: auto-assign nearest guard, send reminder 30 min before task, escalate unaccepted requests
- Execution history provides audit trail for automated actions
- Test/dry-run allows validating rules without side effects
- Future: implement rule execution engine as a background service
- Future: add complex condition chains (AND/OR logic) in rule builder
- Future: support webhook triggers for external system integration
