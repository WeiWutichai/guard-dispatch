"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Loader2, Phone, PhoneOff, PhoneMissed, Search } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  callsApi,
  type AdminCallItem,
  type CallStatus,
} from "@/lib/api";
import { useLanguage } from "@/components/LanguageProvider";

const STATUS_OPTIONS: { value: CallStatus | "all"; thLabel: string; enLabel: string }[] = [
  { value: "all", thLabel: "ทั้งหมด", enLabel: "All" },
  { value: "connected", thLabel: "คุยกัน", enLabel: "Connected" },
  { value: "accepted", thLabel: "รับสาย", enLabel: "Accepted" },
  { value: "ringing", thLabel: "กำลังโทร", enLabel: "Ringing" },
  { value: "ended", thLabel: "จบแล้ว", enLabel: "Ended" },
  { value: "missed", thLabel: "ไม่รับสาย", enLabel: "Missed" },
  { value: "rejected", thLabel: "ถูกปฏิเสธ", enLabel: "Rejected" },
  { value: "failed", thLabel: "ล้มเหลว", enLabel: "Failed" },
];

function formatDuration(seconds: number | null): string {
  if (seconds === null || seconds === undefined) return "-";
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}m ${s.toString().padStart(2, "0")}s`;
}

function formatDateTime(iso: string, isThai: boolean): string {
  const d = new Date(iso);
  try {
    return d.toLocaleString(isThai ? "th-TH" : "en-US", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

function statusBadge(status: CallStatus, isThai: boolean) {
  const label = STATUS_OPTIONS.find((s) => s.value === status);
  const txt = label ? (isThai ? label.thLabel : label.enLabel) : status;
  const color = (() => {
    switch (status) {
      case "connected":
      case "accepted":
        return "bg-emerald-100 text-emerald-700";
      case "ringing":
      case "initiated":
        return "bg-amber-100 text-amber-700";
      case "ended":
        return "bg-slate-100 text-slate-700";
      case "missed":
        return "bg-orange-100 text-orange-700";
      case "rejected":
        return "bg-red-100 text-red-700";
      case "failed":
        return "bg-red-100 text-red-700";
      default:
        return "bg-slate-100 text-slate-600";
    }
  })();
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold",
        color
      )}
    >
      {txt}
    </span>
  );
}

export default function CallsPage() {
  const { t, locale } = useLanguage();
  const isThai = locale === "th";
  const [calls, setCalls] = useState<AdminCallItem[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<CallStatus | "all">("all");
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");

  useEffect(() => {
    const id = setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => clearTimeout(id);
  }, [search]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await callsApi.list({
        status: status === "all" ? undefined : status,
        search: debouncedSearch || undefined,
        limit: 100,
      });
      setCalls(page.data);
      setTotal(page.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, [status, debouncedSearch]);

  useEffect(() => {
    void load();
  }, [load]);

  const stats = useMemo(() => {
    const s = { connected: 0, missed: 0, rejected: 0, avgDuration: 0 };
    let durTotal = 0;
    let durCount = 0;
    for (const c of calls) {
      if (c.status === "connected" || c.status === "ended") s.connected += 1;
      if (c.status === "missed") s.missed += 1;
      if (c.status === "rejected") s.rejected += 1;
      if (c.duration_seconds != null) {
        durTotal += c.duration_seconds;
        durCount += 1;
      }
    }
    if (durCount > 0) s.avgDuration = Math.round(durTotal / durCount);
    return s;
  }, [calls]);

  return (
    <div className="space-y-6">
      <header className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Phone className="h-6 w-6 text-primary" />
            {t.nav.calls}
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            {isThai
              ? "ประวัติการโทรในแอประหว่างลูกค้าและเจ้าหน้าที่"
              : "In-app call history between customers and guards"}
          </p>
        </div>
      </header>

      {/* Summary cards.
          - "Total" comes from `page.total` (server-side COUNT) so it's
            the system-wide number.
          - The other three are client-side reductions over the rows we
            fetched for the current view, so they're scoped "ในตาราง".
            A future PR can move these to a /admin/calls/summary backend
            endpoint that ignores limit/offset; until then we label them
            so operators don't read them as system-wide KPIs. */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <SummaryCard
          label={isThai ? "ทั้งหมด" : "Total"}
          value={total.toString()}
          tone="slate"
          icon={<Phone className="h-5 w-5" />}
        />
        <SummaryCard
          label={isThai ? "ต่อสายสำเร็จ" : "Connected"}
          value={stats.connected.toString()}
          tone="emerald"
          icon={<Phone className="h-5 w-5" />}
          scopeNote={isThai ? "ในตาราง" : "in current view"}
        />
        <SummaryCard
          label={isThai ? "ไม่รับสาย" : "Missed"}
          value={stats.missed.toString()}
          tone="orange"
          icon={<PhoneMissed className="h-5 w-5" />}
          scopeNote={isThai ? "ในตาราง" : "in current view"}
        />
        <SummaryCard
          label={isThai ? "ระยะเวลาเฉลี่ย" : "Avg Duration"}
          value={formatDuration(stats.avgDuration)}
          tone="slate"
          icon={<PhoneOff className="h-5 w-5" />}
          scopeNote={isThai ? "ในตาราง" : "in current view"}
        />
      </div>

      {/* Filters */}
      <div className="bg-white rounded-2xl border border-slate-200 p-4 space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          {STATUS_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => setStatus(opt.value)}
              className={cn(
                "rounded-full px-3 py-1 text-sm font-medium transition-colors",
                status === opt.value
                  ? "bg-primary text-white"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              )}
            >
              {isThai ? opt.thLabel : opt.enLabel}
            </button>
          ))}
        </div>

        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={
              isThai ? "ค้นหาชื่อผู้โทรหรือผู้รับ..." : "Search caller or callee name..."
            }
            className="w-full pl-9 pr-3 py-2 rounded-lg border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
          />
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center">
            <Loader2 className="h-6 w-6 animate-spin text-primary mx-auto" />
          </div>
        ) : error ? (
          <div className="p-12 text-center text-red-600">
            <p className="text-sm mb-3">{error}</p>
            <button
              onClick={() => void load()}
              className="text-sm text-primary underline"
            >
              {isThai ? "ลองใหม่" : "Retry"}
            </button>
          </div>
        ) : calls.length === 0 ? (
          <div className="p-12 text-center text-slate-500">
            <Phone className="h-10 w-10 mx-auto mb-2 text-slate-300" />
            <p className="text-sm">
              {isThai ? "ยังไม่มีบันทึกการโทร" : "No call logs yet"}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-xs font-semibold text-slate-600 uppercase">
                <tr>
                  <th className="text-left px-4 py-3">{isThai ? "เวลา" : "When"}</th>
                  <th className="text-left px-4 py-3">{isThai ? "ผู้โทร" : "Caller"}</th>
                  <th className="text-left px-4 py-3">{isThai ? "ผู้รับ" : "Callee"}</th>
                  <th className="text-left px-4 py-3">{isThai ? "ประเภท" : "Type"}</th>
                  <th className="text-left px-4 py-3">{isThai ? "สถานะ" : "Status"}</th>
                  <th className="text-left px-4 py-3">{isThai ? "ระยะเวลา" : "Duration"}</th>
                  <th className="text-left px-4 py-3">{isThai ? "เหตุผล" : "Reason"}</th>
                </tr>
              </thead>
              <tbody>
                {calls.map((call) => (
                  <tr
                    key={call.id}
                    className="border-t border-slate-100 hover:bg-slate-50/60"
                  >
                    <td className="px-4 py-3 whitespace-nowrap text-slate-700">
                      {formatDateTime(call.started_at, isThai)}
                    </td>
                    <td className="px-4 py-3 text-slate-900">
                      {call.caller_name || (
                        <span className="text-slate-400 text-xs">
                          {call.caller_id.slice(0, 8)}…
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-slate-900">
                      {call.callee_name || (
                        <span className="text-slate-400 text-xs">
                          {call.callee_id.slice(0, 8)}…
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center gap-1 rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
                        {call.call_type === "audio" ? "🎤" : "📹"} {call.call_type}
                      </span>
                    </td>
                    <td className="px-4 py-3">{statusBadge(call.status, isThai)}</td>
                    <td className="px-4 py-3 text-slate-600">
                      {formatDuration(call.duration_seconds)}
                    </td>
                    <td className="px-4 py-3 text-slate-500 text-xs">
                      {call.end_reason || "-"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function SummaryCard({
  label,
  value,
  tone,
  icon,
  scopeNote,
}: {
  label: string;
  value: string;
  tone: "slate" | "emerald" | "orange" | "red";
  icon: React.ReactNode;
  /** Optional sub-label clarifying the value's scope (e.g. "ในตาราง"
   *  for stats computed client-side over the current page only). */
  scopeNote?: string;
}) {
  const bg = {
    slate: "from-slate-50 to-slate-100 border-slate-200",
    emerald: "from-emerald-50 to-emerald-100 border-emerald-200",
    orange: "from-orange-50 to-orange-100 border-orange-200",
    red: "from-red-50 to-red-100 border-red-200",
  }[tone];
  const fg = {
    slate: "text-slate-700",
    emerald: "text-emerald-700",
    orange: "text-orange-700",
    red: "text-red-700",
  }[tone];
  return (
    <div
      className={cn(
        "rounded-2xl bg-gradient-to-br border p-4",
        bg
      )}
    >
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-slate-600">{label}</span>
        <span className={cn("rounded-lg bg-white/60 p-1.5", fg)}>{icon}</span>
      </div>
      <p className={cn("text-2xl font-bold mt-2", fg)}>{value}</p>
      {scopeNote && (
        <p className="text-[10px] font-medium text-slate-500 mt-1">{scopeNote}</p>
      )}
    </div>
  );
}
