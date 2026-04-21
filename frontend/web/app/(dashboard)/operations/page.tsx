"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Activity,
  AlertTriangle,
  Clock,
  Loader2,
  MapPin,
  Phone,
  RefreshCw,
  Wifi,
  WifiOff,
  Navigation,
  ClipboardList,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { activeOpsApi, type AdminActiveOpItem } from "@/lib/api";

type StatusFilter =
  | "all"
  | "pending_acceptance"
  | "accepted"
  | "en_route"
  | "arrived"
  | "pending_completion";

function statusLabel(status: string, isThai: boolean): string {
  const th: Record<string, string> = {
    pending_acceptance: "รอเจ้าหน้าที่ตอบรับ",
    accepted: "ตอบรับแล้ว",
    en_route: "กำลังเดินทาง",
    arrived: "ถึงที่หมายแล้ว",
    pending_completion: "รอลูกค้าตรวจสอบ",
  };
  const en: Record<string, string> = {
    pending_acceptance: "Awaiting acceptance",
    accepted: "Accepted",
    en_route: "En route",
    arrived: "Arrived",
    pending_completion: "Pending review",
  };
  return (isThai ? th : en)[status] ?? status;
}

function statusTone(status: string): { bg: string; text: string } {
  switch (status) {
    case "pending_acceptance":
      return { bg: "bg-slate-100", text: "text-slate-700" };
    case "accepted":
      return { bg: "bg-amber-100", text: "text-amber-700" };
    case "en_route":
      return { bg: "bg-blue-100", text: "text-blue-700" };
    case "arrived":
      return { bg: "bg-emerald-100", text: "text-emerald-700" };
    case "pending_completion":
      return { bg: "bg-orange-100", text: "text-orange-700" };
    default:
      return { bg: "bg-slate-100", text: "text-slate-600" };
  }
}

function minutesAgo(iso: string | null): number | null {
  if (!iso) return null;
  return Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Compute three boolean warning flags so the UI can badge rows.
 *  Must match the backend counter logic (within 1-minute clock skew). */
function computeFlags(row: AdminActiveOpItem, nowMs: number) {
  const scheduledStartMs = new Date(row.scheduled_start).getTime();
  const lateThresholdMs = scheduledStartMs + 5 * 60 * 1000;
  const lateNoAccept =
    row.status === "pending_acceptance" && nowMs > lateThresholdMs;
  const lateToStart =
    (row.status === "accepted" || row.status === "en_route") &&
    nowMs > lateThresholdMs;

  let overdue = false;
  if (row.started_at && row.booked_hours != null) {
    const expectedEndMs =
      new Date(row.started_at).getTime() + row.booked_hours * 3600 * 1000;
    overdue = nowMs > expectedEndMs && row.status !== "pending_completion";
  }

  // GPS freshness — last ping in the last 5 minutes = online
  const gpsAgeMin = minutesAgo(row.gps_recorded_at);
  const gpsStale = gpsAgeMin != null && gpsAgeMin > 5;
  const gpsFresh = gpsAgeMin != null && gpsAgeMin <= 5 && row.guard_is_online;

  return { lateNoAccept, lateToStart, overdue, gpsStale, gpsFresh, gpsAgeMin };
}

export default function ActiveOperationsPage() {
  const { locale } = useLanguage();
  const isThai = locale === "th";

  const [data, setData] = useState<AdminActiveOpItem[]>([]);
  const [total, setTotal] = useState(0);
  const [awaitingAcceptance, setAwaitingAcceptance] = useState(0);
  const [lateToStart, setLateToStart] = useState(0);
  const [overdue, setOverdue] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [nowMs, setNowMs] = useState(Date.now());

  const load = useCallback(async () => {
    setError(null);
    try {
      const page = await activeOpsApi.list();
      setData(page.data);
      setTotal(page.total);
      setAwaitingAcceptance(page.awaiting_acceptance);
      setLateToStart(page.late_to_start);
      setOverdue(page.overdue);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    // Refresh every 15 seconds so "late" and GPS age badges stay accurate.
    const t = setInterval(load, 15_000);
    return () => clearInterval(t);
  }, [load]);

  // Tick every 30s so the "X min ago" and live-countdown numbers update
  // without a full refetch.
  useEffect(() => {
    const t = setInterval(() => setNowMs(Date.now()), 30_000);
    return () => clearInterval(t);
  }, []);

  const filtered =
    statusFilter === "all"
      ? data
      : data.filter((r) => r.status === statusFilter);

  const statusOptions: { value: StatusFilter; label: string }[] = [
    { value: "all", label: isThai ? "ทั้งหมด" : "All" },
    { value: "pending_acceptance", label: isThai ? "รอตอบรับ" : "Awaiting" },
    { value: "accepted", label: isThai ? "ตอบรับแล้ว" : "Accepted" },
    { value: "en_route", label: isThai ? "เดินทาง" : "En route" },
    { value: "arrived", label: isThai ? "ถึงแล้ว" : "Arrived" },
    { value: "pending_completion", label: isThai ? "รอตรวจสอบ" : "Pending review" },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6 flex items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div className="p-2 bg-blue-50 rounded-lg">
              <Activity className="h-5 w-5 text-blue-600" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900">
              {isThai ? "การปฏิบัติการสด" : "Active Operations"}
            </h1>
          </div>
          <p className="text-sm text-slate-500 ml-11">
            {isThai
              ? "งานที่กำลังดำเนินการอยู่ทั้งหมด — รีเฟรชอัตโนมัติทุก 15 วินาที"
              : "All jobs currently in flight — refreshes every 15 seconds"}
          </p>
        </div>
        <button
          onClick={load}
          className="inline-flex items-center gap-2 px-3 py-2 bg-white border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors"
        >
          <RefreshCw className="h-4 w-4" />
          {isThai ? "รีเฟรช" : "Refresh"}
        </button>
      </header>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4 mb-6">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">
                {isThai ? "กำลังปฏิบัติการ" : "In flight"}
              </p>
              <p className="text-3xl font-bold text-slate-900 mt-1">{total}</p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Activity className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">
                {isThai ? "รอตอบรับ (เลยเวลา)" : "Awaiting (late)"}
              </p>
              <p className="text-3xl font-bold text-slate-700 mt-1">
                {awaitingAcceptance}
              </p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Clock className="h-6 w-6 text-slate-500" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-amber-50 to-white p-5 rounded-2xl border border-amber-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600">
                {isThai ? "มาสาย" : "Late to start"}
              </p>
              <p className="text-3xl font-bold text-amber-700 mt-1">{lateToStart}</p>
            </div>
            <div className="p-3 bg-amber-100 rounded-xl">
              <AlertTriangle className="h-6 w-6 text-amber-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-red-50 to-white p-5 rounded-2xl border border-red-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-red-600">
                {isThai ? "เกินเวลา" : "Overdue"}
              </p>
              <p className="text-3xl font-bold text-red-700 mt-1">{overdue}</p>
            </div>
            <div className="p-3 bg-red-100 rounded-xl">
              <AlertTriangle className="h-6 w-6 text-red-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Status filter */}
      <div className="bg-white rounded-xl border border-slate-200 p-4 mb-4 flex items-center gap-2 flex-wrap">
        {statusOptions.map((opt) => (
          <button
            key={opt.value}
            onClick={() => setStatusFilter(opt.value)}
            className={cn(
              "px-3 py-1.5 rounded-full text-xs font-medium transition-colors",
              statusFilter === opt.value
                ? "bg-blue-600 text-white"
                : "bg-slate-100 text-slate-700 hover:bg-slate-200"
            )}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm mb-4">
          <div className="flex items-start gap-2">
            <AlertTriangle className="h-4 w-4 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              {error}
              <button onClick={load} className="ml-3 underline hover:no-underline">
                {isThai ? "ลองใหม่" : "Retry"}
              </button>
            </div>
          </div>
        </div>
      )}

      {loading && data.length === 0 && (
        <div className="p-12 flex justify-center">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </div>
      )}

      {!loading && filtered.length === 0 && !error && (
        <div className="p-12 bg-white rounded-xl border border-slate-200 text-center text-slate-500">
          <Activity className="h-10 w-10 mx-auto mb-3 text-slate-300" />
          <p className="font-medium">
            {isThai ? "ไม่มีงานที่กำลังปฏิบัติการ" : "No active operations"}
          </p>
        </div>
      )}

      {filtered.length > 0 && (
        <div className="space-y-3">
          {filtered.map((row) => {
            const flags = computeFlags(row, nowMs);
            const tone = statusTone(row.status);
            const highlight =
              flags.overdue || flags.lateNoAccept || flags.lateToStart
                ? "border-amber-300"
                : "border-slate-200";
            return (
              <div
                key={row.assignment_id}
                className={cn(
                  "bg-white border rounded-xl p-4 transition-all hover:shadow-md",
                  highlight
                )}
              >
                <div className="flex items-start gap-4">
                  {/* Guard avatar */}
                  <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center text-sm font-bold text-slate-600 flex-shrink-0 relative">
                    {row.guard_avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={row.guard_avatar_url}
                        alt=""
                        className="w-12 h-12 rounded-full object-cover"
                      />
                    ) : (
                      (row.guard_name ?? "?").slice(0, 2).toUpperCase()
                    )}
                    {/* GPS freshness dot */}
                    {flags.gpsFresh && (
                      <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-emerald-500 border-2 border-white" />
                    )}
                    {flags.gpsStale && (
                      <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-amber-500 border-2 border-white" />
                    )}
                    {!row.gps_recorded_at && (
                      <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-slate-300 border-2 border-white" />
                    )}
                  </div>

                  {/* Main info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-3 flex-wrap mb-1">
                      <h3 className="text-base font-semibold text-slate-900 truncate">
                        {row.guard_name ?? (
                          <span className="italic text-slate-400">
                            {isThai ? "ไม่ระบุ" : "unknown"}
                          </span>
                        )}
                      </h3>
                      <span
                        className={cn(
                          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
                          tone.bg,
                          tone.text
                        )}
                      >
                        {statusLabel(row.status, isThai)}
                      </span>
                      {flags.lateNoAccept && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-semibold bg-slate-200 text-slate-800">
                          <Clock className="h-3 w-3" />
                          {isThai ? "ยังไม่ตอบรับ" : "No response"}
                        </span>
                      )}
                      {flags.lateToStart && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-semibold bg-amber-200 text-amber-800">
                          <AlertTriangle className="h-3 w-3" />
                          {isThai ? "มาสาย" : "Late"}
                        </span>
                      )}
                      {flags.overdue && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-semibold bg-red-200 text-red-800">
                          <AlertTriangle className="h-3 w-3" />
                          {isThai ? "เกินเวลา" : "Overdue"}
                        </span>
                      )}
                    </div>

                    <div className="flex items-center gap-3 text-xs text-slate-500 mb-2 flex-wrap">
                      {row.guard_phone && (
                        <span className="flex items-center gap-1">
                          <Phone className="h-3.5 w-3.5" />
                          {row.guard_phone}
                        </span>
                      )}
                      <span>·</span>
                      <span>
                        {isThai ? "ลูกค้า:" : "Customer:"}{" "}
                        <span className="font-medium text-slate-700">
                          {row.customer_name ?? "—"}
                        </span>
                      </span>
                    </div>

                    <div className="flex items-start gap-2 text-sm text-slate-600 mb-2">
                      <MapPin className="h-4 w-4 mt-0.5 text-slate-400 flex-shrink-0" />
                      <span className="flex-1 truncate">{row.address}</span>
                    </div>

                    {/* Status / timing line */}
                    <div className="flex items-center gap-3 text-xs text-slate-500 flex-wrap">
                      <span>
                        {isThai ? "นัด:" : "Scheduled:"}{" "}
                        <span className="font-medium text-slate-700">
                          {formatTime(row.scheduled_start)}
                        </span>
                      </span>
                      {row.started_at && (
                        <>
                          <span>·</span>
                          <span>
                            {isThai ? "เริ่ม:" : "Started:"}{" "}
                            <span className="font-medium text-slate-700">
                              {formatTime(row.started_at)}
                            </span>
                          </span>
                        </>
                      )}
                      {row.booked_hours != null && (
                        <>
                          <span>·</span>
                          <span>
                            {row.booked_hours}{" "}
                            {isThai ? "ชั่วโมง" : "hrs"}
                          </span>
                        </>
                      )}
                    </div>

                    {/* Progress reports */}
                    <div className="flex items-center gap-3 mt-2 text-xs text-slate-500">
                      <span className="inline-flex items-center gap-1">
                        <ClipboardList className="h-3.5 w-3.5" />
                        {row.progress_reports_count}{" "}
                        {isThai ? "รายงาน" : "reports"}
                        {row.latest_hour_reported != null && (
                          <span className="text-slate-400">
                            {" "}
                            · {isThai ? "ล่าสุด ชม." : "latest h"}
                            {row.latest_hour_reported}
                          </span>
                        )}
                      </span>
                      {flags.gpsAgeMin != null && (
                        <span className="inline-flex items-center gap-1">
                          {flags.gpsFresh ? (
                            <Wifi className="h-3.5 w-3.5 text-emerald-500" />
                          ) : (
                            <WifiOff className="h-3.5 w-3.5 text-amber-500" />
                          )}
                          GPS{" "}
                          <span
                            className={cn(
                              flags.gpsFresh ? "text-emerald-600" : "text-amber-600"
                            )}
                          >
                            {flags.gpsAgeMin < 1
                              ? isThai
                                ? "เมื่อสักครู่"
                                : "just now"
                              : `${flags.gpsAgeMin} ${isThai ? "นาที" : "min"}`}
                          </span>
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Map link */}
                  {row.guard_lat != null && row.guard_lng != null && (
                    <a
                      href={`https://www.google.com/maps?q=${row.guard_lat},${row.guard_lng}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      title={isThai ? "เปิดใน Google Maps" : "Open in Google Maps"}
                      className="p-2 text-slate-400 hover:text-primary hover:bg-slate-50 rounded-lg transition-colors flex-shrink-0"
                    >
                      <Navigation className="h-5 w-5" />
                    </a>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
