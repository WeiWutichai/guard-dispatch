"use client";

import { useState } from "react";
import {
  Search,
  Wallet,
  ChevronDown,
  MoreHorizontal,
  Eye,
  Plus,
  Minus,
  Download,
  Clock,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Settings,
  History,
  Users,
  X,
  ArrowUpRight,
  ArrowDownRight,
  Gift,
  Briefcase,
  CreditCard,
  Save,
  Filter,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

type TransactionType = "job_income" | "withdrawal" | "bonus" | "deduction";
type WithdrawalStatus = "pending" | "approved" | "rejected";
type WalletStatus = "active" | "suspended";

interface Transaction {
  id: string;
  date: string;
  type: TransactionType;
  amount: number;
  description: string;
}

interface Guard {
  id: string;
  name: string;
  withdrawable: number;
  pending: number;
  bankAccount: string;
  bankName: string;
  lastTransaction: string;
  status: WalletStatus;
  transactions: Transaction[];
}

interface WithdrawalRequest {
  id: string;
  guardId: string;
  guardName: string;
  amount: number;
  requestDate: string;
  reason: string;
  status: WithdrawalStatus;
}

interface AdminAction {
  id: string;
  adminName: string;
  actionType: string;
  guardName: string;
  amount: number;
  reason: string;
  date: string;
}

const initialGuards: Guard[] = [
  {
    id: "G001",
    name: "สมชาย วงศ์ใหญ่",
    withdrawable: 2500,
    pending: 800,
    bankAccount: "xxx-x-x1234-x",
    bankName: "กสิกรไทย",
    lastTransaction: "2024-01-15",
    status: "active",
    transactions: [
      { id: "T001", date: "2024-01-15", type: "job_income", amount: 1200, description: "รักษาความปลอดภัยคอนโด ABC" },
      { id: "T002", date: "2024-01-14", type: "withdrawal", amount: -500, description: "ถอนเงินไปบัญชี xxx-567" },
      { id: "T003", date: "2024-01-13", type: "bonus", amount: 200, description: "โบนัสประจำเดือน" },
    ],
  },
  {
    id: "G002",
    name: "วันชัย สมใส",
    withdrawable: 1800,
    pending: 450,
    bankAccount: "xxx-x-x5678-x",
    bankName: "กรุงเทพ",
    lastTransaction: "2024-01-14",
    status: "active",
    transactions: [
      { id: "T004", date: "2024-01-14", type: "job_income", amount: 900, description: "รักษาความปลอดภัยห้าง XYZ" },
      { id: "T005", date: "2024-01-12", type: "withdrawal", amount: -300, description: "ถอนเงินไปบัญชี xxx-890" },
    ],
  },
  {
    id: "G003",
    name: "อนุชา สมบูรณ์",
    withdrawable: 3200,
    pending: 1200,
    bankAccount: "xxx-x-x9012-x",
    bankName: "ไทยพาณิชย์",
    lastTransaction: "2024-01-16",
    status: "active",
    transactions: [
      { id: "T006", date: "2024-01-16", type: "job_income", amount: 1500, description: "รักษาความปลอดภัยออฟฟิศ DEF" },
      { id: "T007", date: "2024-01-15", type: "bonus", amount: 300, description: "โบนัสพิเศษ" },
    ],
  },
  {
    id: "G004",
    name: "ประยุทธ์ ใจดี",
    withdrawable: 500,
    pending: 200,
    bankAccount: "xxx-x-x3456-x",
    bankName: "กรุงไทย",
    lastTransaction: "2024-01-10",
    status: "suspended",
    transactions: [
      { id: "T008", date: "2024-01-10", type: "deduction", amount: -100, description: "หักค่าเสียหาย" },
    ],
  },
];

const initialWithdrawalRequests: WithdrawalRequest[] = [
  { id: "W001", guardId: "G001", guardName: "สมชาย วงศ์ใหญ่", amount: 1000, requestDate: "2024-01-16", reason: "ถอนเงินเดือน", status: "pending" },
  { id: "W002", guardId: "G002", guardName: "วันชัย สมใส", amount: 500, requestDate: "2024-01-15", reason: "ถอนเงินฉุกเฉิน", status: "pending" },
  { id: "W003", guardId: "G003", guardName: "อนุชา สมบูรณ์", amount: 800, requestDate: "2024-01-14", reason: "ถอนเงินปกติ", status: "pending" },
];

const initialAdminActions: AdminAction[] = [
  { id: "A001", adminName: "ผู้ดูแลระบบ A", actionType: "add_money", guardName: "สมชาย วงศ์ใหญ่", amount: 200, reason: "โบนัสประจำเดือน", date: "2024-01-15" },
  { id: "A002", adminName: "ผู้ดูแลระบบ B", actionType: "approve_withdrawal", guardName: "วันชัย สมใส", amount: 300, reason: "ถอนเงินปกติ", date: "2024-01-14" },
  { id: "A003", adminName: "ผู้ดูแลระบบ A", actionType: "deduct_money", guardName: "ประยุทธ์ ใจดี", amount: 100, reason: "หักค่าเสียหาย", date: "2024-01-13" },
  { id: "A004", adminName: "ผู้ดูแลระบบ B", actionType: "reject_withdrawal", guardName: "อนุชา สมบูรณ์", amount: 500, reason: "ยอดเงินไม่เพียงพอ", date: "2024-01-12" },
];

export default function WalletPage() {
  const { locale } = useLanguage();
  const [guards, setGuards] = useState<Guard[]>(initialGuards);
  const [withdrawalRequests, setWithdrawalRequests] = useState<WithdrawalRequest[]>(initialWithdrawalRequests);
  const [adminActions, setAdminActions] = useState<AdminAction[]>(initialAdminActions);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeTab, setActiveTab] = useState<"overview" | "requests" | "history" | "settings">("overview");

  // Modal states
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [selectedGuard, setSelectedGuard] = useState<Guard | null>(null);
  const [addMoneyModalOpen, setAddMoneyModalOpen] = useState(false);
  const [deductMoneyModalOpen, setDeductMoneyModalOpen] = useState(false);
  const [moneyAmount, setMoneyAmount] = useState("");
  const [moneyReason, setMoneyReason] = useState("");

  // Settings state
  const [settings, setSettings] = useState({
    pendingDuration: 24,
    minWithdrawal: 100,
    freeWithdrawalsPerDay: 1,
    additionalFee: 10,
  });

  const filteredGuards = guards.filter((guard) =>
    guard.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const stats = {
    totalWithdrawable: guards.reduce((sum, g) => sum + g.withdrawable, 0),
    totalPending: guards.reduce((sum, g) => sum + g.pending, 0),
    pendingRequests: withdrawalRequests.filter(r => r.status === "pending").length,
    activeGuards: guards.filter(g => g.status === "active").length,
  };

  const handleOpenDetail = (guard: Guard) => {
    setSelectedGuard(guard);
    setDetailModalOpen(true);
  };

  const handleApproveWithdrawal = (requestId: string) => {
    setWithdrawalRequests(requests =>
      requests.map(r => r.id === requestId ? { ...r, status: "approved" as WithdrawalStatus } : r)
    );
    // Add admin action
    const request = withdrawalRequests.find(r => r.id === requestId);
    if (request) {
      setAdminActions(prev => [{
        id: `A${Date.now()}`,
        adminName: "Admin User",
        actionType: "approve_withdrawal",
        guardName: request.guardName,
        amount: request.amount,
        reason: request.reason,
        date: new Date().toISOString().split('T')[0],
      }, ...prev]);
    }
  };

  const handleRejectWithdrawal = (requestId: string) => {
    setWithdrawalRequests(requests =>
      requests.map(r => r.id === requestId ? { ...r, status: "rejected" as WithdrawalStatus } : r)
    );
    const request = withdrawalRequests.find(r => r.id === requestId);
    if (request) {
      setAdminActions([{
        id: `A${Date.now()}`,
        adminName: "Admin User",
        actionType: "reject_withdrawal",
        guardName: request.guardName,
        amount: request.amount,
        reason: "คำขอถูกปฏิเสธ",
        date: new Date().toISOString().split('T')[0],
      }, ...adminActions]);
    }
  };

  const handleAddMoney = () => {
    if (selectedGuard && moneyAmount && parseFloat(moneyAmount) > 0) {
      const amount = parseFloat(moneyAmount);
      setGuards(guards.map(g =>
        g.id === selectedGuard.id
          ? {
            ...g,
            withdrawable: g.withdrawable + amount,
            transactions: [{
              id: `T${Date.now()}`,
              date: new Date().toISOString().split('T')[0],
              type: "bonus" as TransactionType,
              amount: amount,
              description: moneyReason || "เพิ่มเงิน",
            }, ...g.transactions]
          }
          : g
      ));
      setAdminActions([{
        id: `A${Date.now()}`,
        adminName: "Admin User",
        actionType: "add_money",
        guardName: selectedGuard.name,
        amount: amount,
        reason: moneyReason || "เพิ่มเงิน",
        date: new Date().toISOString().split('T')[0],
      }, ...adminActions]);
      setAddMoneyModalOpen(false);
      setMoneyAmount("");
      setMoneyReason("");
    }
  };

  const handleDeductMoney = () => {
    if (selectedGuard && moneyAmount && parseFloat(moneyAmount) > 0) {
      const amount = parseFloat(moneyAmount);
      setGuards(guards.map(g =>
        g.id === selectedGuard.id
          ? {
            ...g,
            withdrawable: Math.max(0, g.withdrawable - amount),
            transactions: [{
              id: `T${Date.now()}`,
              date: new Date().toISOString().split('T')[0],
              type: "deduction" as TransactionType,
              amount: -amount,
              description: moneyReason || "หักเงิน",
            }, ...g.transactions]
          }
          : g
      ));
      setAdminActions([{
        id: `A${Date.now()}`,
        adminName: "Admin User",
        actionType: "deduct_money",
        guardName: selectedGuard.name,
        amount: amount,
        reason: moneyReason || "หักเงิน",
        date: new Date().toISOString().split('T')[0],
      }, ...adminActions]);
      setDeductMoneyModalOpen(false);
      setMoneyAmount("");
      setMoneyReason("");
    }
  };

  const getTransactionIcon = (type: TransactionType) => {
    switch (type) {
      case "job_income": return <Briefcase className="h-4 w-4 text-emerald-500" />;
      case "withdrawal": return <ArrowUpRight className="h-4 w-4 text-red-500" />;
      case "bonus": return <Gift className="h-4 w-4 text-purple-500" />;
      case "deduction": return <ArrowDownRight className="h-4 w-4 text-orange-500" />;
    }
  };

  const getTransactionLabel = (type: TransactionType) => {
    const labels = {
      job_income: locale === "th" ? "รายได้จากงาน" : "Job Income",
      withdrawal: locale === "th" ? "ถอนเงิน" : "Withdrawal",
      bonus: locale === "th" ? "โบนัส" : "Bonus",
      deduction: locale === "th" ? "หักเงิน" : "Deduction",
    };
    return labels[type];
  };

  const getActionLabel = (actionType: string) => {
    const labels: Record<string, string> = {
      add_money: locale === "th" ? "เพิ่มเงิน" : "Add Money",
      deduct_money: locale === "th" ? "หักเงิน" : "Deduct Money",
      approve_withdrawal: locale === "th" ? "อนุมัติการถอน" : "Approve Withdrawal",
      reject_withdrawal: locale === "th" ? "ปฏิเสธการถอน" : "Reject Withdrawal",
    };
    return labels[actionType] || actionType;
  };

  const tabs = [
    { id: "overview" as const, label: locale === "th" ? "ภาพรวมกระเป๋าเงิน" : "Wallet Overview", icon: Wallet },
    { id: "requests" as const, label: locale === "th" ? "คำขอถอนเงิน" : "Withdrawal Requests", icon: Clock },
    { id: "history" as const, label: locale === "th" ? "ประวัติการดำเนินการ" : "Admin History", icon: History },
    { id: "settings" as const, label: locale === "th" ? "ตั้งค่าระบบ" : "Settings", icon: Settings },
  ];

  const pendingRequestsCount = withdrawalRequests.filter(r => r.status === "pending").length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">
          {locale === "th" ? "จัดการกระเป๋าเงิน" : "Wallet Management"}
        </h1>
        <p className="text-slate-500 mt-1">
          {locale === "th"
            ? "จัดการการเงินและการถอนเงินของเจ้าหน้าที่รักษาความปลอดภัย"
            : "Manage finances and withdrawals for security guards"}
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-2xl border border-emerald-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600">{locale === "th" ? "ยอดถอนได้รวม" : "Total Withdrawable"}</p>
              <p className="text-3xl font-bold text-emerald-700 mt-1">฿{stats.totalWithdrawable.toLocaleString()}</p>
            </div>
            <div className="p-3 bg-emerald-100 rounded-xl">
              <Wallet className="h-6 w-6 text-emerald-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-amber-50 to-white p-5 rounded-2xl border border-amber-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600">{locale === "th" ? "ยอด Pending รวม" : "Total Pending"}</p>
              <p className="text-3xl font-bold text-amber-700 mt-1">฿{stats.totalPending.toLocaleString()}</p>
            </div>
            <div className="p-3 bg-amber-100 rounded-xl">
              <Clock className="h-6 w-6 text-amber-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-blue-50 to-white p-5 rounded-2xl border border-blue-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-blue-600">{locale === "th" ? "คำขอรออนุมัติ" : "Pending Requests"}</p>
              <p className="text-3xl font-bold text-blue-700 mt-1">{stats.pendingRequests}</p>
            </div>
            <div className="p-3 bg-blue-100 rounded-xl">
              <AlertCircle className="h-6 w-6 text-blue-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">{locale === "th" ? "เจ้าหน้าที่ Active" : "Active Guards"}</p>
              <p className="text-3xl font-bold text-slate-900 mt-1">{stats.activeGuards}</p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Users className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm">
        <div className="flex border-b border-slate-200 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={cn(
                "flex items-center gap-2 px-6 py-4 text-sm font-medium whitespace-nowrap transition-colors relative",
                activeTab === tab.id
                  ? "text-primary border-b-2 border-primary bg-primary/5"
                  : "text-slate-500 hover:text-slate-700 hover:bg-slate-50"
              )}
            >
              <tab.icon className="h-4 w-4" />
              {tab.label}
              {tab.id === "requests" && pendingRequestsCount > 0 && (
                <span className="ml-1.5 px-2 py-0.5 text-xs font-bold bg-red-500 text-white rounded-full">
                  {pendingRequestsCount}
                </span>
              )}
            </button>
          ))}
        </div>

        <div className="p-5">
          {/* Overview Tab */}
          {activeTab === "overview" && (
            <div className="space-y-4">
              {/* Search */}
              <div className="flex items-center gap-4">
                <div className="relative flex-1">
                  <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                  <input
                    type="text"
                    placeholder={locale === "th" ? "ค้นหาเจ้าหน้าที่..." : "Search guards..."}
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl py-2.5 pl-11 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
              </div>

              {/* Guards Table */}
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-slate-50/80 border-b border-slate-200">
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เจ้าหน้าที่" : "Guard"}</th>
                      <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ยอดถอนได้" : "Withdrawable"}</th>
                      <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ยอด Pending" : "Pending"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "บัญชีธนาคาร" : "Bank Account"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ธุรกรรมล่าสุด" : "Last Transaction"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "สถานะ" : "Status"}</th>
                      <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "จัดการ" : "Actions"}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredGuards.map((guard) => (
                      <tr key={guard.id} className="hover:bg-slate-50/50 transition-colors">
                        <td className="py-4 px-5">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary/20 to-primary/10 flex items-center justify-center flex-shrink-0">
                              <span className="text-sm font-bold text-primary">{guard.name.charAt(0)}</span>
                            </div>
                            <div>
                              <p className="font-semibold text-slate-900">{guard.name}</p>
                              <p className="text-xs text-slate-400">ID: {guard.id}</p>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <span className="text-sm font-bold text-emerald-600">฿{guard.withdrawable.toLocaleString()}</span>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <span className="text-sm font-medium text-amber-600">฿{guard.pending.toLocaleString()}</span>
                        </td>
                        <td className="py-4 px-5">
                          <div>
                            <p className="text-sm font-medium text-slate-700">{guard.bankAccount}</p>
                            <p className="text-xs text-slate-400">{guard.bankName}</p>
                          </div>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-500">{guard.lastTransaction}</p>
                        </td>
                        <td className="py-4 px-5">
                          <span className={cn(
                            "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                            guard.status === "active"
                              ? "bg-emerald-100 text-emerald-700"
                              : "bg-red-100 text-red-700"
                          )}>
                            <span className={cn(
                              "w-1.5 h-1.5 rounded-full",
                              guard.status === "active" ? "bg-emerald-500" : "bg-red-500"
                            )}></span>
                            {guard.status === "active" ? (locale === "th" ? "ใช้งาน" : "Active") : (locale === "th" ? "ระงับ" : "Suspended")}
                          </span>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <button
                            onClick={() => handleOpenDetail(guard)}
                            className="p-2.5 bg-slate-100 hover:bg-primary hover:text-white rounded-xl transition-all"
                          >
                            <Eye className="h-4 w-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {filteredGuards.length === 0 && (
                <div className="py-16 text-center">
                  <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                    <Users className="h-8 w-8 text-slate-400" />
                  </div>
                  <p className="text-slate-500 font-medium">{locale === "th" ? "ไม่พบเจ้าหน้าที่" : "No guards found"}</p>
                </div>
              )}
            </div>
          )}

          {/* Withdrawal Requests Tab */}
          {activeTab === "requests" && (
            <div className="space-y-4">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-slate-900">
                  {locale === "th" ? "คำขอถอนเงินรอการอนุมัติ" : "Pending Withdrawal Requests"}
                </h3>
                <span className="px-3 py-1 bg-blue-100 text-blue-700 text-xs font-bold rounded-lg">
                  {pendingRequestsCount} {locale === "th" ? "รายการ" : "Items"}
                </span>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-slate-50/80 border-b border-slate-200">
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เจ้าหน้าที่" : "Guard"}</th>
                      <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "จำนวนเงิน" : "Amount"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "วันที่ขอ" : "Request Date"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เหตุผล" : "Reason"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "สถานะ" : "Status"}</th>
                      <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "การดำเนินการ" : "Actions"}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {withdrawalRequests.map((request) => (
                      <tr key={request.id} className="hover:bg-slate-50/50 transition-colors">
                        <td className="py-4 px-5">
                          <p className="font-semibold text-slate-900">{request.guardName}</p>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <span className="text-sm font-bold text-slate-900">฿{request.amount.toLocaleString()}</span>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-500">{request.requestDate}</p>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-600">{request.reason}</p>
                        </td>
                        <td className="py-4 px-5">
                          <span className={cn(
                            "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                            request.status === "pending" ? "bg-amber-100 text-amber-700" :
                              request.status === "approved" ? "bg-emerald-100 text-emerald-700" :
                                "bg-red-100 text-red-700"
                          )}>
                            {request.status === "pending" ? (locale === "th" ? "รออนุมัติ" : "Pending") :
                              request.status === "approved" ? (locale === "th" ? "อนุมัติ" : "Approved") :
                                (locale === "th" ? "ปฏิเสธ" : "Rejected")}
                          </span>
                        </td>
                        <td className="py-4 px-5 text-right">
                          {request.status === "pending" && (
                            <div className="flex items-center justify-end gap-2">
                              <button
                                onClick={() => handleApproveWithdrawal(request.id)}
                                className="px-4 py-2 bg-emerald-500 text-white text-sm font-medium rounded-xl hover:bg-emerald-600 transition-colors flex items-center gap-1.5"
                              >
                                <CheckCircle2 className="h-4 w-4" />
                                {locale === "th" ? "อนุมัติ" : "Approve"}
                              </button>
                              <button
                                onClick={() => handleRejectWithdrawal(request.id)}
                                className="px-4 py-2 bg-red-500 text-white text-sm font-medium rounded-xl hover:bg-red-600 transition-colors flex items-center gap-1.5"
                              >
                                <XCircle className="h-4 w-4" />
                                {locale === "th" ? "ปฏิเสธ" : "Reject"}
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {withdrawalRequests.length === 0 && (
                <div className="py-16 text-center">
                  <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                    <Clock className="h-8 w-8 text-slate-400" />
                  </div>
                  <p className="text-slate-500 font-medium">{locale === "th" ? "ไม่มีคำขอถอนเงิน" : "No withdrawal requests"}</p>
                </div>
              )}
            </div>
          )}

          {/* Admin History Tab */}
          {activeTab === "history" && (
            <div className="space-y-4">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-slate-900">
                  {locale === "th" ? "ประวัติการดำเนินการของผู้ดูแลระบบ" : "Admin Action History"}
                </h3>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-slate-50/80 border-b border-slate-200">
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ผู้ดูแลระบบ" : "Admin"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "การดำเนินการ" : "Action"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เจ้าหน้าที่" : "Guard"}</th>
                      <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "จำนวนเงิน" : "Amount"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เหตุผล" : "Reason"}</th>
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "วันที่" : "Date"}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {adminActions.map((action) => (
                      <tr key={action.id} className="hover:bg-slate-50/50 transition-colors">
                        <td className="py-4 px-5">
                          <p className="font-medium text-slate-900">{action.adminName}</p>
                        </td>
                        <td className="py-4 px-5">
                          <span className={cn(
                            "inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-semibold",
                            action.actionType === "add_money" ? "bg-emerald-100 text-emerald-700" :
                              action.actionType === "deduct_money" ? "bg-orange-100 text-orange-700" :
                                action.actionType === "approve_withdrawal" ? "bg-blue-100 text-blue-700" :
                                  "bg-red-100 text-red-700"
                          )}>
                            {getActionLabel(action.actionType)}
                          </span>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm font-medium text-primary">{action.guardName}</p>
                        </td>
                        <td className="py-4 px-5 text-right">
                          <span className="text-sm font-bold text-slate-900">฿{action.amount.toLocaleString()}</span>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-600">{action.reason}</p>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-500">{action.date}</p>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Settings Tab */}
          {activeTab === "settings" && (
            <div className="space-y-6 max-w-2xl">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-slate-900">
                  {locale === "th" ? "การตั้งค่าระบบกระเป๋าเงิน" : "Wallet System Settings"}
                </h3>
              </div>

              <div className="space-y-5">
                {/* Pending Duration */}
                <div className="bg-slate-50 rounded-xl p-5">
                  <label className="text-sm font-bold text-slate-700 block mb-2">
                    {locale === "th" ? "ระยะเวลา Pending (ชั่วโมง)" : "Pending Duration (Hours)"}
                  </label>
                  <input
                    type="number"
                    value={settings.pendingDuration}
                    onChange={(e) => setSettings({ ...settings, pendingDuration: parseInt(e.target.value) || 0 })}
                    className="w-full bg-white border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all outline-none"
                  />
                  <p className="text-xs text-slate-500 mt-2">
                    {locale === "th"
                      ? "ระยะเวลาที่เงินจะอยู่ในสถานะ Pending หลังจากงานเสร็จสิ้น"
                      : "Duration money stays in Pending status after job completion"}
                  </p>
                </div>

                {/* Minimum Withdrawal */}
                <div className="bg-slate-50 rounded-xl p-5">
                  <label className="text-sm font-bold text-slate-700 block mb-2">
                    {locale === "th" ? "จำนวนเงินขั้นต่ำในการถอน (บาท)" : "Minimum Withdrawal Amount (Baht)"}
                  </label>
                  <input
                    type="number"
                    value={settings.minWithdrawal}
                    onChange={(e) => setSettings({ ...settings, minWithdrawal: parseInt(e.target.value) || 0 })}
                    className="w-full bg-white border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all outline-none"
                  />
                  <p className="text-xs text-slate-500 mt-2">
                    {locale === "th"
                      ? "จำนวนเงินขั้นต่ำที่เจ้าหน้าที่สามารถถอนได้"
                      : "Minimum amount guards can withdraw"}
                  </p>
                </div>

                {/* Free Withdrawals Per Day */}
                <div className="bg-slate-50 rounded-xl p-5">
                  <label className="text-sm font-bold text-slate-700 block mb-2">
                    {locale === "th" ? "จำนวนครั้งถอนฟรีต่อวัน" : "Free Withdrawals Per Day"}
                  </label>
                  <input
                    type="number"
                    value={settings.freeWithdrawalsPerDay}
                    onChange={(e) => setSettings({ ...settings, freeWithdrawalsPerDay: parseInt(e.target.value) || 0 })}
                    className="w-full bg-white border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all outline-none"
                  />
                  <p className="text-xs text-slate-500 mt-2">
                    {locale === "th"
                      ? "จำนวนครั้งที่เจ้าหน้าที่สามารถถอนเงินฟรีต่อวัน"
                      : "Number of free withdrawals guards can make per day"}
                  </p>
                </div>

                {/* Additional Fee */}
                <div className="bg-slate-50 rounded-xl p-5">
                  <label className="text-sm font-bold text-slate-700 block mb-2">
                    {locale === "th" ? "ค่าธรรมเนียมถอนเพิ่มเติม (บาท)" : "Additional Withdrawal Fee (Baht)"}
                  </label>
                  <input
                    type="number"
                    value={settings.additionalFee}
                    onChange={(e) => setSettings({ ...settings, additionalFee: parseInt(e.target.value) || 0 })}
                    className="w-full bg-white border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all outline-none"
                  />
                  <p className="text-xs text-slate-500 mt-2">
                    {locale === "th"
                      ? "ค่าธรรมเนียมสำหรับการถอนเงินเกินจำนวนครั้งฟรี"
                      : "Fee for withdrawals beyond free limit"}
                  </p>
                </div>

                {/* Save Button */}
                <div className="flex justify-end pt-4">
                  <button className="px-6 py-3 bg-primary text-white font-medium rounded-xl hover:bg-emerald-600 transition-colors flex items-center gap-2 shadow-lg shadow-primary/20">
                    <Save className="h-4 w-4" />
                    {locale === "th" ? "บันทึกการตั้งค่า" : "Save Settings"}
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Guard Detail Modal */}
      {detailModalOpen && selectedGuard && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl shadow-2xl max-h-[90vh] overflow-hidden flex flex-col">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-primary/20 to-primary/10 flex items-center justify-center">
                  <span className="text-lg font-bold text-primary">{selectedGuard.name.charAt(0)}</span>
                </div>
                <div>
                  <h2 className="text-lg font-bold text-slate-900">
                    {locale === "th" ? "รายละเอียดกระเป๋าเงิน" : "Wallet Details"}
                  </h2>
                  <p className="text-sm text-slate-500">{selectedGuard.name}</p>
                </div>
              </div>
              <button
                onClick={() => setDetailModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            {/* Balance Cards */}
            <div className="p-5 border-b border-slate-100">
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-emerald-50 rounded-xl p-4 text-center">
                  <p className="text-sm text-emerald-600 font-medium">{locale === "th" ? "ยอดถอนได้" : "Withdrawable"}</p>
                  <p className="text-2xl font-bold text-emerald-700 mt-1">฿{selectedGuard.withdrawable.toLocaleString()}</p>
                </div>
                <div className="bg-amber-50 rounded-xl p-4 text-center">
                  <p className="text-sm text-amber-600 font-medium">{locale === "th" ? "ยอด Pending" : "Pending"}</p>
                  <p className="text-2xl font-bold text-amber-700 mt-1">฿{selectedGuard.pending.toLocaleString()}</p>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex gap-3 mt-4">
                <button
                  onClick={() => setAddMoneyModalOpen(true)}
                  className="flex-1 px-4 py-2.5 bg-emerald-500 text-white text-sm font-medium rounded-xl hover:bg-emerald-600 transition-colors flex items-center justify-center gap-2"
                >
                  <Plus className="h-4 w-4" />
                  {locale === "th" ? "เพิ่มเงิน" : "Add Money"}
                </button>
                <button
                  onClick={() => setDeductMoneyModalOpen(true)}
                  className="flex-1 px-4 py-2.5 bg-orange-500 text-white text-sm font-medium rounded-xl hover:bg-orange-600 transition-colors flex items-center justify-center gap-2"
                >
                  <Minus className="h-4 w-4" />
                  {locale === "th" ? "หักเงิน" : "Deduct Money"}
                </button>
                <button className="px-4 py-2.5 bg-slate-100 text-slate-700 text-sm font-medium rounded-xl hover:bg-slate-200 transition-colors flex items-center gap-2">
                  <Download className="h-4 w-4" />
                  {locale === "th" ? "ส่งออก" : "Export"}
                </button>
              </div>
            </div>

            {/* Transaction History */}
            <div className="flex-1 overflow-y-auto p-5">
              <h3 className="text-sm font-bold text-slate-700 mb-4">
                {locale === "th" ? "ประวัติธุรกรรม" : "Transaction History"}
              </h3>
              <div className="space-y-3">
                {selectedGuard.transactions.map((tx) => (
                  <div key={tx.id} className="flex items-center justify-between p-4 bg-slate-50 rounded-xl">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-white rounded-lg">
                        {getTransactionIcon(tx.type)}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-slate-900">{getTransactionLabel(tx.type)}</p>
                        <p className="text-xs text-slate-500">{tx.description}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className={cn(
                        "text-sm font-bold",
                        tx.amount > 0 ? "text-emerald-600" : "text-red-600"
                      )}>
                        {tx.amount > 0 ? "+" : ""}฿{Math.abs(tx.amount).toLocaleString()}
                      </p>
                      <p className="text-xs text-slate-400">{tx.date}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Add Money Modal */}
      {addMoneyModalOpen && selectedGuard && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[60] p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl">
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-emerald-100 rounded-xl">
                  <Plus className="h-5 w-5 text-emerald-600" />
                </div>
                <div>
                  <h2 className="text-lg font-bold text-slate-900">
                    {locale === "th" ? "เพิ่มเงิน" : "Add Money"}
                  </h2>
                  <p className="text-sm text-slate-500">{selectedGuard.name}</p>
                </div>
              </div>
              <button
                onClick={() => { setAddMoneyModalOpen(false); setMoneyAmount(""); setMoneyReason(""); }}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "จำนวนเงิน (บาท)" : "Amount (Baht)"}
                </label>
                <input
                  type="number"
                  value={moneyAmount}
                  onChange={(e) => setMoneyAmount(e.target.value)}
                  placeholder="0"
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 focus:bg-white transition-all outline-none"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "เหตุผล" : "Reason"}
                </label>
                <textarea
                  value={moneyReason}
                  onChange={(e) => setMoneyReason(e.target.value)}
                  placeholder={locale === "th" ? "ระบุเหตุผล..." : "Enter reason..."}
                  rows={3}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 focus:bg-white transition-all outline-none resize-none"
                />
              </div>
            </div>
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => { setAddMoneyModalOpen(false); setMoneyAmount(""); setMoneyReason(""); }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleAddMoney}
                disabled={!moneyAmount || parseFloat(moneyAmount) <= 0}
                className={cn(
                  "flex-1 px-4 py-2.5 text-sm font-medium text-white rounded-xl flex items-center justify-center gap-2 transition-colors",
                  moneyAmount && parseFloat(moneyAmount) > 0
                    ? "bg-emerald-500 hover:bg-emerald-600"
                    : "bg-slate-300 cursor-not-allowed"
                )}
              >
                <Plus className="h-4 w-4" />
                {locale === "th" ? "เพิ่มเงิน" : "Add Money"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Deduct Money Modal */}
      {deductMoneyModalOpen && selectedGuard && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[60] p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl">
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-orange-100 rounded-xl">
                  <Minus className="h-5 w-5 text-orange-600" />
                </div>
                <div>
                  <h2 className="text-lg font-bold text-slate-900">
                    {locale === "th" ? "หักเงิน" : "Deduct Money"}
                  </h2>
                  <p className="text-sm text-slate-500">{selectedGuard.name}</p>
                </div>
              </div>
              <button
                onClick={() => { setDeductMoneyModalOpen(false); setMoneyAmount(""); setMoneyReason(""); }}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div className="bg-orange-50 rounded-xl p-3 text-center">
                <p className="text-sm text-orange-600">{locale === "th" ? "ยอดถอนได้ปัจจุบัน" : "Current Withdrawable"}</p>
                <p className="text-xl font-bold text-orange-700">฿{selectedGuard.withdrawable.toLocaleString()}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "จำนวนเงินที่หัก (บาท)" : "Deduction Amount (Baht)"}
                </label>
                <input
                  type="number"
                  value={moneyAmount}
                  onChange={(e) => setMoneyAmount(e.target.value)}
                  placeholder="0"
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 focus:bg-white transition-all outline-none"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "เหตุผล" : "Reason"}
                </label>
                <textarea
                  value={moneyReason}
                  onChange={(e) => setMoneyReason(e.target.value)}
                  placeholder={locale === "th" ? "ระบุเหตุผล..." : "Enter reason..."}
                  rows={3}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 focus:bg-white transition-all outline-none resize-none"
                />
              </div>
            </div>
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => { setDeductMoneyModalOpen(false); setMoneyAmount(""); setMoneyReason(""); }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleDeductMoney}
                disabled={!moneyAmount || parseFloat(moneyAmount) <= 0}
                className={cn(
                  "flex-1 px-4 py-2.5 text-sm font-medium text-white rounded-xl flex items-center justify-center gap-2 transition-colors",
                  moneyAmount && parseFloat(moneyAmount) > 0
                    ? "bg-orange-500 hover:bg-orange-600"
                    : "bg-slate-300 cursor-not-allowed"
                )}
              >
                <Minus className="h-4 w-4" />
                {locale === "th" ? "หักเงิน" : "Deduct"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
