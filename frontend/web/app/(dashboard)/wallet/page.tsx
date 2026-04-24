"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Wallet as WalletIcon,
  DollarSign,
  Clock,
  CheckCircle2,
  Loader2,
  X,
  AlertCircle,
  Receipt,
  Banknote,
  ArrowRight,
  Download,
} from "lucide-react";
import { cn, downloadCsv, exportTimestamp, toCsv } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import {
  walletApi,
  type AdminPaymentItem,
  type WalletSummaryResponse,
} from "@/lib/api";

type WalletTab = "overview" | "refunds" | "payments";
type RefundStatusFilter = "pending" | "processed" | "skipped" | "all";

function formatMoney(n: number | null | undefined): string {
  if (n == null) return "-";
  return `฿${n.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function formatDate(iso: string | null | undefined, locale: "th" | "en"): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "-";
  return d.toLocaleDateString(locale === "th" ? "th-TH" : "en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function refundBadgeStyle(status: string | null): { bg: string; text: string } {
  switch (status) {
    case "pending":
      return { bg: "bg-amber-100", text: "text-amber-700" };
    case "processed":
      return { bg: "bg-emerald-100", text: "text-emerald-700" };
    case "skipped":
      return { bg: "bg-slate-200", text: "text-slate-600" };
    default:
      return { bg: "bg-slate-100", text: "text-slate-500" };
  }
}

export default function WalletPage() {
  const { locale } = useLanguage();

  const [activeTab, setActiveTab] = useState<WalletTab>("overview");
  const [summary, setSummary] = useState<WalletSummaryResponse | null>(null);
  const [summaryLoading, setSummaryLoading] = useState(true);
  const [summaryError, setSummaryError] = useState<string | null>(null);

  const loadSummary = useCallback(async () => {
    try {
      setSummaryLoading(true);
      setSummaryError(null);
      const data = await walletApi.summary();
      setSummary(data);
    } catch (e) {
      setSummaryError(e instanceof Error ? e.message : String(e));
    } finally {
      setSummaryLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSummary();
  }, [loadSummary]);

  // Refunds state
  const [refunds, setRefunds] = useState<AdminPaymentItem[]>([]);
  const [refundsTotal, setRefundsTotal] = useState(0);
  const [refundsLoading, setRefundsLoading] = useState(false);
  const [refundsError, setRefundsError] = useState<string | null>(null);
  const [refundStatusFilter, setRefundStatusFilter] =
    useState<RefundStatusFilter>("pending");
  const [selectedRefund, setSelectedRefund] = useState<AdminPaymentItem | null>(
    null
  );

  const loadRefunds = useCallback(async () => {
    try {
      setRefundsLoading(true);
      setRefundsError(null);
      const page = await walletApi.listRefunds(
        refundStatusFilter === "all"
          ? { limit: 100 }
          : { status: refundStatusFilter, limit: 100 }
      );
      setRefunds(page.data);
      setRefundsTotal(page.total);
    } catch (e) {
      setRefundsError(e instanceof Error ? e.message : String(e));
    } finally {
      setRefundsLoading(false);
    }
  }, [refundStatusFilter]);

  useEffect(() => {
    if (activeTab === "refunds") loadRefunds();
  }, [activeTab, loadRefunds]);

  // Payments state
  const [payments, setPayments] = useState<AdminPaymentItem[]>([]);
  const [paymentsLoading, setPaymentsLoading] = useState(false);
  const [paymentsError, setPaymentsError] = useState<string | null>(null);

  const loadPayments = useCallback(async () => {
    try {
      setPaymentsLoading(true);
      setPaymentsError(null);
      const page = await walletApi.listPayments({
        status: "completed",
        limit: 100,
      });
      setPayments(page.data);
    } catch (e) {
      setPaymentsError(e instanceof Error ? e.message : String(e));
    } finally {
      setPaymentsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === "payments") loadPayments();
  }, [activeTab, loadPayments]);

  const isThai = locale === "th";
  const tabs: { id: WalletTab; label: string }[] = [
    { id: "overview", label: isThai ? "ภาพรวม" : "Overview" },
    { id: "refunds", label: isThai ? "คืนเงิน" : "Refunds" },
    { id: "payments", label: isThai ? "ชำระเงิน" : "Payments" },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <div className="p-2 bg-emerald-50 rounded-lg">
                <WalletIcon className="h-5 w-5 text-emerald-600" />
              </div>
              <h1 className="text-2xl font-bold text-slate-900">
                {isThai ? "กระเป๋าเงิน" : "Wallet"}
              </h1>
            </div>
            <p className="text-sm text-slate-500 ml-11">
              {isThai
                ? "จัดการรายได้ ยอดคืนเงิน และการชำระเงินทั้งหมดในระบบ"
                : "Manage revenue, refunds, and all payments in the system"}
            </p>
          </div>
          {(activeTab === "refunds" || activeTab === "payments") && (
            <button
              onClick={() => {
                const rows = activeTab === "refunds" ? refunds : payments;
                const csv = toCsv(rows as unknown as Record<string, unknown>[], [
                  ["Payment ID", (p) => p.id as string],
                  ["Request ID", (p) => (p.request_id as string | null) ?? ""],
                  ["Customer", (p) => (p.customer_name as string | null) ?? ""],
                  ["Amount", (p) => p.amount as number],
                  ["Final", (p) => (p.final_amount as number | null) ?? ""],
                  ["Refund", (p) => (p.refund_amount as number | null) ?? ""],
                  ["Tip", (p) => (p.tip_amount as number | null) ?? 0],
                  ["Status", (p) => (p.status as string | null) ?? ""],
                  ["Refund Status", (p) => (p.refund_status as string | null) ?? ""],
                  ["Method", (p) => (p.payment_method as string | null) ?? ""],
                  ["Paid At", (p) => (p.paid_at as string | null) ?? ""],
                  ["Created", (p) => (p.created_at as string | null) ?? ""],
                ]);
                downloadCsv(
                  `${activeTab}-${exportTimestamp()}.csv`,
                  csv
                );
              }}
              disabled={
                (activeTab === "refunds" ? refunds : payments).length === 0
              }
              className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-slate-200 bg-white text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Download className="h-4 w-4" />
              Export CSV
            </button>
          )}
        </div>
      </header>

      <div className="bg-white rounded-xl border border-slate-200 mb-6">
        <div className="flex border-b border-slate-200 overflow-x-auto">
          {tabs.map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              className={cn(
                "px-5 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap",
                activeTab === t.id
                  ? "border-emerald-500 text-emerald-700"
                  : "border-transparent text-slate-600 hover:text-slate-900"
              )}
            >
              {t.label}
            </button>
          ))}
        </div>

        {activeTab === "overview" && (
          <OverviewTab
            summary={summary}
            loading={summaryLoading}
            error={summaryError}
            onRefresh={loadSummary}
            onGoToRefunds={() => setActiveTab("refunds")}
            isThai={isThai}
          />
        )}
        {activeTab === "refunds" && (
          <RefundsTab
            items={refunds}
            total={refundsTotal}
            loading={refundsLoading}
            error={refundsError}
            statusFilter={refundStatusFilter}
            onStatusFilterChange={setRefundStatusFilter}
            onRowClick={setSelectedRefund}
            onRefresh={loadRefunds}
            isThai={isThai}
            locale={locale}
          />
        )}
        {activeTab === "payments" && (
          <PaymentsTab
            items={payments}
            loading={paymentsLoading}
            error={paymentsError}
            onRefresh={loadPayments}
            isThai={isThai}
            locale={locale}
          />
        )}
      </div>

      {selectedRefund && (
        <RefundModal
          item={selectedRefund}
          onClose={() => setSelectedRefund(null)}
          onCompleted={() => {
            setSelectedRefund(null);
            loadRefunds();
            loadSummary();
          }}
          isThai={isThai}
          locale={locale}
        />
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Overview Tab
// ---------------------------------------------------------------------------

function OverviewTab(props: {
  summary: WalletSummaryResponse | null;
  loading: boolean;
  error: string | null;
  onRefresh: () => void;
  onGoToRefunds: () => void;
  isThai: boolean;
}) {
  const { summary, loading, error, onRefresh, onGoToRefunds, isThai } = props;

  if (loading && !summary) {
    return (
      <div className="p-12 flex justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
      </div>
    );
  }

  if (error && !summary) {
    return (
      <div className="p-8 text-center">
        <AlertCircle className="h-10 w-10 text-red-500 mx-auto mb-3" />
        <p className="text-red-600 mb-3">
          {isThai ? "โหลดข้อมูลไม่สำเร็จ" : "Failed to load summary"}
        </p>
        <button
          onClick={onRefresh}
          className="px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm hover:bg-emerald-700"
        >
          {isThai ? "ลองใหม่" : "Retry"}
        </button>
      </div>
    );
  }

  const s = summary;
  return (
    <div className="p-6 space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          icon={<DollarSign className="h-5 w-5 text-emerald-600" />}
          iconBg="bg-emerald-50"
          label={isThai ? "รายได้เดือนนี้" : "Monthly revenue"}
          value={formatMoney(s?.monthly_revenue ?? 0)}
          subtext={
            isThai ? "ค่าบริการ + ทิป (สุทธิ)" : "Final price + tips (net)"
          }
        />
        <StatCard
          icon={<Clock className="h-5 w-5 text-amber-600" />}
          iconBg="bg-amber-50"
          label={isThai ? "รอดำเนินการคืนเงิน" : "Pending refunds"}
          value={formatMoney(s?.pending_refunds_total ?? 0)}
          subtext={`${s?.pending_refunds_count ?? 0} ${
            isThai ? "รายการ" : "items"
          }`}
          highlight={Boolean(s && s.pending_refunds_count > 0)}
          onClick={onGoToRefunds}
        />
        <StatCard
          icon={<CheckCircle2 className="h-5 w-5 text-blue-600" />}
          iconBg="bg-blue-50"
          label={isThai ? "โอนคืนแล้วเดือนนี้" : "Refunded this month"}
          value={formatMoney(s?.processed_refunds_total ?? 0)}
          subtext={`${s?.processed_refunds_count ?? 0} ${
            isThai ? "รายการ" : "items"
          }`}
        />
        <StatCard
          icon={<Receipt className="h-5 w-5 text-slate-600" />}
          iconBg="bg-slate-50"
          label={isThai ? "สุทธิหลังคืนเงิน" : "Net after refunds"}
          value={formatMoney(
            (s?.monthly_revenue ?? 0) - (s?.processed_refunds_total ?? 0)
          )}
          subtext={isThai ? "รายได้ที่เก็บจริง" : "Actual retained revenue"}
        />
      </div>

      {s && s.pending_refunds_count > 0 && (
        <button
          onClick={onGoToRefunds}
          className="w-full p-4 bg-amber-50 border border-amber-200 rounded-xl hover:bg-amber-100 transition-colors flex items-center justify-between"
        >
          <div className="flex items-center gap-3 text-left">
            <AlertCircle className="h-5 w-5 text-amber-600" />
            <div>
              <div className="font-semibold text-amber-900">
                {isThai
                  ? `มี ${s.pending_refunds_count} รายการรอโอนคืน รวม ${formatMoney(
                      s.pending_refunds_total
                    )}`
                  : `${s.pending_refunds_count} refunds awaiting transfer (${formatMoney(
                      s.pending_refunds_total
                    )})`}
              </div>
              <div className="text-sm text-amber-700">
                {isThai ? "คลิกเพื่อดำเนินการ" : "Click to process"}
              </div>
            </div>
          </div>
          <ArrowRight className="h-5 w-5 text-amber-700" />
        </button>
      )}
    </div>
  );
}

function StatCard(props: {
  icon: React.ReactNode;
  iconBg: string;
  label: string;
  value: string;
  subtext?: string;
  highlight?: boolean;
  onClick?: () => void;
}) {
  const body = (
    <div
      className={cn(
        "p-5 rounded-xl border bg-white transition-colors",
        props.highlight
          ? "border-amber-300 ring-1 ring-amber-200"
          : "border-slate-200",
        props.onClick && "hover:bg-slate-50 cursor-pointer"
      )}
    >
      <div className="flex items-start justify-between mb-3">
        <div className={cn("p-2 rounded-lg", props.iconBg)}>{props.icon}</div>
      </div>
      <div className="text-xs text-slate-500 mb-1">{props.label}</div>
      <div className="text-2xl font-bold text-slate-900">{props.value}</div>
      {props.subtext && (
        <div className="text-xs text-slate-500 mt-1">{props.subtext}</div>
      )}
    </div>
  );
  return props.onClick ? (
    <button onClick={props.onClick} className="text-left">
      {body}
    </button>
  ) : (
    body
  );
}

// ---------------------------------------------------------------------------
// Refunds Tab
// ---------------------------------------------------------------------------

function RefundsTab(props: {
  items: AdminPaymentItem[];
  total: number;
  loading: boolean;
  error: string | null;
  statusFilter: RefundStatusFilter;
  onStatusFilterChange: (s: RefundStatusFilter) => void;
  onRowClick: (item: AdminPaymentItem) => void;
  onRefresh: () => void;
  isThai: boolean;
  locale: "th" | "en";
}) {
  const {
    items,
    total,
    loading,
    error,
    statusFilter,
    onStatusFilterChange,
    onRowClick,
    onRefresh,
    isThai,
    locale,
  } = props;

  const filters: { id: RefundStatusFilter; label: string }[] = [
    { id: "pending", label: isThai ? "รอดำเนินการ" : "Pending" },
    { id: "processed", label: isThai ? "โอนแล้ว" : "Processed" },
    { id: "skipped", label: isThai ? "ข้าม" : "Skipped" },
    { id: "all", label: isThai ? "ทั้งหมด" : "All" },
  ];

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex gap-2 flex-wrap">
          {filters.map((f) => (
            <button
              key={f.id}
              onClick={() => onStatusFilterChange(f.id)}
              className={cn(
                "px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                statusFilter === f.id
                  ? "bg-emerald-600 text-white"
                  : "bg-slate-100 text-slate-700 hover:bg-slate-200"
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
        <div className="text-sm text-slate-500">
          {isThai ? "ทั้งหมด" : "Total"}:{" "}
          <span className="font-semibold text-slate-900">{total}</span>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
          {error}
          <button
            onClick={onRefresh}
            className="ml-3 underline hover:no-underline"
          >
            {isThai ? "ลองใหม่" : "Retry"}
          </button>
        </div>
      )}

      {loading && items.length === 0 && (
        <div className="p-12 flex justify-center">
          <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
        </div>
      )}

      {!loading && items.length === 0 && !error && (
        <div className="p-12 text-center text-slate-500">
          <Banknote className="h-10 w-10 mx-auto mb-3 text-slate-300" />
          {isThai ? "ไม่มีรายการ" : "No refunds"}
        </div>
      )}

      {items.length > 0 && (
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-200">
                <Th>{isThai ? "วันที่" : "Date"}</Th>
                <Th>{isThai ? "ลูกค้า" : "Customer"}</Th>
                <Th>{isThai ? "เจ้าหน้าที่" : "Guard"}</Th>
                <Th className="text-right">
                  {isThai ? "ราคาเดิม" : "Original"}
                </Th>
                <Th className="text-right">
                  {isThai ? "ราคาจริง" : "Final"}
                </Th>
                <Th className="text-right">
                  {isThai ? "ยอดคืน" : "Refund"}
                </Th>
                <Th className="text-center">{isThai ? "สถานะ" : "Status"}</Th>
                <Th className="text-right"></Th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => {
                const s = refundBadgeStyle(item.refund_status);
                return (
                  <tr
                    key={item.payment_id}
                    onClick={() => onRowClick(item)}
                    className="border-b border-slate-100 hover:bg-slate-50 cursor-pointer"
                  >
                    <Td>{formatDate(item.paid_at, locale)}</Td>
                    <Td>
                      <div className="font-medium text-slate-900">
                        {item.customer_name ?? "-"}
                      </div>
                      <div className="text-xs text-slate-500 truncate max-w-[200px]">
                        {item.service_address}
                      </div>
                    </Td>
                    <Td>{item.guard_name ?? "-"}</Td>
                    <Td className="text-right">
                      {formatMoney(item.original_amount)}
                    </Td>
                    <Td className="text-right">
                      {formatMoney(item.final_amount)}
                    </Td>
                    <Td className="text-right font-bold text-amber-600">
                      {formatMoney(item.refund_amount)}
                    </Td>
                    <Td className="text-center">
                      <span
                        className={cn(
                          "inline-flex px-2 py-0.5 rounded-full text-xs font-semibold",
                          s.bg,
                          s.text
                        )}
                      >
                        {item.refund_status ?? "-"}
                      </span>
                    </Td>
                    <Td className="text-right">
                      <ArrowRight className="h-4 w-4 text-slate-400 inline" />
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Payments Tab (read-only)
// ---------------------------------------------------------------------------

function PaymentsTab(props: {
  items: AdminPaymentItem[];
  loading: boolean;
  error: string | null;
  onRefresh: () => void;
  isThai: boolean;
  locale: "th" | "en";
}) {
  const { items, loading, error, onRefresh, isThai, locale } = props;

  if (loading && items.length === 0) {
    return (
      <div className="p-12 flex justify-center">
        <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
      </div>
    );
  }

  if (error && items.length === 0) {
    return (
      <div className="p-8 text-center">
        <AlertCircle className="h-10 w-10 text-red-500 mx-auto mb-3" />
        <p className="text-red-600 mb-3">{error}</p>
        <button
          onClick={onRefresh}
          className="px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm hover:bg-emerald-700"
        >
          {isThai ? "ลองใหม่" : "Retry"}
        </button>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="p-12 text-center text-slate-500">
        <Receipt className="h-10 w-10 mx-auto mb-3 text-slate-300" />
        {isThai ? "ไม่มีการชำระเงิน" : "No payments"}
      </div>
    );
  }

  return (
    <div className="p-6 overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-slate-200">
            <Th>{isThai ? "วันที่" : "Date"}</Th>
            <Th>{isThai ? "ลูกค้า" : "Customer"}</Th>
            <Th>{isThai ? "เจ้าหน้าที่" : "Guard"}</Th>
            <Th className="text-right">
              {isThai ? "ยอดสุทธิ" : "Net amount"}
            </Th>
            <Th>{isThai ? "วิธีการ" : "Method"}</Th>
            <Th className="text-center">{isThai ? "คืนเงิน" : "Refund"}</Th>
          </tr>
        </thead>
        <tbody>
          {items.map((p) => {
            const net = (p.final_amount ?? p.original_amount) + p.tip_amount;
            const s = refundBadgeStyle(p.refund_status);
            return (
              <tr key={p.payment_id} className="border-b border-slate-100">
                <Td>{formatDate(p.paid_at, locale)}</Td>
                <Td>{p.customer_name ?? "-"}</Td>
                <Td>{p.guard_name ?? "-"}</Td>
                <Td className="text-right font-semibold">{formatMoney(net)}</Td>
                <Td>
                  <span className="text-xs uppercase text-slate-600">
                    {p.payment_method}
                  </span>
                </Td>
                <Td className="text-center">
                  {p.refund_status ? (
                    <span
                      className={cn(
                        "inline-flex px-2 py-0.5 rounded-full text-xs font-semibold",
                        s.bg,
                        s.text
                      )}
                    >
                      {p.refund_status}
                    </span>
                  ) : (
                    <span className="text-slate-300">—</span>
                  )}
                </Td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Refund Process / Skip Modal
// ---------------------------------------------------------------------------

function RefundModal(props: {
  item: AdminPaymentItem;
  onClose: () => void;
  onCompleted: () => void;
  isThai: boolean;
  locale: "th" | "en";
}) {
  const { item, onClose, onCompleted, isThai, locale } = props;
  const [reference, setReference] = useState("");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const readonly = item.refund_status !== "pending";

  const submit = async (action: "process" | "skip") => {
    setSubmitting(true);
    setError(null);
    try {
      await walletApi.processRefund(item.payment_id, {
        action,
        reference: reference.trim() || undefined,
        note: note.trim() || undefined,
      });
      onCompleted();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-in fade-in">
      <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto animate-in zoom-in-95">
        <div className="sticky top-0 bg-white flex items-center justify-between p-5 border-b border-slate-200">
          <h2 className="text-lg font-bold text-slate-900">
            {readonly
              ? isThai
                ? "รายละเอียดการคืนเงิน"
                : "Refund detail"
              : isThai
                ? "ดำเนินการคืนเงิน"
                : "Process refund"}
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-slate-100 rounded-lg"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          <InfoRow
            label={isThai ? "ลูกค้า" : "Customer"}
            value={item.customer_name ?? "-"}
          />
          <InfoRow
            label={isThai ? "เจ้าหน้าที่" : "Guard"}
            value={item.guard_name ?? "-"}
          />
          <InfoRow
            label={isThai ? "สถานที่ปฏิบัติงาน" : "Service location"}
            value={item.service_address}
          />
          <InfoRow
            label={isThai ? "ชั่วโมงที่จอง" : "Booked hours"}
            value={
              item.booked_hours != null
                ? `${item.booked_hours} ${isThai ? "ชม." : "hrs"}`
                : "-"
            }
          />
          <InfoRow
            label={isThai ? "ชั่วโมงที่ปฏิบัติจริง" : "Actual hours"}
            value={
              item.actual_hours_worked != null
                ? `${item.actual_hours_worked} ${isThai ? "ชม." : "hrs"}`
                : "-"
            }
          />

          <div className="bg-slate-50 rounded-xl p-4 space-y-2">
            <MoneyRow
              label={isThai ? "ราคาเดิม" : "Original"}
              value={formatMoney(item.original_amount)}
            />
            {item.final_amount != null && (
              <MoneyRow
                label={isThai ? "ราคาจริง (prorated)" : "Final (prorated)"}
                value={formatMoney(item.final_amount)}
              />
            )}
            <MoneyRow
              label={isThai ? "ยอดคืน" : "Refund owed"}
              value={formatMoney(item.refund_amount)}
              highlight
            />
          </div>

          {readonly && (
            <div className="space-y-2 p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
              <div className="flex justify-between text-sm">
                <span className="text-slate-600">
                  {isThai ? "สถานะ" : "Status"}
                </span>
                <span className="font-semibold text-emerald-700 capitalize">
                  {item.refund_status}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-slate-600">
                  {isThai ? "ดำเนินการเมื่อ" : "Processed at"}
                </span>
                <span className="text-slate-900">
                  {formatDate(item.refund_processed_at, locale)}
                </span>
              </div>
              {item.refund_reference && (
                <div className="flex justify-between text-sm">
                  <span className="text-slate-600">
                    {isThai ? "เลขที่อ้างอิง" : "Reference"}
                  </span>
                  <span className="font-mono text-slate-900">
                    {item.refund_reference}
                  </span>
                </div>
              )}
              {item.refund_processed_by_name && (
                <div className="flex justify-between text-sm">
                  <span className="text-slate-600">
                    {isThai ? "ดำเนินการโดย" : "Processed by"}
                  </span>
                  <span className="text-slate-900">
                    {item.refund_processed_by_name}
                  </span>
                </div>
              )}
            </div>
          )}

          {!readonly && (
            <>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1.5">
                  {isThai
                    ? "เลขที่อ้างอิงการโอน (bank slip)"
                    : "Bank transfer reference"}
                </label>
                <input
                  type="text"
                  value={reference}
                  onChange={(e) => setReference(e.target.value)}
                  maxLength={200}
                  placeholder={
                    isThai
                      ? "เช่น SLIP-2026-001234"
                      : "e.g. SLIP-2026-001234"
                  }
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400"
                />
                <p className="text-xs text-slate-500 mt-1">
                  {isThai
                    ? "จำเป็นเมื่อยืนยันโอนคืนแล้ว"
                    : "Required when confirming transfer"}
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1.5">
                  {isThai ? "หมายเหตุ (ไม่บังคับ)" : "Note (optional)"}
                </label>
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  rows={2}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-200 focus:border-emerald-400"
                />
              </div>

              {error && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                  {error}
                </div>
              )}

              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => submit("skip")}
                  disabled={submitting}
                  className="flex-1 px-4 py-2.5 border border-slate-300 text-slate-700 rounded-lg text-sm font-medium hover:bg-slate-50 disabled:opacity-50"
                >
                  {isThai ? "ข้ามรายการนี้" : "Skip"}
                </button>
                <button
                  onClick={() => submit("process")}
                  disabled={submitting || !reference.trim()}
                  className="flex-1 px-4 py-2.5 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {submitting ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <CheckCircle2 className="h-4 w-4" />
                  )}
                  {isThai ? "ยืนยันโอนคืนแล้ว" : "Confirm transferred"}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function InfoRow(props: { label: string; value: string }) {
  return (
    <div className="flex justify-between items-start gap-3">
      <span className="text-sm text-slate-600">{props.label}</span>
      <span className="text-sm font-medium text-slate-900 text-right max-w-[60%]">
        {props.value}
      </span>
    </div>
  );
}

function MoneyRow(props: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex justify-between items-center",
        props.highlight ? "text-amber-700 font-bold" : "text-slate-700"
      )}
    >
      <span className="text-sm">{props.label}</span>
      <span className="text-sm">{props.value}</span>
    </div>
  );
}

function Th(props: {
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <th
      className={cn(
        "py-3 px-3 text-xs font-semibold text-slate-500 uppercase",
        props.className ?? "text-left"
      )}
    >
      {props.children}
    </th>
  );
}

function Td(props: {
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <td className={cn("py-3 px-3 text-sm text-slate-700", props.className)}>
      {props.children}
    </td>
  );
}
