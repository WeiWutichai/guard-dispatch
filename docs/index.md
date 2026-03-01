---
layout: home

hero:
  name: "Guard Dispatch"
  text: "ระบบเรียก รปภ. แบบ Real-time"
  tagline: Security Guard Dispatch System — Developer Documentation
  image:
    src: /shield.svg
    alt: Guard Dispatch
  actions:
    - theme: brand
      text: Developer Guide
      link: /DEVELOPER_GUIDE
    - theme: alt
      text: Web Admin Pages
      link: /pages/dashboard
    - theme: alt
      text: Mobile Screens
      link: /screens/phone-input

features:
  - icon: 🦀
    title: Rust Backend (5 services)
    details: Axum 0.8 microservices — Auth, Booking, Tracking, Notification, Chat. JWT, SQLx, Redis, FCM.

  - icon: 🗺️
    title: Real-time GPS Tracking
    details: WebSocket-based GPS updates < 3s. Redis Pub/Sub pipeline. IDOR-protected location endpoints.

  - icon: 📱
    title: Flutter Mobile App
    details: iOS + Android. Guard role (5 tabs) + Hirer role (4 tabs). Provider state management + FlutterSecureStorage.

  - icon: 🖥️
    title: Next.js 16 Web Admin
    details: App Router + TypeScript. 16 pages. Bilingual TH/EN. Cookie-based auth. lucide-react icons.

  - icon: 🐳
    title: Docker Compose (12 containers)
    details: Nginx gateway, 5 Rust services, Node.js mediasoup, PostgreSQL, 2× Redis, MinIO. Non-root containers.

  - icon: 📖
    title: Swagger UI (5 services)
    details: utoipa 5 + utoipa-swagger-ui 9. Bearer JWT auth. Available at /docs on each service port.
---

## Quick Links

| ส่วน | คำอธิบาย | ลิงก์ |
|------|----------|-------|
| Developer Guide | Setup, conventions, step-by-step guides | [DEVELOPER_GUIDE](/DEVELOPER_GUIDE) |
| Web Admin (16 หน้า) | Next.js pages — routes, UI, API | [pages/dashboard](/pages/dashboard) |
| Mobile Common (9 หน้าจอ) | Phone, OTP, PIN, Chat, Call | [screens/phone-input](/screens/phone-input) |
| Mobile Guard (11 หน้าจอ) | Dashboard, Jobs, Income, Registration | [screens/guard/dashboard](/screens/guard/dashboard) |
| Mobile Hirer (8 หน้าจอ) | Booking flow, Payment, History | [screens/hirer/dashboard](/screens/hirer/dashboard) |

## Service Endpoints

| Service | Port | Swagger UI |
|---------|------|-----------|
| rust-auth | 3001 | `http://localhost:3001/docs` |
| rust-booking | 3002 | `http://localhost:3002/docs` |
| rust-tracking | 3003 | `http://localhost:3003/docs` |
| rust-notification | 3004 | `http://localhost:3004/docs` |
| rust-chat | 3006 | `http://localhost:3006/docs` |
