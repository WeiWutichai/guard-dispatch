"use client";

import { useState, useEffect } from "react";
import {
  Briefcase,
  Plus,
  Search,
  Calendar,
  Clock,
  MapPin,
  User,
  CheckCircle2,
  Circle,
  MoreHorizontal,
  Filter,
  Loader2,
  AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { bookingApi, type GuardRequest } from "@/lib/api";

type StatusFilter = "all" | "pending" | "assigned" | "in_progress" | "completed" | "cancelled";
type UrgencyFilter = "all" | "low" | "medium" | "high" | "critical";

const statusConfig: Record<string, { label: string; color: string; bg: string; icon: typeof Circle }> = {
  pending: { label: "Pending", color: "text-slate-600", bg: "bg-slate-100", icon: Circle },
  assigned: { label: "Assigned", color: "text-amber-700", bg: "bg-amber-50", icon: Clock },
  in_progress: { label: "In Progress", color: "text-blue-700", bg: "bg-blue-50", icon: Clock },
  completed: { label: "Completed", color: "text-emerald-700", bg: "bg-emerald-50", icon: CheckCircle2 },
  cancelled: { label: "Cancelled", color: "text-red-700", bg: "bg-red-50", icon: AlertCircle },
};

const urgencyConfig: Record<string, { label: string; color: string; bg: string }> = {
  low: { label: "Low", color: "text-blue-700", bg: "bg-blue-50" },
  medium: { label: "Medium", color: "text-amber-700", bg: "bg-amber-50" },
  high: { label: "High", color: "text-red-700", bg: "bg-red-50" },
  critical: { label: "Critical", color: "text-red-800", bg: "bg-red-100" },
};

export default function TasksPage() {
  const { locale } = useLanguage();
  const [requests, setRequests] = useState<GuardRequest[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [urgencyFilter, setUrgencyFilter] = useState<UrgencyFilter>("all");

  useEffect(() => {
    async function fetchData() {
      try {
        const data = await bookingApi.listRequests({ limit: 100 });
        setRequests(data);
      } catch {
        // API may not be connected
      } finally {
        setIsLoading(false);
      }
    }
    fetchData();
  }, []);

  const filteredRequests = requests.filter((req) => {
    const matchesSearch =
      req.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      req.location_address.toLowerCase().includes(searchQuery.toLowerCase()) ||
      req.description.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === "all" || req.status === statusFilter;
    const matchesUrgency = urgencyFilter === "all" || req.urgency === urgencyFilter;
    return matchesSearch && matchesStatus && matchesUrgency;
  });

  const stats = {
    total: requests.length,
    pending: requests.filter(r => r.status === "pending").length,
    inProgress: requests.filter(r => r.status === "in_progress" || r.status === "assigned").length,
    completed: requests.filter(r => r.status === "completed").length,
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">
            {locale === "th" ? "จัดการงาน" : "Task Management"}
          </h1>
          <p className="text-slate-500 mt-1">
            {locale === "th" ? "มอบหมายและติดตามงานรักษาความปลอดภัย" : "Assign and track security tasks across all locations"}
          </p>
        </div>
        <button className="inline-flex items-center px-4 py-2 bg-primary text-white rounded-lg font-medium text-sm hover:bg-emerald-600 transition-colors shadow-sm">
          <Plus className="h-4 w-4 mr-2" />
          {locale === "th" ? "สร้างงาน" : "Create Task"}
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-slate-100 rounded-lg">
              <Briefcase className="h-5 w-5 text-slate-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.total}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "งานทั้งหมด" : "Total Tasks"}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-slate-100 rounded-lg">
              <Circle className="h-5 w-5 text-slate-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.pending}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "รอดำเนินการ" : "Pending"}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-blue-50 rounded-lg">
              <Clock className="h-5 w-5 text-blue-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.inProgress}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "กำลังดำเนินการ" : "In Progress"}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-emerald-50 rounded-lg">
              <CheckCircle2 className="h-5 w-5 text-emerald-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.completed}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "เสร็จสิ้น" : "Completed"}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-slate-200 p-4">
        <div className="flex flex-col lg:flex-row gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input
              type="text"
              placeholder={locale === "th" ? "ค้นหางาน สถานที่..." : "Search tasks, locations..."}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-50 border-none rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:bg-white transition-all outline-none"
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <div className="flex items-center gap-2">
              <Filter className="h-4 w-4 text-slate-400" />
              <span className="text-sm text-slate-500">{locale === "th" ? "สถานะ:" : "Status:"}</span>
              {(["all", "pending", "assigned", "in_progress", "completed", "cancelled"] as const).map((status) => (
                <button
                  key={status}
                  onClick={() => setStatusFilter(status)}
                  className={cn(
                    "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors",
                    statusFilter === status
                      ? "bg-primary text-white"
                      : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                  )}
                >
                  {status === "all" ? (locale === "th" ? "ทั้งหมด" : "All") : statusConfig[status]?.label || status}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Tasks List */}
      <div className="space-y-4">
        {filteredRequests.map((req) => {
          const urgency = urgencyConfig[req.urgency] || urgencyConfig.medium;
          const status = statusConfig[req.status] || statusConfig.pending;
          const StatusIcon = status.icon;
          return (
            <div key={req.id} className="bg-white rounded-xl border border-slate-200 p-5 hover:shadow-md transition-shadow">
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-4 flex-1">
                  <div className={cn("p-2 rounded-lg mt-0.5", status.bg)}>
                    <StatusIcon className={cn("h-5 w-5", status.color)} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-3 mb-1">
                      <h3 className="text-base font-semibold text-slate-900">{req.title}</h3>
                      <span className={cn("px-2 py-0.5 rounded text-xs font-medium", urgency.bg, urgency.color)}>
                        {urgency.label}
                      </span>
                      <span className={cn("px-2 py-0.5 rounded text-xs font-medium", status.bg, status.color)}>
                        {status.label}
                      </span>
                    </div>
                    <p className="text-sm text-slate-500 mb-3">{req.description}</p>
                    <div className="flex flex-wrap items-center gap-4 text-sm text-slate-500">
                      <div className="flex items-center">
                        <MapPin className="h-4 w-4 mr-1.5 text-slate-400" />
                        {req.location_address}
                      </div>
                      <div className="flex items-center">
                        <Calendar className="h-4 w-4 mr-1.5 text-slate-400" />
                        {new Date(req.scheduled_start).toLocaleDateString()}
                      </div>
                      <div className="flex items-center">
                        <Clock className="h-4 w-4 mr-1.5 text-slate-400" />
                        {new Date(req.scheduled_start).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                      </div>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2 ml-4">
                  <button className="p-2 hover:bg-slate-100 rounded-lg transition-colors">
                    <MoreHorizontal className="h-4 w-4 text-slate-400" />
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {filteredRequests.length === 0 && (
          <div className="bg-white rounded-xl border border-slate-200 py-12 text-center">
            <Briefcase className="h-12 w-12 text-slate-300 mx-auto mb-4" />
            <p className="text-slate-500 font-medium">
              {locale === "th" ? "ไม่พบงาน" : "No tasks found"}
            </p>
            <p className="text-slate-400 text-sm mt-1">
              {locale === "th" ? "ลองปรับตัวกรองใหม่" : "Try adjusting your search or filters"}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
