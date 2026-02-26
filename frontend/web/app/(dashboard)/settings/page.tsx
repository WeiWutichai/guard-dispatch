"use client";

import { useState } from "react";
import {
  Settings,
  User,
  Bell,
  Shield,
  Palette,
  Globe,
  Key,
  Building,
  Mail,
  Phone,
  Camera,
  Moon,
  Sun,
  Check,
  ChevronRight,
} from "lucide-react";
import { cn } from "@/lib/utils";

type SettingsTab = "profile" | "notifications" | "security" | "appearance" | "company";

const tabs: { id: SettingsTab; label: string; icon: typeof User }[] = [
  { id: "profile", label: "Profile", icon: User },
  { id: "notifications", label: "Notifications", icon: Bell },
  { id: "security", label: "Security", icon: Shield },
  { id: "appearance", label: "Appearance", icon: Palette },
  { id: "company", label: "Company", icon: Building },
];

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState<SettingsTab>("profile");
  const [theme, setTheme] = useState<"light" | "dark" | "system">("light");
  const [notifications, setNotifications] = useState({
    email: true,
    push: true,
    sms: false,
    alerts: true,
    reports: true,
    marketing: false,
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Settings</h1>
        <p className="text-slate-500 mt-1">Manage your account and application preferences</p>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Sidebar */}
        <div className="lg:w-64 flex-shrink-0">
          <div className="bg-white rounded-xl border border-slate-200 p-2">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors",
                  activeTab === tab.id
                    ? "bg-emerald-50 text-emerald-700"
                    : "text-slate-600 hover:bg-slate-50"
                )}
              >
                <tab.icon className={cn("h-5 w-5", activeTab === tab.id ? "text-emerald-600" : "text-slate-400")} />
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 bg-white rounded-xl border border-slate-200 p-6">
          {activeTab === "profile" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Profile Settings</h2>
                <p className="text-sm text-slate-500 mt-1">Update your personal information</p>
              </div>

              {/* Avatar */}
              <div className="flex items-center gap-6 pb-6 border-b border-slate-200">
                <div className="relative">
                  <div className="w-24 h-24 rounded-full bg-primary/10 flex items-center justify-center">
                    <User className="h-10 w-10 text-primary" />
                  </div>
                  <button className="absolute bottom-0 right-0 p-2 bg-white border border-slate-200 rounded-full shadow-sm hover:bg-slate-50 transition-colors">
                    <Camera className="h-4 w-4 text-slate-600" />
                  </button>
                </div>
                <div>
                  <h3 className="font-medium text-slate-900">Profile Photo</h3>
                  <p className="text-sm text-slate-500 mt-0.5">JPG, GIF or PNG. Max size 2MB.</p>
                  <button className="mt-2 text-sm text-primary font-medium hover:underline">
                    Upload new photo
                  </button>
                </div>
              </div>

              {/* Form */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">First Name</label>
                  <input
                    type="text"
                    defaultValue="Admin"
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Last Name</label>
                  <input
                    type="text"
                    defaultValue="User"
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Email Address</label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                    <input
                      type="email"
                      defaultValue="admin@secureguard.com"
                      className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Phone Number</label>
                  <div className="relative">
                    <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                    <input
                      type="tel"
                      defaultValue="+66 81 234 5678"
                      className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                    />
                  </div>
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-slate-700 mb-2">Role</label>
                  <input
                    type="text"
                    defaultValue="System Administrator"
                    disabled
                    className="w-full px-4 py-2 bg-slate-100 border border-slate-200 rounded-lg text-sm text-slate-500 cursor-not-allowed"
                  />
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200 flex justify-end gap-3">
                <button className="px-4 py-2 border border-slate-200 text-slate-600 rounded-lg text-sm font-medium hover:bg-slate-50 transition-colors">
                  Cancel
                </button>
                <button className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-emerald-600 transition-colors">
                  Save Changes
                </button>
              </div>
            </div>
          )}

          {activeTab === "notifications" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Notification Preferences</h2>
                <p className="text-sm text-slate-500 mt-1">Choose how you want to be notified</p>
              </div>

              <div className="space-y-4">
                {[
                  { key: "email", label: "Email Notifications", desc: "Receive updates via email" },
                  { key: "push", label: "Push Notifications", desc: "Browser and mobile notifications" },
                  { key: "sms", label: "SMS Notifications", desc: "Text message alerts for critical events" },
                  { key: "alerts", label: "Security Alerts", desc: "Immediate alerts for security incidents" },
                  { key: "reports", label: "Daily Reports", desc: "Receive daily summary reports" },
                  { key: "marketing", label: "Product Updates", desc: "News about new features and updates" },
                ].map((item) => (
                  <div key={item.key} className="flex items-center justify-between p-4 bg-slate-50 rounded-lg">
                    <div>
                      <p className="font-medium text-slate-900">{item.label}</p>
                      <p className="text-sm text-slate-500">{item.desc}</p>
                    </div>
                    <button
                      onClick={() => setNotifications((prev) => ({ ...prev, [item.key]: !prev[item.key as keyof typeof notifications] }))}
                      className={cn(
                        "relative w-11 h-6 rounded-full transition-colors",
                        notifications[item.key as keyof typeof notifications] ? "bg-primary" : "bg-slate-300"
                      )}
                    >
                      <span
                        className={cn(
                          "absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-transform",
                          notifications[item.key as keyof typeof notifications] ? "translate-x-6" : "translate-x-1"
                        )}
                      />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {activeTab === "security" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Security Settings</h2>
                <p className="text-sm text-slate-500 mt-1">Manage your account security</p>
              </div>

              <div className="space-y-4">
                <div className="p-4 bg-slate-50 rounded-lg">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-white rounded-lg">
                        <Key className="h-5 w-5 text-slate-600" />
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">Password</p>
                        <p className="text-sm text-slate-500">Last changed 30 days ago</p>
                      </div>
                    </div>
                    <button className="text-sm text-primary font-medium hover:underline">
                      Change
                    </button>
                  </div>
                </div>

                <div className="p-4 bg-slate-50 rounded-lg">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-white rounded-lg">
                        <Shield className="h-5 w-5 text-slate-600" />
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">Two-Factor Authentication</p>
                        <p className="text-sm text-slate-500">Add an extra layer of security</p>
                      </div>
                    </div>
                    <span className="px-2 py-1 bg-emerald-50 text-emerald-700 text-xs font-medium rounded-full">
                      Enabled
                    </span>
                  </div>
                </div>

                <div className="p-4 bg-slate-50 rounded-lg">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-white rounded-lg">
                        <Globe className="h-5 w-5 text-slate-600" />
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">Active Sessions</p>
                        <p className="text-sm text-slate-500">Manage your active sessions</p>
                      </div>
                    </div>
                    <button className="text-sm text-primary font-medium hover:underline">
                      View All
                    </button>
                  </div>
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200">
                <button className="text-sm text-red-600 font-medium hover:underline">
                  Log out of all devices
                </button>
              </div>
            </div>
          )}

          {activeTab === "appearance" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Appearance</h2>
                <p className="text-sm text-slate-500 mt-1">Customize how the app looks</p>
              </div>

              <div>
                <h3 className="text-sm font-medium text-slate-700 mb-4">Theme</h3>
                <div className="grid grid-cols-3 gap-4">
                  {[
                    { id: "light", label: "Light", icon: Sun },
                    { id: "dark", label: "Dark", icon: Moon },
                    { id: "system", label: "System", icon: Settings },
                  ].map((option) => (
                    <button
                      key={option.id}
                      onClick={() => setTheme(option.id as typeof theme)}
                      className={cn(
                        "p-4 rounded-xl border-2 transition-all",
                        theme === option.id
                          ? "border-primary bg-emerald-50"
                          : "border-slate-200 hover:border-slate-300"
                      )}
                    >
                      <div className={cn(
                        "w-10 h-10 rounded-lg flex items-center justify-center mx-auto mb-3",
                        theme === option.id ? "bg-primary" : "bg-slate-100"
                      )}>
                        <option.icon className={cn("h-5 w-5", theme === option.id ? "text-white" : "text-slate-500")} />
                      </div>
                      <p className={cn("text-sm font-medium", theme === option.id ? "text-primary" : "text-slate-700")}>
                        {option.label}
                      </p>
                      {theme === option.id && (
                        <div className="mt-2 flex justify-center">
                          <Check className="h-4 w-4 text-primary" />
                        </div>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200">
                <h3 className="text-sm font-medium text-slate-700 mb-4">Accent Color</h3>
                <div className="flex gap-3">
                  {["bg-emerald-500", "bg-blue-500", "bg-purple-500", "bg-amber-500", "bg-red-500"].map((color) => (
                    <button
                      key={color}
                      className={cn(
                        "w-8 h-8 rounded-full transition-transform hover:scale-110",
                        color,
                        color === "bg-emerald-500" && "ring-2 ring-offset-2 ring-emerald-500"
                      )}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}

          {activeTab === "company" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">Company Settings</h2>
                <p className="text-sm text-slate-500 mt-1">Manage your organization details</p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-slate-700 mb-2">Company Name</label>
                  <input
                    type="text"
                    defaultValue="SecureGuard Co., Ltd."
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-slate-700 mb-2">Address</label>
                  <textarea
                    rows={3}
                    defaultValue="123 Security Tower, Sukhumvit Road, Bangkok 10110, Thailand"
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all resize-none"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Tax ID</label>
                  <input
                    type="text"
                    defaultValue="0105562012345"
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Industry</label>
                  <select className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all">
                    <option>Security Services</option>
                    <option>Private Investigation</option>
                    <option>Risk Management</option>
                  </select>
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200 flex justify-end gap-3">
                <button className="px-4 py-2 border border-slate-200 text-slate-600 rounded-lg text-sm font-medium hover:bg-slate-50 transition-colors">
                  Cancel
                </button>
                <button className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-emerald-600 transition-colors">
                  Save Changes
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
