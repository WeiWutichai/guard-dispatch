# Pricing / กำหนดราคา

## Route
`/pricing`

## Purpose / วัตถุประสงค์
Configure service rates, commission structures, area-based pricing, flexible pricing rules, and promotional codes. Central hub for all pricing-related settings that affect guard service costs and platform revenue.

กำหนดอัตราค่าบริการ โครงสร้างค่าคอมมิชชัน ราคาตามพื้นที่ กฎราคายืดหยุ่น และรหัสโปรโมชัน ศูนย์กลางการตั้งค่าราคาทั้งหมดที่มีผลต่อค่าบริการเจ้าหน้าที่และรายได้แพลตฟอร์ม

## UI Components
- 6-tab sidebar navigation:
  - Services: base rates per guard type and duration
  - Commission: platform commission percentages and tiers
  - Areas: area-based pricing adjustments and zones
  - Flexibility: dynamic pricing rules (surge, off-peak, holidays)
  - Promotions: promo code management (create, edit, expire)
  - History: pricing change audit log
- Rate editing forms with validation
- Commission tier configuration table
- Promo code table with status toggles
- Change history timeline

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Edit base service rates by guard type and duration
- Adjust commission percentages and tier thresholds
- Configure area-based pricing multipliers
- Toggle flexible pricing rules on/off
- Create, edit, and expire promotional codes
- View pricing change history

## i18n Keys
`t.pricing.*`

## Related Backend Service
- No dedicated backend service yet -- will require pricing/configuration endpoints

## Status
Mock Data

## Notes
- Pricing changes should be audited with before/after values in the history tab
- Promo codes support percentage and fixed-amount discounts
- Area-based pricing allows different rates for different geographic zones
- Flexible pricing rules can adjust rates based on time of day, demand, or special events
- Future: integrate with booking service to apply pricing rules during request creation
- Future: add bulk rate update functionality
