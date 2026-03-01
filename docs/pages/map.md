# Live Map / แผนที่สด

## Route
`/map`

## Purpose / วัตถุประสงค์
Real-time GPS tracking of security guards on an interactive map. Displays guard positions, duty status, and allows filtering by status. Provides a visual overview of guard deployment across service areas.

ติดตามตำแหน่ง GPS ของเจ้าหน้าที่รักษาความปลอดภัยแบบเรียลไทม์บนแผนที่ แสดงตำแหน่งเจ้าหน้าที่ สถานะการปฏิบัติงาน และกรองตามสถานะได้ ให้ภาพรวมการจัดวางกำลังพลในพื้นที่บริการ

## UI Components
- 4 stat cards: Total Guards, On Duty, Available, On Task (gradient backgrounds)
- Simulated map canvas with guard position markers (colored by status)
- Guard list sidebar showing all guards with status indicators
- Status filter buttons (All/On Duty/Available/On Task/Offline)
- Guard marker popups with basic info on click

## Data Source
Mock data -- placeholder implementation
- Production target: `trackingApi.connectGpsWebSocket()` via WebSocket at `/ws/track`

## User Actions
- View guard positions on map canvas
- Filter guards by status using sidebar or filter buttons
- Click on guard markers to see guard details
- Browse guard list in sidebar panel

## i18n Keys
`t.map.*`

## Related Backend Service
- **Tracking Service** (port 3003) -- GPS data via WebSocket (`/ws/track`) and REST (`/tracking/*`)

## Status
Mock Data

## Notes
- Current map implementation is a placeholder canvas, not a real map library (e.g., Leaflet, Mapbox)
- GPS data must be sent via WebSocket only (REST polling is prohibited per project rules)
- GPS update target latency: less than 3 seconds (critical performance requirement)
- WebSocket authentication uses cookies (tokens must not be sent in URL query params)
- Future: integrate a real map library with tile layers and proper geospatial rendering
- Future: connect to tracking service WebSocket for live guard position updates
- Future: add geofencing visualization for service areas
