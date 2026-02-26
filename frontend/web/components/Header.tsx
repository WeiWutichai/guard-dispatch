"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { Bell, Search, User, Settings, LogOut, ChevronDown, Languages, AlertTriangle, CheckCircle2, Clock, Shield } from "lucide-react";
import { useLanguage } from "./LanguageProvider";
import { useAuth } from "./AuthProvider";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { notificationApi, type NotificationLog } from "@/lib/api";

type NotificationDisplayType = "alert" | "success" | "warning" | "info";

function mapNotificationType(type: string): NotificationDisplayType {
    if (type.includes("cancel") || type.includes("emergency")) return "alert";
    if (type.includes("complete") || type.includes("arrived")) return "success";
    if (type.includes("assign") || type.includes("en_route")) return "warning";
    return "info";
}

const notificationIcons: Record<NotificationDisplayType, { icon: typeof AlertTriangle; color: string; bg: string }> = {
    alert: { icon: AlertTriangle, color: "text-red-600", bg: "bg-red-50" },
    warning: { icon: Clock, color: "text-amber-600", bg: "bg-amber-50" },
    success: { icon: CheckCircle2, color: "text-emerald-600", bg: "bg-emerald-50" },
    info: { icon: Shield, color: "text-blue-600", bg: "bg-blue-50" },
};

function timeAgo(dateStr: string, locale: string): string {
    const diff = Date.now() - new Date(dateStr).getTime();
    const minutes = Math.floor(diff / 60000);
    if (minutes < 1) return locale === "th" ? "เมื่อสักครู่" : "Just now";
    if (minutes < 60) return locale === "th" ? `${minutes} นาทีที่แล้ว` : `${minutes} min ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return locale === "th" ? `${hours} ชั่วโมงที่แล้ว` : `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return locale === "th" ? `${days} วันที่แล้ว` : `${days}d ago`;
}

export function Header() {
    const { user, logout } = useAuth();
    const { locale, setLocale, t } = useLanguage();
    const [isProfileOpen, setIsProfileOpen] = useState(false);
    const [isLangOpen, setIsLangOpen] = useState(false);
    const [isNotifOpen, setIsNotifOpen] = useState(false);
    const [notifications, setNotifications] = useState<NotificationLog[]>([]);
    const dropdownRef = useRef<HTMLDivElement>(null);
    const langRef = useRef<HTMLDivElement>(null);
    const notifRef = useRef<HTMLDivElement>(null);

    const unreadCount = notifications.filter(n => !n.is_read).length;

    // Fetch notifications from API
    const fetchNotifications = useCallback(async () => {
        try {
            const data = await notificationApi.list({ limit: 10 });
            setNotifications(data);
        } catch {
            // Keep existing — API may not be connected yet
        }
    }, []);

    useEffect(() => {
        // eslint-disable-next-line react-hooks/set-state-in-effect -- subscribing to external notification API
        void fetchNotifications();
        const interval = setInterval(fetchNotifications, 30000);
        return () => clearInterval(interval);
    }, [fetchNotifications]);

    // Close dropdowns when clicking outside
    useEffect(() => {
        function handleClickOutside(event: MouseEvent) {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setIsProfileOpen(false);
            }
            if (langRef.current && !langRef.current.contains(event.target as Node)) {
                setIsLangOpen(false);
            }
            if (notifRef.current && !notifRef.current.contains(event.target as Node)) {
                setIsNotifOpen(false);
            }
        }
        document.addEventListener("mousedown", handleClickOutside);
        return () => document.removeEventListener("mousedown", handleClickOutside);
    }, []);

    const handleLogout = async () => {
        setIsProfileOpen(false);
        await logout();
    };

    const handleMarkAsRead = async (id: string) => {
        try {
            await notificationApi.markAsRead(id);
            setNotifications(prev => prev.map(n => n.id === id ? { ...n, is_read: true } : n));
        } catch {
            // Ignore
        }
    };

    const notificationTitle = locale === "th" ? "การแจ้งเตือน" : "Notifications";
    const viewAllText = locale === "th" ? "ดูทั้งหมด" : "View all";
    const noNotificationsText = locale === "th" ? "ไม่มีการแจ้งเตือน" : "No notifications";

    const displayName = user?.full_name || "Admin";
    const displayEmail = user?.email || "";
    const initials = displayName.split(" ").map(n => n[0]).join("").slice(0, 2).toUpperCase();

    return (
        <header className="h-16 bg-white border-b border-slate-200 px-8 flex items-center justify-between sticky top-0 z-10">
            <div className="flex-1 max-w-xl">
                <div className="relative group">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 group-focus-within:text-primary transition-colors" />
                    <input
                        type="text"
                        placeholder={t.header.searchPlaceholder}
                        className="w-full bg-slate-50 border-none rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:bg-white transition-all outline-none text-slate-900 placeholder:text-slate-400"
                    />
                </div>
            </div>

            <div className="flex items-center space-x-2">
                {/* Language Switcher */}
                <div className="relative" ref={langRef}>
                    <button
                        onClick={() => setIsLangOpen(!isLangOpen)}
                        className="flex items-center gap-1.5 px-3 py-2 text-slate-500 hover:bg-slate-50 rounded-lg transition-colors text-sm font-medium"
                    >
                        <Languages className="h-4 w-4" />
                        <span className="uppercase">{locale}</span>
                    </button>

                    {isLangOpen && (
                        <div className="absolute right-0 mt-2 w-40 bg-white rounded-xl border border-slate-200 shadow-lg py-1 z-50">
                            <button
                                onClick={() => { setLocale("th"); setIsLangOpen(false); }}
                                className={`flex items-center gap-3 w-full px-4 py-2.5 text-sm transition-colors ${locale === "th"
                                        ? "bg-emerald-50 text-emerald-700"
                                        : "text-slate-700 hover:bg-slate-50"
                                    }`}
                            >
                                <span>TH</span>
                                <span>ไทย</span>
                            </button>
                            <button
                                onClick={() => { setLocale("en"); setIsLangOpen(false); }}
                                className={`flex items-center gap-3 w-full px-4 py-2.5 text-sm transition-colors ${locale === "en"
                                        ? "bg-emerald-50 text-emerald-700"
                                        : "text-slate-700 hover:bg-slate-50"
                                    }`}
                            >
                                <span>EN</span>
                                <span>English</span>
                            </button>
                        </div>
                    )}
                </div>

                {/* Notifications */}
                <div className="relative" ref={notifRef}>
                    <button
                        onClick={() => setIsNotifOpen(!isNotifOpen)}
                        className="p-2 text-slate-500 hover:bg-slate-50 rounded-lg transition-colors relative"
                    >
                        <Bell className="h-5 w-5" />
                        {unreadCount > 0 && (
                            <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center px-1">
                                {unreadCount}
                            </span>
                        )}
                    </button>

                    {isNotifOpen && (
                        <div className="absolute right-0 mt-2 w-96 bg-white rounded-xl border border-slate-200 shadow-lg z-50 overflow-hidden">
                            <div className="px-4 py-3 border-b border-slate-100 flex items-center justify-between">
                                <div className="flex items-center gap-2">
                                    <h3 className="font-semibold text-slate-900">{notificationTitle}</h3>
                                    {unreadCount > 0 && (
                                        <span className="px-2 py-0.5 bg-red-100 text-red-600 text-xs font-medium rounded-full">
                                            {unreadCount}
                                        </span>
                                    )}
                                </div>
                            </div>

                            <div className="max-h-[400px] overflow-y-auto divide-y divide-slate-100">
                                {notifications.length > 0 ? (
                                    notifications.map((notification) => {
                                        const displayType = mapNotificationType(notification.notification_type);
                                        const config = notificationIcons[displayType];
                                        const IconComponent = config.icon;
                                        return (
                                            <div
                                                key={notification.id}
                                                onClick={() => handleMarkAsRead(notification.id)}
                                                className={cn(
                                                    "px-4 py-3 hover:bg-slate-50 cursor-pointer transition-colors",
                                                    !notification.is_read && "bg-blue-50/50"
                                                )}
                                            >
                                                <div className="flex gap-3">
                                                    <div className={cn("p-2 rounded-lg flex-shrink-0", config.bg)}>
                                                        <IconComponent className={cn("h-4 w-4", config.color)} />
                                                    </div>
                                                    <div className="flex-1 min-w-0">
                                                        <div className="flex items-start justify-between gap-2">
                                                            <p className={cn(
                                                                "text-sm text-slate-900",
                                                                !notification.is_read && "font-semibold"
                                                            )}>
                                                                {notification.title}
                                                            </p>
                                                            {!notification.is_read && (
                                                                <span className="w-2 h-2 bg-blue-500 rounded-full flex-shrink-0 mt-1.5"></span>
                                                            )}
                                                        </div>
                                                        <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">
                                                            {notification.body}
                                                        </p>
                                                        <p className="text-xs text-slate-400 mt-1">
                                                            {timeAgo(notification.sent_at, locale)}
                                                        </p>
                                                    </div>
                                                </div>
                                            </div>
                                        );
                                    })
                                ) : (
                                    <div className="py-12 text-center">
                                        <Bell className="h-8 w-8 text-slate-300 mx-auto mb-2" />
                                        <p className="text-sm text-slate-500">{noNotificationsText}</p>
                                    </div>
                                )}
                            </div>

                            <div className="px-4 py-3 border-t border-slate-100 bg-slate-50">
                                <Link href="/activity" className="w-full text-center text-sm text-primary hover:underline font-medium block">
                                    {viewAllText}
                                </Link>
                            </div>
                        </div>
                    )}
                </div>

                <div className="h-8 w-px bg-slate-200 mx-2"></div>

                {/* Profile Dropdown */}
                <div className="relative" ref={dropdownRef}>
                    <button
                        onClick={() => setIsProfileOpen(!isProfileOpen)}
                        className="flex items-center space-x-3 cursor-pointer hover:bg-slate-50 p-2 rounded-lg transition-colors"
                    >
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                            <span className="text-xs font-semibold text-primary">{initials}</span>
                        </div>
                        <span className="text-sm font-medium text-slate-700">{displayName}</span>
                        <ChevronDown className={`h-4 w-4 text-slate-400 transition-transform ${isProfileOpen ? "rotate-180" : ""}`} />
                    </button>

                    {isProfileOpen && (
                        <div className="absolute right-0 mt-2 w-64 bg-white rounded-xl border border-slate-200 shadow-lg py-2 z-50">
                            <div className="px-4 py-3 border-b border-slate-100">
                                <div className="flex items-center space-x-3">
                                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                                        <span className="text-sm font-semibold text-primary">{initials}</span>
                                    </div>
                                    <div>
                                        <p className="text-sm font-semibold text-slate-900">{displayName}</p>
                                        <p className="text-xs text-slate-500">{displayEmail}</p>
                                    </div>
                                </div>
                            </div>

                            <div className="py-2">
                                <Link
                                    href="/profile"
                                    onClick={() => setIsProfileOpen(false)}
                                    className="flex items-center space-x-3 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
                                >
                                    <User className="h-4 w-4 text-slate-400" />
                                    <span>{t.header.profile}</span>
                                </Link>
                                <Link
                                    href="/settings"
                                    onClick={() => setIsProfileOpen(false)}
                                    className="flex items-center space-x-3 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
                                >
                                    <Settings className="h-4 w-4 text-slate-400" />
                                    <span>{t.header.settings}</span>
                                </Link>
                            </div>

                            <div className="border-t border-slate-100 pt-2">
                                <button
                                    onClick={handleLogout}
                                    className="flex items-center space-x-3 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors w-full"
                                >
                                    <LogOut className="h-4 w-4" />
                                    <span>{t.header.logout}</span>
                                </button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </header>
    );
}
