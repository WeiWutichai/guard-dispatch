"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Activity,
  Search,
  Loader2,
  AlertCircle,
  X,
  Download,
} from "lucide-react";
import { cn, downloadCsv, exportTimestamp, toCsv } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { auditApi, type AuditLogItem } from "@/lib/api";

const ENTITY_FILTERS = [
  "all",
  "auth",
  "booking",
  "chat",
  "notification",
  "tracking",
  "pricing",
  "admin",
] as const;
type EntityFilter = (typeof ENTITY_FILTERS)[number];

function formatDateTime(iso: string, locale: "th" | "en"): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "-";
  return d.toLocaleString(locale === "th" ? "th-TH" : "en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function roleBadge(role: string | null): { bg: string; text: string; label: string } {
  switch (role) {
    case "admin":
      return { bg: "bg-purple-100", text: "text-purple-700", label: "admin" };
    case "guard":
      return { bg: "bg-amber-100", text: "text-amber-700", label: "guard" };
    case "customer":
      return { bg: "bg-blue-100", text: "text-blue-700", label: "customer" };
    default:
      return { bg: "bg-slate-100", text: "text-slate-600", label: "-" };
  }
}

function entityBadge(entity: string): { bg: string; text: string } {
  const palette: Record<string, { bg: string; text: string }> = {
    auth: { bg: "bg-emerald-50", text: "text-emerald-700" },
    booking: { bg: "bg-blue-50", text: "text-blue-700" },
    chat: { bg: "bg-indigo-50", text: "text-indigo-700" },
    notification: { bg: "bg-amber-50", text: "text-amber-700" },
    tracking: { bg: "bg-teal-50", text: "text-teal-700" },
    pricing: { bg: "bg-rose-50", text: "text-rose-700" },
    admin: { bg: "bg-purple-50", text: "text-purple-700" },
  };
  return palette[entity] ?? { bg: "bg-slate-100", text: "text-slate-600" };
}

export default function ActivityPage() {
  const { locale } = useLanguage();
  const isThai = locale === "th";

  const [logs, setLogs] = useState<AuditLogItem[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [entityFilter, setEntityFilter] = useState<EntityFilter>("all");
  const [searchInput, setSearchInput] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [selected, setSelected] = useState<AuditLogItem | null>(null);

  // Debounce search — avoid hammering API on every keystroke
  useEffect(() => {
    const h = setTimeout(() => setDebouncedSearch(searchInput.trim()), 300);
    return () => clearTimeout(h);
  }, [searchInput]);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const page = await auditApi.list({
        search: debouncedSearch || undefined,
        entity_type: entityFilter === "all" ? undefined : entityFilter,
        limit: 200,
      });
      setLogs(page.data);
      setTotal(page.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch, entityFilter]);

  useEffect(() => {
    load();
  }, [load]);

  const filterLabels = useMemo(
    () => ({
      all: isThai ? "ทั้งหมด" : "All",
      auth: "Auth",
      booking: "Booking",
      chat: "Chat",
      notification: "Notification",
      tracking: "Tracking",
      pricing: "Pricing",
      admin: "Admin",
    }),
    [isThai]
  );

  const handleExportCsv = () => {
    const csv = toCsv(logs as unknown as Record<string, unknown>[], [
      ["Time", (r) => (r.created_at as string | null) ?? ""],
      ["User", (r) => (r.user_name as string | null) ?? ""],
      ["Role", (r) => (r.user_role as string | null) ?? ""],
      ["Action", (r) => (r.action as string | null) ?? ""],
      ["Entity", (r) => (r.entity_type as string | null) ?? ""],
      ["Entity ID", (r) => (r.entity_id as string | null) ?? ""],
      ["IP", (r) => (r.ip_address as string | null) ?? ""],
    ]);
    downloadCsv(`activity-${exportTimestamp()}.csv`, csv);
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6 flex items-start justify-between gap-4">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div className="p-2 bg-emerald-50 rounded-lg">
              <Activity className="h-5 w-5 text-emerald-600" />
            </div>
            <h1 className="text-2xl font-bold text-slate-900">
              {isThai ? "บันทึกกิจกรรม" : "Activity Log"}
            </h1>
          </div>
          <p className="text-sm text-slate-500 ml-11">
            {isThai
              ? "บันทึกทุก request ที่เข้าระบบ — user, endpoint, IP, เวลา"
              : "Every request that hits the backend — user, endpoint, IP, timestamp"}
          </p>
        </div>
        <button
          onClick={handleExportCsv}
          disabled={logs.length === 0}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-200 bg-white text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Download className="h-4 w-4" />
          Export CSV
        </button>
      </header>

      <div className="bg-white rounded-xl border border-slate-200 p-4 mb-4 space-y-3">
        <div className="flex gap-3 flex-wrap">
          <div className="flex-1 min-w-[240px] relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 pointer-events-none" />
            <input
              type="text"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              placeholder={
                isThai
                  ? "ค้นหา action เช่น POST /requests"
                  : "Search action e.g. POST /requests"
              }
              className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400"
            />
          </div>
          <div className="text-sm text-slate-500 flex items-center">
            {isThai ? "ทั้งหมด" : "Total"}:{" "}
            <span className="ml-1.5 font-semibold text-slate-900">{total}</span>
          </div>
        </div>

        <div className="flex gap-2 flex-wrap">
          {ENTITY_FILTERS.map((f) => (
            <button
              key={f}
              onClick={() => setEntityFilter(f)}
              className={cn(
                "px-3 py-1.5 rounded-full text-xs font-medium transition-colors",
                entityFilter === f
                  ? "bg-emerald-600 text-white"
                  : "bg-slate-100 text-slate-700 hover:bg-slate-200"
              )}
            >
              {filterLabels[f]}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm mb-4">
          <div className="flex items-start gap-2">
            <AlertCircle className="h-4 w-4 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              {error}
              <button
                onClick={load}
                className="ml-3 underline hover:no-underline"
              >
                {isThai ? "ลองใหม่" : "Retry"}
              </button>
            </div>
          </div>
        </div>
      )}

      {loading && logs.length === 0 && (
        <div className="p-12 flex justify-center">
          <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
        </div>
      )}

      {!loading && logs.length === 0 && !error && (
        <div className="p-12 bg-white rounded-xl border border-slate-200 text-center text-slate-500">
          <Activity className="h-10 w-10 mx-auto mb-3 text-slate-300" />
          {isThai ? "ไม่พบบันทึก" : "No logs found"}
        </div>
      )}

      {logs.length > 0 && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50">
                <tr className="border-b border-slate-200">
                  <Th>{isThai ? "เวลา" : "Time"}</Th>
                  <Th>{isThai ? "ผู้ใช้" : "User"}</Th>
                  <Th>{isThai ? "Role" : "Role"}</Th>
                  <Th>{isThai ? "Action" : "Action"}</Th>
                  <Th>{isThai ? "Entity" : "Entity"}</Th>
                  <Th>IP</Th>
                </tr>
              </thead>
              <tbody>
                {logs.map((row) => {
                  const r = roleBadge(row.user_role);
                  const e = entityBadge(row.entity_type);
                  return (
                    <tr
                      key={row.id}
                      onClick={() => setSelected(row)}
                      className="border-b border-slate-100 hover:bg-slate-50 cursor-pointer"
                    >
                      <Td className="whitespace-nowrap font-mono text-xs">
                        {formatDateTime(row.created_at, locale)}
                      </Td>
                      <Td>
                        <div className="font-medium text-slate-900">
                          {row.user_name ?? (
                            <span className="text-slate-400 italic">
                              {isThai ? "ไม่ระบุ" : "anonymous"}
                            </span>
                          )}
                        </div>
                        {row.user_id && (
                          <div className="text-xs text-slate-500 font-mono truncate max-w-[140px]">
                            {row.user_id.slice(0, 8)}…
                          </div>
                        )}
                      </Td>
                      <Td>
                        <span
                          className={cn(
                            "inline-flex px-2 py-0.5 rounded-full text-xs font-semibold",
                            r.bg,
                            r.text
                          )}
                        >
                          {r.label}
                        </span>
                      </Td>
                      <Td className="font-mono text-xs">{row.action}</Td>
                      <Td>
                        <span
                          className={cn(
                            "inline-flex px-2 py-0.5 rounded-full text-xs font-medium",
                            e.bg,
                            e.text
                          )}
                        >
                          {row.entity_type}
                        </span>
                      </Td>
                      <Td className="font-mono text-xs text-slate-600">
                        {row.ip_address ?? "-"}
                      </Td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {selected && (
        <DetailModal
          log={selected}
          onClose={() => setSelected(null)}
          isThai={isThai}
          locale={locale}
        />
      )}
    </div>
  );
}

function DetailModal(props: {
  log: AuditLogItem;
  onClose: () => void;
  isThai: boolean;
  locale: "th" | "en";
}) {
  const { log, onClose, isThai, locale } = props;
  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-in fade-in">
      <div className="bg-white rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto animate-in zoom-in-95">
        <div className="sticky top-0 bg-white flex items-center justify-between p-5 border-b border-slate-200">
          <div className="flex items-center gap-2">
            <Activity className="h-5 w-5 text-emerald-600" />
            <h2 className="text-lg font-bold text-slate-900">
              {isThai ? "รายละเอียด" : "Detail"}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-slate-100 rounded-lg"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-5 space-y-3">
          <Row label="ID" value={log.id} mono />
          <Row
            label={isThai ? "เวลา" : "Time"}
            value={formatDateTime(log.created_at, locale)}
          />
          <Row
            label={isThai ? "ผู้ใช้" : "User"}
            value={log.user_name ?? (isThai ? "ไม่ระบุ" : "anonymous")}
          />
          {log.user_id && (
            <Row label="User ID" value={log.user_id} mono />
          )}
          <Row
            label={isThai ? "บทบาท" : "Role"}
            value={log.user_role ?? "-"}
          />
          <Row label="Action" value={log.action} mono />
          <Row label="Entity type" value={log.entity_type} />
          {log.entity_id && (
            <Row label="Entity ID" value={log.entity_id} mono />
          )}
          <Row label="IP address" value={log.ip_address ?? "-"} mono />
        </div>
      </div>
    </div>
  );
}

function Row(props: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-start gap-3">
      <div className="w-28 flex-shrink-0 text-xs text-slate-500 pt-1">
        {props.label}
      </div>
      <div
        className={cn(
          "flex-1 text-sm text-slate-900 break-all",
          props.mono && "font-mono text-xs"
        )}
      >
        {props.value}
      </div>
    </div>
  );
}

function Th(props: { children?: React.ReactNode; className?: string }) {
  return (
    <th
      className={cn(
        "py-3 px-4 text-xs font-semibold text-slate-500 uppercase text-left",
        props.className
      )}
    >
      {props.children}
    </th>
  );
}

function Td(props: { children?: React.ReactNode; className?: string }) {
  return (
    <td className={cn("py-3 px-4 text-sm text-slate-700", props.className)}>
      {props.children}
    </td>
  );
}

