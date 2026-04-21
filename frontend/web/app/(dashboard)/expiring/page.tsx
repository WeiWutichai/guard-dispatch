"use client";

import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  Clock,
  ShieldAlert,
  Loader2,
  ChevronRight,
  FileText,
  Phone,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { expiringDocsApi, type ExpiringDocsItem } from "@/lib/api";

type WindowFilter = 7 | 30 | 90;

const DOC_FIELDS = [
  "id_card_expiry",
  "security_license_expiry",
  "training_cert_expiry",
  "criminal_check_expiry",
  "driver_license_expiry",
] as const;

type DocField = (typeof DOC_FIELDS)[number];

function docLabel(field: DocField, isThai: boolean): string {
  const th: Record<DocField, string> = {
    id_card_expiry: "บัตรประชาชน",
    security_license_expiry: "ใบอนุญาต รปภ.",
    training_cert_expiry: "ใบรับรองการฝึกอบรม",
    criminal_check_expiry: "ประวัติอาชญากรรม",
    driver_license_expiry: "ใบขับขี่",
  };
  const en: Record<DocField, string> = {
    id_card_expiry: "National ID",
    security_license_expiry: "Security license",
    training_cert_expiry: "Training cert",
    criminal_check_expiry: "Criminal check",
    driver_license_expiry: "Driver license",
  };
  return (isThai ? th : en)[field];
}

function daysLabel(days: number, isThai: boolean): string {
  if (days < 0) return isThai ? `หมดอายุแล้ว ${Math.abs(days)} วัน` : `Expired ${Math.abs(days)}d ago`;
  if (days === 0) return isThai ? "หมดอายุวันนี้" : "Expires today";
  if (days === 1) return isThai ? "อีก 1 วัน" : "1 day left";
  return isThai ? `อีก ${days} วัน` : `${days} days left`;
}

function daysTone(days: number): { bg: string; text: string; border: string } {
  if (days < 0) return { bg: "bg-red-100", text: "text-red-700", border: "border-red-300" };
  if (days <= 7) return { bg: "bg-amber-100", text: "text-amber-700", border: "border-amber-300" };
  if (days <= 30) return { bg: "bg-yellow-50", text: "text-yellow-700", border: "border-yellow-200" };
  return { bg: "bg-slate-100", text: "text-slate-600", border: "border-slate-200" };
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("th-TH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default function ExpiringDocsPage() {
  const { locale } = useLanguage();
  const isThai = locale === "th";

  const [windowDays, setWindowDays] = useState<WindowFilter>(30);
  const [data, setData] = useState<ExpiringDocsItem[]>([]);
  const [total, setTotal] = useState(0);
  const [expiredCount, setExpiredCount] = useState(0);
  const [expiringSoonCount, setExpiringSoonCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await expiringDocsApi.list({
        within_days: windowDays,
        limit: 200,
      });
      setData(page.data);
      setTotal(page.total);
      setExpiredCount(page.expired_count);
      setExpiringSoonCount(page.expiring_soon_count);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [windowDays]);

  useEffect(() => {
    load();
  }, [load]);

  const windowOptions: { value: WindowFilter; label: string }[] = [
    { value: 7, label: isThai ? "7 วัน" : "7 days" },
    { value: 30, label: isThai ? "30 วัน" : "30 days" },
    { value: 90, label: isThai ? "90 วัน" : "90 days" },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6">
        <div className="flex items-center gap-3 mb-1">
          <div className="p-2 bg-amber-50 rounded-lg">
            <ShieldAlert className="h-5 w-5 text-amber-600" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">
            {isThai ? "เอกสารใกล้หมดอายุ" : "Expiring Documents"}
          </h1>
        </div>
        <p className="text-sm text-slate-500 ml-11">
          {isThai
            ? "พนักงานที่ได้รับอนุมัติและมีเอกสารกำลังจะหมดอายุ"
            : "Approved guards with documents nearing expiry or already expired"}
        </p>
      </header>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
        <div className="bg-gradient-to-br from-red-50 to-white p-5 rounded-2xl border border-red-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-red-600">
                {isThai ? "หมดอายุแล้ว" : "Already expired"}
              </p>
              <p className="text-3xl font-bold text-red-700 mt-1">{expiredCount}</p>
            </div>
            <div className="p-3 bg-red-100 rounded-xl">
              <AlertTriangle className="h-6 w-6 text-red-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-amber-50 to-white p-5 rounded-2xl border border-amber-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600">
                {isThai ? "หมดอายุใน 30 วัน" : "Expiring in 30 days"}
              </p>
              <p className="text-3xl font-bold text-amber-700 mt-1">{expiringSoonCount}</p>
            </div>
            <div className="p-3 bg-amber-100 rounded-xl">
              <Clock className="h-6 w-6 text-amber-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">
                {isThai ? "ในหน้าต่างที่เลือก" : "In selected window"}
              </p>
              <p className="text-3xl font-bold text-slate-900 mt-1">{total}</p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <FileText className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Window filter */}
      <div className="bg-white rounded-xl border border-slate-200 p-4 mb-4">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-sm text-slate-500">
            {isThai ? "แสดงที่จะหมดอายุใน:" : "Show expiring within:"}
          </span>
          {windowOptions.map((opt) => (
            <button
              key={opt.value}
              onClick={() => setWindowDays(opt.value)}
              className={cn(
                "px-3 py-1.5 rounded-full text-xs font-medium transition-colors",
                windowDays === opt.value
                  ? "bg-emerald-600 text-white"
                  : "bg-slate-100 text-slate-700 hover:bg-slate-200"
              )}
            >
              {opt.label}
            </button>
          ))}
          <span className="text-xs text-slate-400 ml-auto">
            {isThai ? "เรียงตามวันที่ใกล้หมดอายุที่สุดก่อน" : "Sorted by earliest expiry first"}
          </span>
        </div>
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
          <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
        </div>
      )}

      {!loading && data.length === 0 && !error && (
        <div className="p-12 bg-white rounded-xl border border-slate-200 text-center text-slate-500">
          <ShieldAlert className="h-10 w-10 mx-auto mb-3 text-slate-300" />
          <p className="font-medium">
            {isThai ? "ไม่พบเอกสารใกล้หมดอายุ" : "No expiring documents"}
          </p>
          <p className="text-sm text-slate-400 mt-1">
            {isThai
              ? "ทุกคนมีเอกสารครบและยังไม่หมดอายุภายในช่วงนี้"
              : "All guards have valid documents for this window."}
          </p>
        </div>
      )}

      {data.length > 0 && (
        <div className="space-y-3">
          {data.map((row) => {
            const tone = daysTone(row.days_until_expiry);
            const atRiskDocs = DOC_FIELDS.filter((f) => row[f]);
            return (
              <div
                key={row.user_id}
                className={cn(
                  "bg-white border rounded-xl p-4 transition-all hover:shadow-md",
                  tone.border
                )}
              >
                <div className="flex items-start gap-4">
                  {/* Avatar */}
                  <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center text-sm font-bold text-slate-600 flex-shrink-0">
                    {row.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={row.avatar_url}
                        alt=""
                        className="w-12 h-12 rounded-full object-cover"
                      />
                    ) : (
                      row.full_name.slice(0, 2).toUpperCase()
                    )}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-3 flex-wrap mb-1">
                      <h3 className="text-base font-semibold text-slate-900 truncate">
                        {row.full_name}
                      </h3>
                      <span
                        className={cn(
                          "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold",
                          tone.bg,
                          tone.text
                        )}
                      >
                        {daysLabel(row.days_until_expiry, isThai)}
                      </span>
                    </div>
                    <div className="flex items-center gap-3 text-xs text-slate-500 mb-3">
                      <span className="flex items-center gap-1">
                        <Phone className="h-3.5 w-3.5" />
                        {row.phone}
                      </span>
                      <span className="text-slate-400">·</span>
                      <span>
                        {isThai ? "เร็วสุด:" : "Earliest:"}{" "}
                        <span className="font-medium text-slate-700">
                          {formatDate(row.earliest_expiry)}
                        </span>
                      </span>
                    </div>

                    {/* At-risk docs */}
                    <div className="flex flex-wrap gap-2">
                      {atRiskDocs.map((field) => {
                        const date = row[field]!;
                        const d = new Date(date);
                        const today = new Date();
                        today.setHours(0, 0, 0, 0);
                        const diffDays = Math.floor(
                          (d.getTime() - today.getTime()) / 86400000
                        );
                        const t = daysTone(diffDays);
                        return (
                          <div
                            key={field}
                            className={cn(
                              "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs border",
                              t.bg,
                              t.border
                            )}
                          >
                            <FileText className={cn("h-3 w-3", t.text)} />
                            <span className="text-slate-700 font-medium">
                              {docLabel(field, isThai)}
                            </span>
                            <span className={cn("font-semibold", t.text)}>
                              {formatDate(date)}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Link to applicants drawer — same user_id drill-in */}
                  <a
                    href={`/guards`}
                    title={isThai ? "ไปยังหน้าพนักงาน" : "View in Guards"}
                    className="p-2 text-slate-400 hover:text-primary hover:bg-slate-50 rounded-lg transition-colors flex-shrink-0"
                  >
                    <ChevronRight className="h-5 w-5" />
                  </a>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
