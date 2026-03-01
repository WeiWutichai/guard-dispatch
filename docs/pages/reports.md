# Reports / รายงาน

## Route
`/reports`

## Purpose / วัตถุประสงค์
Analytics and business reporting dashboard with KPI metrics, trend visualizations, and data export capabilities. Provides insights into operational performance, revenue, guard utilization, and customer satisfaction.

แดชบอร์ดการวิเคราะห์และรายงานธุรกิจพร้อมตัวชี้วัด KPI กราฟแนวโน้ม และความสามารถในการส่งออกข้อมูล ให้ข้อมูลเชิงลึกเกี่ยวกับประสิทธิภาพการดำเนินงาน รายได้ การใช้งานเจ้าหน้าที่ และความพึงพอใจลูกค้า

## UI Components
- KPI cards: key performance indicators with trend arrows (up/down vs previous period)
- Period selector: daily, weekly, monthly, quarterly, yearly
- Chart visualizations:
  - Line chart: trends over time (bookings, revenue)
  - Pie chart: distribution breakdowns (status, guard types, areas)
  - Bar chart: comparisons (guard performance, area revenue)
- Report type selector (operational, financial, guard performance, customer satisfaction)
- Export buttons: PDF and Excel download options

## Data Source
Mock data -- not yet connected to backend API

## User Actions
- Select report type (operational/financial/performance/satisfaction)
- Filter by time period (daily/weekly/monthly/quarterly/yearly)
- View interactive chart visualizations
- Export reports as PDF or Excel files
- Compare metrics across different periods

## i18n Keys
`t.reports.*`

## Related Backend Service
- Data aggregation across multiple services: booking, auth, tracking
- No dedicated reporting service yet

## Status
Mock Data

## Notes
- Charts use client-side rendering with mock data points
- Export functionality generates files client-side from displayed data
- Future: implement server-side report generation for large datasets
- Future: add scheduled report delivery via email
- Future: connect to real data from booking, tracking, and auth services for live analytics
- Future: add custom report builder for ad-hoc queries
