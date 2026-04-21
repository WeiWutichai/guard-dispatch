"use client";

import { useState, useEffect, useCallback } from "react";
import {
  Briefcase,
  Plus,
  Search,
  Calendar,
  Clock,
  MapPin,
  CheckCircle2,
  Circle,
  Filter,
  Loader2,
  AlertCircle,
  X,
  Image as ImageIcon,
  ClipboardList,
  ChevronLeft,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import {
  bookingApi,
  type GuardRequest,
  type Assignment,
  type ProgressReportItem,
} from "@/lib/api";

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
  const [urgencyFilter] = useState<UrgencyFilter>("all");

  // Drawer state — `selectedRequest` drives the whole drawer; `selectedAssignment`
  // switches the drawer into "progress report timeline" mode.
  const [selectedRequest, setSelectedRequest] = useState<GuardRequest | null>(null);
  const [selectedAssignment, setSelectedAssignment] = useState<Assignment | null>(null);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [assignmentsLoading, setAssignmentsLoading] = useState(false);
  const [reports, setReports] = useState<ProgressReportItem[]>([]);
  const [reportsLoading, setReportsLoading] = useState(false);
  const [reportsError, setReportsError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

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

  const openRequestDrawer = useCallback(async (req: GuardRequest) => {
    setSelectedRequest(req);
    setSelectedAssignment(null);
    setAssignments([]);
    setAssignmentsLoading(true);
    try {
      const list = await bookingApi.listAssignments(req.id);
      setAssignments(list);
    } catch {
      setAssignments([]);
    } finally {
      setAssignmentsLoading(false);
    }
  }, []);

  const closeDrawer = useCallback(() => {
    setSelectedRequest(null);
    setSelectedAssignment(null);
    setAssignments([]);
    setReports([]);
    setReportsError(null);
  }, []);

  const openAssignmentProgress = useCallback(async (assignment: Assignment) => {
    setSelectedAssignment(assignment);
    setReports([]);
    setReportsError(null);
    setReportsLoading(true);
    try {
      const list = await bookingApi.listProgressReports(assignment.id);
      setReports(list);
    } catch (e) {
      setReportsError(e instanceof Error ? e.message : String(e));
    } finally {
      setReportsLoading(false);
    }
  }, []);

  const backToAssignments = useCallback(() => {
    setSelectedAssignment(null);
    setReports([]);
    setReportsError(null);
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
        <button
          type="button"
          disabled
          title={locale === "th" ? "ยังไม่เปิดใช้งาน" : "Not available yet"}
          className="inline-flex items-center px-4 py-2 bg-primary/40 text-white rounded-lg font-medium text-sm shadow-sm cursor-not-allowed"
        >
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
            <button
              key={req.id}
              type="button"
              onClick={() => openRequestDrawer(req)}
              className="w-full text-left bg-white rounded-xl border border-slate-200 p-5 hover:shadow-md hover:border-primary/40 transition-all"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-4 flex-1 min-w-0">
                  <div className={cn("p-2 rounded-lg mt-0.5", status.bg)}>
                    <StatusIcon className={cn("h-5 w-5", status.color)} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-3 mb-1">
                      <h3 className="text-base font-semibold text-slate-900 truncate">{req.title}</h3>
                      <span className={cn("px-2 py-0.5 rounded text-xs font-medium", urgency.bg, urgency.color)}>
                        {urgency.label}
                      </span>
                      <span className={cn("px-2 py-0.5 rounded text-xs font-medium", status.bg, status.color)}>
                        {status.label}
                      </span>
                    </div>
                    <p className="text-sm text-slate-500 mb-3 line-clamp-2">{req.description}</p>
                    <div className="flex flex-wrap items-center gap-4 text-sm text-slate-500">
                      <div className="flex items-center">
                        <MapPin className="h-4 w-4 mr-1.5 text-slate-400" />
                        <span className="truncate max-w-[280px]">{req.location_address}</span>
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
                <div className="ml-4 text-xs font-medium text-primary">
                  {locale === "th" ? "ดูรายละเอียด →" : "Details →"}
                </div>
              </div>
            </button>
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

      {/* Request detail drawer — opens on card click, drills into assignments → progress reports */}
      {selectedRequest && (
        <>
          {/* Backdrop */}
          <div
            onClick={closeDrawer}
            className="fixed inset-0 bg-black/40 z-40 animate-in fade-in"
          />
          {/* Drawer */}
          <aside className="fixed right-0 top-0 bottom-0 w-full max-w-2xl bg-white z-50 flex flex-col shadow-2xl animate-in slide-in-from-right">
            {/* Header */}
            <div className="px-6 py-4 border-b border-slate-200 flex items-center justify-between sticky top-0 bg-white z-10">
              <div className="flex items-center gap-3 min-w-0">
                {selectedAssignment && (
                  <button
                    onClick={backToAssignments}
                    className="p-1.5 hover:bg-slate-100 rounded-lg transition-colors"
                    title={locale === "th" ? "กลับ" : "Back"}
                  >
                    <ChevronLeft className="h-5 w-5 text-slate-500" />
                  </button>
                )}
                <div className="min-w-0">
                  <h2 className="text-lg font-bold text-slate-900 truncate">
                    {selectedAssignment
                      ? locale === "th"
                        ? "รายงานความคืบหน้า"
                        : "Progress Reports"
                      : selectedRequest.title}
                  </h2>
                  <p className="text-xs text-slate-500 truncate">
                    {selectedAssignment
                      ? locale === "th"
                        ? "บันทึกชั่วโมงจากเจ้าหน้าที่"
                        : "Hourly guard check-ins"
                      : selectedRequest.location_address}
                  </p>
                </div>
              </div>
              <button
                onClick={closeDrawer}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-500" />
              </button>
            </div>

            {/* Body */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6">
              {!selectedAssignment && (
                <>
                  {/* Request summary */}
                  <section className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
                    <div className="flex gap-2 items-start">
                      <span className="text-slate-400 w-24 flex-shrink-0">
                        {locale === "th" ? "คำอธิบาย" : "Description"}
                      </span>
                      <span className="text-slate-900 flex-1 whitespace-pre-wrap">
                        {selectedRequest.description || "—"}
                      </span>
                    </div>
                    <div className="flex gap-2 items-start">
                      <span className="text-slate-400 w-24 flex-shrink-0">
                        {locale === "th" ? "สถานที่" : "Location"}
                      </span>
                      <span className="text-slate-900 flex-1">
                        {selectedRequest.location_address}
                      </span>
                    </div>
                    <div className="flex gap-2 items-start">
                      <span className="text-slate-400 w-24 flex-shrink-0">
                        {locale === "th" ? "เริ่ม" : "Start"}
                      </span>
                      <span className="text-slate-900 flex-1 font-mono text-xs">
                        {new Date(selectedRequest.scheduled_start).toLocaleString()}
                      </span>
                    </div>
                    <div className="flex gap-2 items-start">
                      <span className="text-slate-400 w-24 flex-shrink-0">
                        {locale === "th" ? "สถานะ" : "Status"}
                      </span>
                      <span
                        className={cn(
                          "px-2 py-0.5 rounded text-xs font-medium",
                          statusConfig[selectedRequest.status]?.bg,
                          statusConfig[selectedRequest.status]?.color
                        )}
                      >
                        {statusConfig[selectedRequest.status]?.label || selectedRequest.status}
                      </span>
                    </div>
                  </section>

                  {/* Assignments list */}
                  <section className="space-y-3">
                    <h3 className="text-sm font-semibold text-slate-700">
                      {locale === "th" ? "เจ้าหน้าที่ที่มอบหมาย" : "Assignments"}{" "}
                      <span className="text-slate-400 font-normal">({assignments.length})</span>
                    </h3>
                    {assignmentsLoading ? (
                      <div className="flex items-center justify-center py-8">
                        <Loader2 className="h-5 w-5 text-primary animate-spin" />
                      </div>
                    ) : assignments.length === 0 ? (
                      <div className="bg-slate-50 rounded-xl p-6 text-center text-sm text-slate-500">
                        {locale === "th" ? "ยังไม่มีการมอบหมาย" : "No assignments yet"}
                      </div>
                    ) : (
                      <div className="space-y-2">
                        {assignments.map((a) => (
                          <button
                            key={a.id}
                            type="button"
                            onClick={() => openAssignmentProgress(a)}
                            className="w-full flex items-center justify-between p-3 bg-white border border-slate-200 rounded-xl hover:border-primary/40 hover:shadow-sm transition-all"
                          >
                            <div className="text-left min-w-0">
                              <div className="font-medium text-sm text-slate-900 font-mono">
                                {a.guard_id.slice(0, 8)}…
                              </div>
                              <div className="flex items-center gap-2 mt-0.5">
                                <span className="text-xs text-slate-500">
                                  {locale === "th" ? "สถานะ:" : "Status:"}
                                </span>
                                <span className="text-xs font-semibold text-slate-700">
                                  {a.status}
                                </span>
                                {a.started_at && (
                                  <span className="text-xs text-slate-400">
                                    · {new Date(a.started_at).toLocaleString()}
                                  </span>
                                )}
                              </div>
                            </div>
                            <span className="inline-flex items-center gap-1 text-xs font-semibold text-primary">
                              <ClipboardList className="h-4 w-4" />
                              {locale === "th" ? "ดูรายงาน" : "Reports"} →
                            </span>
                          </button>
                        ))}
                      </div>
                    )}
                  </section>
                </>
              )}

              {selectedAssignment && (
                <section className="space-y-4">
                  {/* Assignment context */}
                  <div className="bg-slate-50 rounded-xl p-3 text-xs space-y-1">
                    <div>
                      <span className="text-slate-400">
                        {locale === "th" ? "เจ้าหน้าที่:" : "Guard:"}
                      </span>{" "}
                      <span className="font-mono text-slate-900">
                        {selectedAssignment.guard_id.slice(0, 8)}…
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-400">
                        {locale === "th" ? "เริ่มปฏิบัติงาน:" : "Started:"}
                      </span>{" "}
                      <span className="text-slate-900">
                        {selectedAssignment.started_at
                          ? new Date(selectedAssignment.started_at).toLocaleString()
                          : "—"}
                      </span>
                    </div>
                  </div>

                  {reportsError && (
                    <div className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                      <AlertCircle className="h-4 w-4 mt-0.5 flex-shrink-0" />
                      <span className="flex-1">{reportsError}</span>
                    </div>
                  )}

                  {reportsLoading ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="h-6 w-6 text-primary animate-spin" />
                    </div>
                  ) : reports.length === 0 && !reportsError ? (
                    <div className="bg-slate-50 rounded-xl p-8 text-center">
                      <ClipboardList className="h-10 w-10 text-slate-300 mx-auto mb-2" />
                      <p className="text-sm text-slate-500">
                        {locale === "th"
                          ? "ยังไม่มีรายงานความคืบหน้า"
                          : "No progress reports yet"}
                      </p>
                    </div>
                  ) : (
                    <ol className="space-y-3">
                      {reports.map((r) => (
                        <li
                          key={r.id}
                          className="bg-white border border-slate-200 rounded-xl p-4"
                        >
                          <div className="flex items-center justify-between mb-2">
                            <span className="inline-flex items-center gap-2 text-sm font-semibold text-slate-900">
                              <span className="w-7 h-7 rounded-full bg-primary/10 text-primary flex items-center justify-center text-xs font-bold">
                                {r.hour_number}
                              </span>
                              {r.hour_number === 0
                                ? locale === "th"
                                  ? "เริ่มปฏิบัติงาน"
                                  : "Start of shift"
                                : locale === "th"
                                  ? `ชั่วโมงที่ ${r.hour_number}`
                                  : `Hour ${r.hour_number}`}
                            </span>
                            <span className="text-xs text-slate-400 font-mono">
                              {new Date(r.created_at).toLocaleString()}
                            </span>
                          </div>
                          {r.message && (
                            <p className="text-sm text-slate-700 whitespace-pre-wrap mb-3">
                              {r.message}
                            </p>
                          )}
                          {(r.media.length > 0 || r.photo_url) && (
                            <div className="flex flex-wrap gap-2">
                              {r.media.length > 0
                                ? r.media.map((m) => (
                                    <button
                                      key={m.id}
                                      type="button"
                                      onClick={() => setPreviewUrl(m.url)}
                                      className="relative w-24 h-24 rounded-lg overflow-hidden border border-slate-200 hover:border-primary/40 transition-all group"
                                    >
                                      {/* eslint-disable-next-line @next/next/no-img-element */}
                                      <img
                                        src={m.url}
                                        alt="progress"
                                        className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                                      />
                                    </button>
                                  ))
                                : r.photo_url && (
                                    <button
                                      type="button"
                                      onClick={() => setPreviewUrl(r.photo_url!)}
                                      className="relative w-24 h-24 rounded-lg overflow-hidden border border-slate-200 hover:border-primary/40 transition-all group"
                                    >
                                      {/* eslint-disable-next-line @next/next/no-img-element */}
                                      <img
                                        src={r.photo_url}
                                        alt="progress"
                                        className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                                      />
                                    </button>
                                  )}
                            </div>
                          )}
                          {!r.message && r.media.length === 0 && !r.photo_url && (
                            <p className="text-xs text-slate-400 italic">
                              {locale === "th" ? "ไม่มีข้อความหรือรูปภาพ" : "No content"}
                            </p>
                          )}
                        </li>
                      ))}
                    </ol>
                  )}
                </section>
              )}
            </div>
          </aside>
        </>
      )}

      {/* Photo lightbox */}
      {previewUrl && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4"
          onClick={() => setPreviewUrl(null)}
        >
          <div
            className="relative max-w-4xl w-full flex flex-col items-center"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex gap-3 mb-4">
              <a
                href={previewUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white text-sm font-medium backdrop-blur-sm inline-flex items-center gap-2"
              >
                <ImageIcon className="h-4 w-4" />
                {locale === "th" ? "เปิดเต็มจอ" : "Open"}
              </a>
              <button
                onClick={() => setPreviewUrl(null)}
                className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white text-sm font-medium backdrop-blur-sm"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={previewUrl}
              alt="Progress photo"
              className="max-h-[85vh] rounded-lg object-contain"
            />
          </div>
        </div>
      )}
    </div>
  );
}
