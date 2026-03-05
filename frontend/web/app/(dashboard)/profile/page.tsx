"use client";

import { useState, useEffect } from "react";
import {
    User,
    Mail,
    Phone,
    Camera,
    Shield,
    Key,
    Bell,
    Clock,
    CheckCircle2,
    AlertCircle,
    Save,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { useAuth } from "@/components/AuthProvider";
import { authApi } from "@/lib/api";

export default function ProfilePage() {
    const { t } = useLanguage();
    const { user, refreshUser } = useAuth();
    const [isEditing, setIsEditing] = useState(false);

    const nameParts = (user?.full_name || "Admin User").split(" ");
    const [formData, setFormData] = useState({
        firstName: nameParts[0] || "Admin",
        lastName: nameParts.slice(1).join(" ") || "User",
        email: user?.email || "",
        phone: user?.phone || "",
        position: user?.role === "admin" ? "System Administrator" : user?.role || "",
        department: "Security Operations",
    });

    // Sync form data when user changes
    useEffect(() => {
        if (user) {
            const parts = user.full_name.split(" ");
            // eslint-disable-next-line react-hooks/set-state-in-effect -- sync form with user profile from API
            queueMicrotask(() => setFormData({
                firstName: parts[0] || "",
                lastName: parts.slice(1).join(" ") || "",
                email: user.email,
                phone: user.phone,
                position: user.role === "admin" ? "System Administrator" : user.role || "",
                department: "Security Operations",
            }));
        }
    }, [user]);

    const [passwords, setPasswords] = useState({
        current: "",
        new: "",
        confirm: "",
    });

    const activityLog = [
        { action: t.profile.login, time: t.profile.today + " 09:30", ip: "192.168.1.100", status: "success" },
        { action: t.profile.editEmployee, time: t.profile.today + " 10:15", ip: "192.168.1.100", status: "success" },
        { action: t.profile.login, time: t.profile.yesterday + " 14:22", ip: "192.168.1.105", status: "success" },
        { action: t.profile.passwordChanged, time: "3 " + t.profile.daysAgo, ip: "192.168.1.100", status: "success" },
        { action: t.profile.loginAttempt, time: "5 " + t.profile.daysAgo, ip: "103.45.67.89", status: "failed" },
    ];

    const handleSave = async () => {
        try {
            await authApi.updateProfile({
                full_name: `${formData.firstName} ${formData.lastName}`.trim(),
                phone: formData.phone,
            });
            await refreshUser();
            setIsEditing(false);
        } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : "Save failed";
            alert(msg);
        }
    };

    const handleChangePassword = () => {
        if (passwords.new !== passwords.confirm) {
            alert(t.profile.passwordMismatch);
            return;
        }
        if (passwords.new.length < 8) {
            alert(t.profile.passwordTooShort);
            return;
        }
        alert(t.profile.passwordChangeSuccess);
        setPasswords({ current: "", new: "", confirm: "" });
    };

    return (
        <div className="space-y-6 max-w-5xl mx-auto">
            <div>
                <h1 className="text-2xl font-bold text-slate-900">{t.profile.title}</h1>
                <p className="text-slate-500 mt-1">{t.profile.subtitle}</p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Profile Card */}
                <div className="lg:col-span-2 space-y-6">
                    {/* Basic Info */}
                    <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
                        <div className="p-6 border-b border-slate-200 flex items-center justify-between">
                            <div>
                                <h2 className="text-lg font-semibold text-slate-900">{t.profile.personalInfo}</h2>
                                <p className="text-sm text-slate-500">{t.profile.editProfile}</p>
                            </div>
                            {!isEditing ? (
                                <button
                                    onClick={() => setIsEditing(true)}
                                    className="px-4 py-2 text-sm font-medium text-primary hover:bg-emerald-50 rounded-lg transition-colors"
                                >
                                    {t.common.edit}
                                </button>
                            ) : (
                                <div className="flex gap-2">
                                    <button
                                        onClick={() => setIsEditing(false)}
                                        className="px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 rounded-lg transition-colors"
                                    >
                                        {t.common.cancel}
                                    </button>
                                    <button
                                        onClick={handleSave}
                                        className="px-4 py-2 text-sm font-medium text-white bg-primary hover:bg-emerald-600 rounded-lg transition-colors flex items-center gap-2"
                                    >
                                        <Save className="h-4 w-4" />
                                        {t.common.save}
                                    </button>
                                </div>
                            )}
                        </div>

                        <div className="p-6">
                            {/* Avatar Section */}
                            <div className="flex items-center gap-6 pb-6 border-b border-slate-100">
                                <div className="relative">
                                    <div className="w-24 h-24 rounded-full bg-primary/10 flex items-center justify-center">
                                        <User className="h-10 w-10 text-primary" />
                                    </div>
                                    <button className="absolute bottom-0 right-0 p-2 bg-white border border-slate-200 rounded-full shadow-sm hover:bg-slate-50 transition-colors">
                                        <Camera className="h-4 w-4 text-slate-600" />
                                    </button>
                                </div>
                                <div>
                                    <h3 className="font-semibold text-slate-900">{t.profile.profilePhoto}</h3>
                                    <p className="text-sm text-slate-500 mt-0.5">{t.profile.photoRequirements}</p>
                                    <button className="mt-2 text-sm text-primary font-medium hover:underline">
                                        {t.profile.uploadNew}
                                    </button>
                                </div>
                            </div>

                            {/* Form */}
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-6">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.firstName}</label>
                                    <input
                                        type="text"
                                        value={formData.firstName}
                                        onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                                        disabled={!isEditing}
                                        className={cn(
                                            "w-full px-4 py-2.5 rounded-lg text-sm transition-all outline-none text-slate-900",
                                            isEditing
                                                ? "bg-white border border-slate-200 focus:ring-2 focus:ring-primary/20 focus:border-primary"
                                                : "bg-slate-50 border border-transparent"
                                        )}
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.lastName}</label>
                                    <input
                                        type="text"
                                        value={formData.lastName}
                                        onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                                        disabled={!isEditing}
                                        className={cn(
                                            "w-full px-4 py-2.5 rounded-lg text-sm transition-all outline-none text-slate-900",
                                            isEditing
                                                ? "bg-white border border-slate-200 focus:ring-2 focus:ring-primary/20 focus:border-primary"
                                                : "bg-slate-50 border border-transparent"
                                        )}
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.email}</label>
                                    <div className="relative">
                                        <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                                        <input
                                            type="email"
                                            value={formData.email}
                                            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                            disabled={!isEditing}
                                            className={cn(
                                                "w-full pl-10 pr-4 py-2.5 rounded-lg text-sm transition-all outline-none text-slate-900",
                                                isEditing
                                                    ? "bg-white border border-slate-200 focus:ring-2 focus:ring-primary/20 focus:border-primary"
                                                    : "bg-slate-50 border border-transparent"
                                            )}
                                        />
                                    </div>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.phone}</label>
                                    <div className="relative">
                                        <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                                        <input
                                            type="tel"
                                            value={formData.phone}
                                            onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                                            disabled={!isEditing}
                                            className={cn(
                                                "w-full pl-10 pr-4 py-2.5 rounded-lg text-sm transition-all outline-none text-slate-900",
                                                isEditing
                                                    ? "bg-white border border-slate-200 focus:ring-2 focus:ring-primary/20 focus:border-primary"
                                                    : "bg-slate-50 border border-transparent"
                                            )}
                                        />
                                    </div>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.position}</label>
                                    <input
                                        type="text"
                                        value={formData.position}
                                        disabled
                                        className="w-full px-4 py-2.5 bg-slate-100 border border-transparent rounded-lg text-sm text-slate-500 cursor-not-allowed"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.department}</label>
                                    <input
                                        type="text"
                                        value={formData.department}
                                        disabled
                                        className="w-full px-4 py-2.5 bg-slate-100 border border-transparent rounded-lg text-sm text-slate-500 cursor-not-allowed"
                                    />
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Change Password */}
                    <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
                        <div className="p-6 border-b border-slate-200">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-amber-50 rounded-lg">
                                    <Key className="h-5 w-5 text-amber-600" />
                                </div>
                                <div>
                                    <h2 className="text-lg font-semibold text-slate-900">{t.profile.changePassword}</h2>
                                    <p className="text-sm text-slate-500">{t.profile.updatePasswordSecurity}</p>
                                </div>
                            </div>
                        </div>
                        <div className="p-6 space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.currentPassword}</label>
                                <input
                                    type="password"
                                    value={passwords.current}
                                    onChange={(e) => setPasswords({ ...passwords, current: e.target.value })}
                                    className="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                                    placeholder="••••••••"
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.newPassword}</label>
                                <input
                                    type="password"
                                    value={passwords.new}
                                    onChange={(e) => setPasswords({ ...passwords, new: e.target.value })}
                                    className="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                                    placeholder="••••••••"
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">{t.profile.confirmPassword}</label>
                                <input
                                    type="password"
                                    value={passwords.confirm}
                                    onChange={(e) => setPasswords({ ...passwords, confirm: e.target.value })}
                                    className="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                                    placeholder="••••••••"
                                />
                            </div>
                            <button
                                onClick={handleChangePassword}
                                className="px-4 py-2.5 bg-amber-500 hover:bg-amber-600 text-white rounded-lg text-sm font-medium transition-colors"
                            >
                                {t.profile.changePassword}
                            </button>
                        </div>
                    </div>
                </div>

                {/* Sidebar */}
                <div className="space-y-6">
                    {/* Security Status */}
                    <div className="bg-white rounded-xl border border-slate-200 p-6">
                        <div className="flex items-center gap-3 mb-4">
                            <div className="p-2 bg-emerald-50 rounded-lg">
                                <Shield className="h-5 w-5 text-emerald-600" />
                            </div>
                            <h3 className="font-semibold text-slate-900">{t.profile.securityStatus}</h3>
                        </div>
                        <div className="space-y-3">
                            <div className="flex items-center justify-between p-3 bg-emerald-50 rounded-lg">
                                <div className="flex items-center gap-2">
                                    <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                                    <span className="text-sm text-emerald-700">{t.profile.twoFactorAuth}</span>
                                </div>
                                <span className="text-xs text-emerald-600 font-medium">{t.profile.enabled}</span>
                            </div>
                            <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                                <div className="flex items-center gap-2">
                                    <Clock className="h-4 w-4 text-slate-500" />
                                    <span className="text-sm text-slate-600">{t.profile.lastPasswordChange}</span>
                                </div>
                                <span className="text-xs text-slate-500">30 {t.profile.daysAgo}</span>
                            </div>
                            <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                                <div className="flex items-center gap-2">
                                    <Bell className="h-4 w-4 text-slate-500" />
                                    <span className="text-sm text-slate-600">{t.profile.loginNotifications}</span>
                                </div>
                                <span className="text-xs text-emerald-600 font-medium">{t.profile.enabled}</span>
                            </div>
                        </div>
                    </div>

                    {/* Activity Log */}
                    <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
                        <div className="p-4 border-b border-slate-200">
                            <h3 className="font-semibold text-slate-900">{t.profile.recentActivity}</h3>
                        </div>
                        <div className="divide-y divide-slate-100">
                            {activityLog.map((log, index) => (
                                <div key={index} className="p-4">
                                    <div className="flex items-start gap-3">
                                        <div className={cn(
                                            "p-1.5 rounded-full mt-0.5",
                                            log.status === "success" ? "bg-emerald-50" : "bg-red-50"
                                        )}>
                                            {log.status === "success" ? (
                                                <CheckCircle2 className="h-3 w-3 text-emerald-600" />
                                            ) : (
                                                <AlertCircle className="h-3 w-3 text-red-600" />
                                            )}
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <p className="text-sm font-medium text-slate-900">{log.action}</p>
                                            <div className="flex items-center gap-2 mt-0.5">
                                                <span className="text-xs text-slate-500">{log.time}</span>
                                                <span className="text-xs text-slate-400">•</span>
                                                <span className="text-xs text-slate-400">{log.ip}</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                        <div className="p-4 bg-slate-50 text-center">
                            <button className="text-sm text-primary font-medium hover:underline">
                                {t.common.viewAll}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
