import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // basePath ใช้เฉพาะ production (ผ่าน Nginx) — dev เข้า localhost:3000 ตรงได้เลย
  basePath: process.env.NEXT_PUBLIC_BASE_PATH || "",
  async rewrites() {
    // Staging/production: each NEXT_PUBLIC_*_URL points directly at the
    // Rust service container on the `backend` Docker network. This bypasses
    // nginx entirely for server-to-server calls, which avoids:
    //   1. HTTP→HTTPS redirects leaking the internal hostname to the browser
    //   2. Needing to terminate TLS twice inside the network
    //   3. Hitting nginx rate limits on legitimate internal traffic
    //
    // Dev (docker-compose.yml / localhost): fallback to the nginx gateway on
    // localhost so a developer running `next dev` still works.
    const authUrl = process.env.NEXT_PUBLIC_AUTH_URL || "http://localhost:80/auth";
    const bookingUrl = process.env.NEXT_PUBLIC_BOOKING_URL || "http://localhost:80/booking";
    const trackingUrl = process.env.NEXT_PUBLIC_TRACKING_URL || "http://localhost:80/tracking";
    const notificationUrl = process.env.NEXT_PUBLIC_NOTIFICATION_URL || "http://localhost:80/notification";
    const chatUrl = process.env.NEXT_PUBLIC_CHAT_URL || "http://localhost:80/chat";
    return [
      { source: "/api/auth/:path*", destination: `${authUrl}/:path*` },
      { source: "/api/booking/:path*", destination: `${bookingUrl}/:path*` },
      { source: "/api/tracking/:path*", destination: `${trackingUrl}/:path*` },
      { source: "/api/notification/:path*", destination: `${notificationUrl}/:path*` },
      { source: "/api/chat/:path*", destination: `${chatUrl}/:path*` },
    ];
  },
};

export default nextConfig;
