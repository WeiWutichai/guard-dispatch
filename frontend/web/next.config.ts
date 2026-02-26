import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  basePath: "/pguard-app",
  async rewrites() {
    // In development, proxy API calls to the backend Nginx gateway
    // In production (Docker), the Nginx gateway handles routing
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:80";
    return [
      { source: "/api/auth/:path*", destination: `${apiUrl}/auth/:path*` },
      { source: "/api/booking/:path*", destination: `${apiUrl}/booking/:path*` },
      { source: "/api/tracking/:path*", destination: `${apiUrl}/tracking/:path*` },
      { source: "/api/notification/:path*", destination: `${apiUrl}/notification/:path*` },
      { source: "/api/chat/:path*", destination: `${apiUrl}/chat/:path*` },
    ];
  },
};

export default nextConfig;
