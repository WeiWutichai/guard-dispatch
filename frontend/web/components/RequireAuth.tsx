"use client";

import { type ReactNode } from "react";
import { Loader2 } from "lucide-react";
import { useAuth } from "./AuthProvider";

/**
 * Gates the whole dashboard shell (Sidebar + Header + content) on auth.
 *
 * Without this, the server-rendered `DashboardLayout` painted the admin shell
 * immediately while `AuthProvider` was still resolving the session, so an
 * unauthenticated visitor to `/` saw the dashboard flash before the
 * redirect-to-login effect fired. Rendering a full-screen loader until auth is
 * resolved (and while the redirect is in-flight) removes that flash entirely.
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  const { isLoading, isAuthenticated } = useAuth();

  // `isLoading` → still checking the session. `!isAuthenticated` → AuthProvider's
  // redirect effect is about to push to /login; show the loader rather than the
  // shell during that brief window.
  if (isLoading || !isAuthenticated) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return <>{children}</>;
}
