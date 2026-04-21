"use client";

import { type ReactNode } from "react";
import { ShieldX, Loader2 } from "lucide-react";
import { useAuth } from "./AuthProvider";
import { useLanguage } from "./LanguageProvider";

/**
 * Renders children only for admin users.
 *
 * Backend already enforces admin-only routes with `require_admin()`, but the
 * UI needs a frontend gate so authenticated guards/customers who land on
 * /applicants, /wallet, etc. see a clean "unauthorized" screen instead of
 * the admin shell with broken tables.
 *
 * Defense-in-depth — if a backend endpoint ever ships without its admin guard,
 * this still protects the UI from leaking the admin IA to non-admins.
 */
export function AdminOnly({ children }: { children: ReactNode }) {
  const { user, isLoading } = useAuth();
  const { locale } = useLanguage();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!user || user.role !== "admin") {
    return (
      <div className="flex flex-col items-center justify-center h-[calc(100vh-200px)] gap-4 text-center px-6">
        <div className="p-4 bg-red-50 rounded-full">
          <ShieldX className="h-12 w-12 text-red-500" />
        </div>
        <h2 className="text-xl font-bold text-slate-900">
          {locale === "th" ? "คุณไม่มีสิทธิ์เข้าถึงหน้านี้" : "Access denied"}
        </h2>
        <p className="text-sm text-slate-500 max-w-md">
          {locale === "th"
            ? "หน้านี้สำหรับผู้ดูแลระบบเท่านั้น หากคุณคิดว่านี่เป็นข้อผิดพลาด กรุณาติดต่อผู้ดูแลระบบ"
            : "This page is restricted to administrators. If you believe this is an error, please contact your system administrator."}
        </p>
      </div>
    );
  }

  return <>{children}</>;
}
