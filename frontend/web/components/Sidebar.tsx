"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Map as MapIcon,
  Users,
  Users2,
  Briefcase,
  Settings,
  UserPlus,
  FileText,
  ShieldCheck,
  ShieldAlert,
  Star,
  Wallet,
  DollarSign,
  Activity,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "./LanguageProvider";
import { useAuth } from "./AuthProvider";

export function Sidebar() {
  const pathname = usePathname();
  const { t } = useLanguage();
  const { user } = useAuth();

  const navigation = [
    { name: t.nav.liveMap, href: "/map", icon: MapIcon },
    { name: t.nav.applicants, href: "/applicants", icon: UserPlus },
    { name: t.nav.guards, href: "/guards", icon: Users },
    { name: t.nav.expiringDocs, href: "/expiring", icon: ShieldAlert },
    { name: t.nav.customers, href: "/customers", icon: Users2 },
    { name: t.nav.reviews, href: "/reviews", icon: Star },
    { name: t.nav.wallet, href: "/wallet", icon: Wallet },
    { name: t.nav.pricing, href: "/pricing", icon: DollarSign },
    { name: t.nav.tasks, href: "/tasks", icon: Briefcase },
    { name: t.nav.reports, href: "/reports", icon: FileText },
    { name: t.nav.activity, href: "/activity", icon: Activity },
    { name: t.nav.settings, href: "/settings", icon: Settings },
  ];

  const displayName = user?.full_name || "Admin User";
  const displayEmail = user?.email || "";
  const initials = displayName.split(" ").map(n => n[0]).join("").slice(0, 2).toUpperCase();

  return (
    <div className="flex flex-col w-64 bg-white border-r border-slate-200 h-screen sticky top-0">
      <div className="flex items-center h-16 px-6 border-b border-slate-200">
        <div className="w-8 h-8 rounded bg-primary flex items-center justify-center mr-3">
          <ShieldCheck className="text-white w-5 h-5" />
        </div>
        <span className="text-xl font-bold text-slate-900 tracking-tight">
          Guard Dispatch
        </span>
      </div>

      <nav className="flex-1 overflow-y-auto p-4 space-y-1">
        {navigation.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center px-3 py-2.5 text-sm font-medium rounded-lg transition-colors group",
                isActive
                  ? "bg-accent text-accent-foreground"
                  : "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              )}
            >
              <item.icon className={cn(
                "mr-3 h-5 w-5 flex-shrink-0 transition-colors",
                isActive ? "text-primary" : "text-slate-400 group-hover:text-slate-500"
              )} />
              {item.name}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-slate-200">
        <div className="flex items-center p-2 rounded-lg bg-slate-50">
          <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center mr-3">
            <span className="text-xs font-semibold text-primary">{initials}</span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-slate-900 truncate">{displayName}</p>
            <p className="text-xs text-slate-500 truncate">{displayEmail}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
