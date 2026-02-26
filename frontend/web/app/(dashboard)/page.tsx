"use client";

import { useState, useEffect } from "react";
import {
  Users,
  CheckCircle2,
  TrendingUp,
  Activity,
  Star,
  Award,
  Loader2,
} from "lucide-react";
import { useLanguage } from "@/components/LanguageProvider";
import { bookingApi, type GuardRequest } from "@/lib/api";

export default function Dashboard() {
  const { t, locale } = useLanguage();
  const [requests, setRequests] = useState<GuardRequest[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const data = await bookingApi.listRequests({ limit: 100 });
        setRequests(data);
      } catch {
        // API may not be connected yet — use empty state
      } finally {
        setIsLoading(false);
      }
    }
    fetchData();
  }, []);

  // Compute stats from real data (or show 0 if no data)
  const pendingCount = requests.filter(r => r.status === "pending").length;
  const inProgressCount = requests.filter(r => r.status === "in_progress" || r.status === "assigned").length;
  const completedCount = requests.filter(r => r.status === "completed").length;
  const totalCount = requests.length;

  const stats = [
    { name: t.dashboard.activeGuards, value: String(inProgressCount), change: "", icon: Users, color: "text-emerald-600", bg: "bg-emerald-50" },
    { name: t.dashboard.liveTasks, value: String(pendingCount + inProgressCount), change: "", icon: Activity, color: "text-blue-600", bg: "bg-blue-50" },
    { name: t.dashboard.completedToday, value: String(completedCount), change: "", icon: CheckCircle2, color: "text-purple-600", bg: "bg-purple-50" },
    { name: t.dashboard.totalRevenue, value: String(totalCount), change: locale === "th" ? "คำขอทั้งหมด" : "total requests", icon: TrendingUp, color: "text-orange-600", bg: "bg-orange-50" },
  ];

  // Recent requests for display
  const recentRequests = requests.slice(0, 5);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">{t.dashboard.title}</h1>
        <p className="text-slate-500 mt-1">{t.dashboard.subtitle}</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat) => (
          <div key={stat.name} className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between mb-4">
              <div className={`${stat.bg} p-2 rounded-lg`}>
                <stat.icon className={`h-6 w-6 ${stat.color}`} />
              </div>
              {stat.change && (
                <span className="text-sm font-medium text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">
                  {stat.change}
                </span>
              )}
            </div>
            <p className="text-sm font-medium text-slate-500">{stat.name}</p>
            <p className="text-2xl font-bold text-slate-900 mt-1">{stat.value}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Recent Requests */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-6 border-b border-slate-200">
            <h2 className="text-lg font-bold text-slate-900">
              {locale === "th" ? "คำขอล่าสุด" : "Recent Requests"}
            </h2>
          </div>
          <div className="divide-y divide-slate-100">
            {recentRequests.length > 0 ? recentRequests.map((req) => (
              <div key={req.id} className="p-4 flex items-center gap-4 hover:bg-slate-50 transition-colors">
                <div className={`p-2 rounded-lg ${
                  req.status === "completed" ? "bg-emerald-50" :
                  req.status === "in_progress" ? "bg-blue-50" :
                  req.status === "assigned" ? "bg-amber-50" :
                  req.status === "cancelled" ? "bg-red-50" :
                  "bg-slate-100"
                }`}>
                  <Activity className={`h-4 w-4 ${
                    req.status === "completed" ? "text-emerald-600" :
                    req.status === "in_progress" ? "text-blue-600" :
                    req.status === "assigned" ? "text-amber-600" :
                    req.status === "cancelled" ? "text-red-600" :
                    "text-slate-500"
                  }`} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-slate-900 truncate">{req.title}</p>
                  <p className="text-xs text-slate-500">{req.location_address}</p>
                </div>
                <span className={`text-xs font-medium px-2 py-1 rounded-full ${
                  req.status === "completed" ? "bg-emerald-50 text-emerald-700" :
                  req.status === "in_progress" ? "bg-blue-50 text-blue-700" :
                  req.status === "assigned" ? "bg-amber-50 text-amber-700" :
                  req.status === "cancelled" ? "bg-red-50 text-red-700" :
                  "bg-slate-100 text-slate-600"
                }`}>
                  {req.status.replace("_", " ")}
                </span>
              </div>
            )) : (
              <div className="p-8 text-center">
                <p className="text-slate-500 text-sm">
                  {locale === "th" ? "ยังไม่มีคำขอ" : "No requests yet"}
                </p>
              </div>
            )}
          </div>
        </div>

        {/* Quick Stats Panel */}
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-6 border-b border-slate-200 flex items-center gap-3">
            <Award className="h-5 w-5 text-amber-500" />
            <h2 className="text-lg font-bold text-slate-900">
              {locale === "th" ? "สรุปสถานะ" : "Status Summary"}
            </h2>
          </div>
          <div className="divide-y divide-slate-100">
            {[
              { label: locale === "th" ? "รอดำเนินการ" : "Pending", count: pendingCount, color: "text-slate-600" },
              { label: locale === "th" ? "มอบหมายแล้ว" : "Assigned", count: requests.filter(r => r.status === "assigned").length, color: "text-amber-600" },
              { label: locale === "th" ? "กำลังดำเนินการ" : "In Progress", count: requests.filter(r => r.status === "in_progress").length, color: "text-blue-600" },
              { label: locale === "th" ? "เสร็จสิ้น" : "Completed", count: completedCount, color: "text-emerald-600" },
              { label: locale === "th" ? "ยกเลิก" : "Cancelled", count: requests.filter(r => r.status === "cancelled").length, color: "text-red-600" },
            ].map((item) => (
              <div key={item.label} className="p-4 flex items-center justify-between hover:bg-slate-50 transition-colors">
                <p className="text-sm font-medium text-slate-700">{item.label}</p>
                <span className={`text-lg font-bold ${item.color}`}>{item.count}</span>
              </div>
            ))}
          </div>
          <div className="p-4 bg-slate-50 border-t border-slate-100 text-center">
            <span className="text-sm text-slate-500">
              {locale === "th" ? `ทั้งหมด ${totalCount} คำขอ` : `${totalCount} total requests`}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
