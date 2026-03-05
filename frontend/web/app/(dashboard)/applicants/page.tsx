"use client";

import { useState, useEffect, useCallback } from "react";
import {
  Users,
  Search,
  Phone,
  Mail,
  Shield,
  X,
  UserPlus,
  Eye,
  Check,
  Ban,
  Calendar,
  ChevronDown,
  UserCheck,
  Loader2,
  AlertCircle,
  RefreshCw,
  ExternalLink,
  FileText,
  Landmark,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { authApi, type UserResponse, type GuardProfile } from "@/lib/api";

// --- Types ---
type ApplicantStatus = "pending" | "approved" | "rejected";
type TabType = "all" | "guard" | "customer";

const statusConfig: Record<ApplicantStatus, { color: string; bg: string; dot: string }> = {
  pending: { color: "text-amber-700", bg: "bg-amber-100", dot: "bg-amber-500" },
  approved: { color: "text-emerald-700", bg: "bg-emerald-100", dot: "bg-emerald-500" },
  rejected: { color: "text-red-700", bg: "bg-red-100", dot: "bg-red-500" },
};

function getInitials(name: string): string {
  return name
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("th-TH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default function ApplicantsPage() {
  const { t, locale } = useLanguage();

  // Data state
  const [applicants, setApplicants] = useState<UserResponse[]>([]);
  const [total, setTotal] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filter state
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<ApplicantStatus | "all">("pending");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [activeTab, setActiveTab] = useState<TabType>("all");

  // Modal state
  const [selectedApplicant, setSelectedApplicant] = useState<UserResponse | null>(null);
  const [isApplicantModalOpen, setIsApplicantModalOpen] = useState(false);
  const [isActionLoading, setIsActionLoading] = useState(false);

  // Guard profile state (fetched when a guard applicant modal opens)
  const [guardProfile, setGuardProfile] = useState<GuardProfile | null>(null);
  const [isGuardProfileLoading, setIsGuardProfileLoading] = useState(false);

  // Document preview lightbox
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  // Fetch applicants from API
  const fetchApplicants = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const params: Record<string, string | number> = { limit: 100 };
      if (activeTab !== "all") params.role = activeTab;
      if (statusFilter !== "all") params.approval_status = statusFilter;
      if (searchQuery.trim()) params.search = searchQuery.trim();

      const result = await authApi.listUsers(params as Parameters<typeof authApi.listUsers>[0]);
      setApplicants(result.users);
      setTotal(result.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsLoading(false);
    }
  }, [activeTab, statusFilter, searchQuery]);

  useEffect(() => {
    const debounce = setTimeout(fetchApplicants, 300);
    return () => clearTimeout(debounce);
  }, [fetchApplicants]);

  // Fetch guard profile when a guard applicant modal opens
  useEffect(() => {
    if (isApplicantModalOpen && selectedApplicant?.role === "guard") {
      setGuardProfile(null);
      setIsGuardProfileLoading(true);
      authApi.getGuardProfile(selectedApplicant.id)
        .then(setGuardProfile)
        .catch(() => setGuardProfile(null))
        .finally(() => setIsGuardProfileLoading(false));
    } else {
      setGuardProfile(null);
    }
  }, [isApplicantModalOpen, selectedApplicant?.id, selectedApplicant?.role]);

  // Stats scoped to current view
  const stats = {
    total,
    pending: applicants.filter((a) => a.approval_status === "pending").length,
    approved: applicants.filter((a) => a.approval_status === "approved").length,
    rejected: applicants.filter((a) => a.approval_status === "rejected").length,
  };

  const closeModal = () => {
    setIsApplicantModalOpen(false);
    setSelectedApplicant(null);
    setGuardProfile(null);
    setPreviewUrl(null);
  };

  const handleApprove = async (userId: string) => {
    setIsActionLoading(true);
    try {
      await authApi.updateApprovalStatus(userId, "approved");
      await fetchApplicants();
      closeModal();
    } catch {
      // Keep modal open on error
    } finally {
      setIsActionLoading(false);
    }
  };

  const handleReject = async (userId: string) => {
    setIsActionLoading(true);
    try {
      await authApi.updateApprovalStatus(userId, "rejected");
      await fetchApplicants();
      closeModal();
    } catch {
      // Keep modal open on error
    } finally {
      setIsActionLoading(false);
    }
  };

  const tabs: { key: TabType; label: string; icon: React.ReactNode }[] = [
    { key: "all", label: t.applicants.tabs.all, icon: <Users className="h-4 w-4" /> },
    { key: "guard", label: t.applicants.tabs.guard, icon: <Shield className="h-4 w-4" /> },
    { key: "customer", label: t.applicants.tabs.customer, icon: <UserCheck className="h-4 w-4" /> },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{t.applicants.title}</h1>
          <p className="text-slate-500 mt-1">{t.applicants.subtitle}</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-2xl border border-slate-200 p-1.5 shadow-sm inline-flex gap-1">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={cn(
              "flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium transition-all",
              activeTab === tab.key
                ? "bg-primary text-white shadow-md shadow-primary/20"
                : "text-slate-600 hover:bg-slate-100"
            )}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-5">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">{t.applicants.stats.total}</p>
              <p className="text-3xl font-bold text-slate-900 mt-1">{stats.total}</p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Users className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-amber-50 to-white p-5 rounded-2xl border border-amber-100 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600">{t.applicants.stats.pending}</p>
              <p className="text-3xl font-bold text-amber-700 mt-1">{stats.pending}</p>
            </div>
            <div className="p-3 bg-amber-100 rounded-xl">
              <UserPlus className="h-6 w-6 text-amber-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-2xl border border-emerald-100 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600">{t.applicants.stats.approved}</p>
              <p className="text-3xl font-bold text-emerald-700 mt-1">{stats.approved}</p>
            </div>
            <div className="p-3 bg-emerald-100 rounded-xl">
              <Check className="h-6 w-6 text-emerald-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-red-50 to-white p-5 rounded-2xl border border-red-100 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-red-600">{t.applicants.stats.rejected}</p>
              <p className="text-3xl font-bold text-red-700 mt-1">{stats.rejected}</p>
            </div>
            <div className="p-3 bg-red-100 rounded-xl">
              <Ban className="h-6 w-6 text-red-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
        <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
          <div className="relative flex-1 w-full">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
            <input
              type="text"
              placeholder={t.applicants.searchPlaceholder}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 pl-12 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
            />
          </div>
          <div className="relative">
            <button
              onClick={() => setIsFilterOpen(!isFilterOpen)}
              className="flex items-center gap-3 px-5 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-100 transition-colors min-w-[180px] justify-between"
            >
              <span>
                {statusFilter === "all"
                  ? t.applicants.statusAll
                  : statusFilter === "pending"
                    ? t.applicants.statusPending
                    : statusFilter === "approved"
                      ? t.applicants.statusApproved
                      : t.applicants.statusRejected}
              </span>
              <ChevronDown className={cn("h-4 w-4 transition-transform", isFilterOpen && "rotate-180")} />
            </button>
            {isFilterOpen && (
              <div className="absolute right-0 mt-2 w-52 bg-white rounded-xl border border-slate-200 shadow-xl py-2 z-50">
                <button
                  onClick={() => {
                    setStatusFilter("all");
                    setIsFilterOpen(false);
                  }}
                  className={cn(
                    "w-full px-4 py-2.5 text-sm text-left transition-colors",
                    statusFilter === "all"
                      ? "bg-primary/10 text-primary font-medium"
                      : "text-slate-700 hover:bg-slate-50"
                  )}
                >
                  {t.applicants.statusAll}
                </button>
                {(["pending", "approved", "rejected"] as ApplicantStatus[]).map((status) => (
                  <button
                    key={status}
                    onClick={() => {
                      setStatusFilter(status);
                      setIsFilterOpen(false);
                    }}
                    className={cn(
                      "w-full px-4 py-2.5 text-sm text-left transition-colors",
                      statusFilter === status
                        ? "bg-primary/10 text-primary font-medium"
                        : "text-slate-700 hover:bg-slate-50"
                    )}
                  >
                    {status === "pending"
                      ? t.applicants.statusPending
                      : status === "approved"
                        ? t.applicants.statusApproved
                        : t.applicants.statusRejected}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Loading State */}
      {isLoading && (
        <div className="py-16 text-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary mx-auto mb-4" />
          <p className="text-slate-500 font-medium">{t.applicants.loading}</p>
        </div>
      )}

      {/* Error State */}
      {error && !isLoading && (
        <div className="py-16 text-center">
          <div className="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <AlertCircle className="h-8 w-8 text-red-500" />
          </div>
          <p className="text-slate-700 font-medium mb-2">{t.applicants.errorLoading}</p>
          <p className="text-sm text-slate-500 mb-4">{error}</p>
          <button
            onClick={fetchApplicants}
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-xl text-sm font-medium hover:bg-emerald-600 transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            {t.applicants.retry}
          </button>
        </div>
      )}

      {/* Applicants Table */}
      {!isLoading && !error && (
        <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-200">
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.applicant}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.phone}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.type}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.appliedDate}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.status}
                  </th>
                  <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.actions}
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {applicants.map((applicant) => {
                  const status = statusConfig[applicant.approval_status];
                  return (
                    <tr key={applicant.id} className="hover:bg-slate-50/50 transition-colors group">
                      {/* Applicant Name + Avatar */}
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-3">
                          <div
                            className={cn(
                              "w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0",
                              applicant.role === "guard"
                                ? "bg-gradient-to-br from-amber-100 to-amber-50"
                                : applicant.role === "customer"
                                  ? "bg-gradient-to-br from-blue-100 to-blue-50"
                                  : "bg-gradient-to-br from-slate-100 to-slate-50"
                            )}
                          >
                            <span
                              className={cn(
                                "text-sm font-bold",
                                applicant.role === "guard"
                                  ? "text-amber-700"
                                  : applicant.role === "customer"
                                    ? "text-blue-700"
                                    : "text-slate-500"
                              )}
                            >
                              {getInitials(applicant.full_name)}
                            </span>
                          </div>
                          <div>
                            <p className="font-semibold text-slate-900">{applicant.full_name}</p>
                            <p className="text-xs text-slate-400">{applicant.email}</p>
                          </div>
                        </div>
                      </td>
                      {/* Phone */}
                      <td className="py-4 px-5">
                        <p className="text-sm text-slate-600">{applicant.phone}</p>
                      </td>
                      {/* Type badge */}
                      <td className="py-4 px-5">
                        {applicant.role === "guard" || applicant.role === "customer" ? (
                          <span
                            className={cn(
                              "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                              applicant.role === "guard"
                                ? "bg-amber-100 text-amber-700"
                                : "bg-blue-100 text-blue-700"
                            )}
                          >
                            {applicant.role === "guard" ? (
                              <Shield className="h-3 w-3" />
                            ) : (
                              <UserCheck className="h-3 w-3" />
                            )}
                            {t.applicants.badge[applicant.role]}
                          </span>
                        ) : (
                          <span className="text-sm text-slate-400">
                            {t.applicants.badge.noRole}
                          </span>
                        )}
                      </td>
                      {/* Applied date */}
                      <td className="py-4 px-5">
                        <p className="text-sm text-slate-500">{formatDate(applicant.created_at)}</p>
                      </td>
                      {/* Status */}
                      <td className="py-4 px-5">
                        <span
                          className={cn(
                            "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                            status.bg,
                            status.color
                          )}
                        >
                          <span className={cn("w-1.5 h-1.5 rounded-full", status.dot)}></span>
                          {applicant.approval_status === "pending"
                            ? t.applicants.statusPending
                            : applicant.approval_status === "approved"
                              ? t.applicants.statusApproved
                              : t.applicants.statusRejected}
                        </span>
                      </td>
                      {/* Actions */}
                      <td className="py-4 px-5 text-right">
                        <button
                          onClick={() => {
                            setSelectedApplicant(applicant);
                            setIsApplicantModalOpen(true);
                          }}
                          className="p-2.5 bg-slate-100 hover:bg-primary hover:text-white rounded-xl transition-all group-hover:shadow-sm"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {applicants.length === 0 && (
            <div className="py-16 text-center">
              <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <Users className="h-8 w-8 text-slate-400" />
              </div>
              <p className="text-slate-500 font-medium">{t.applicants.noApplicantsFound}</p>
            </div>
          )}
        </div>
      )}

      {/* Applicant Review Modal */}
      {isApplicantModalOpen && selectedApplicant && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl border border-slate-200 w-full max-w-2xl overflow-hidden animate-in fade-in zoom-in duration-200">
            {/* Modal Header */}
            <div
              className={cn(
                "flex items-center justify-between p-6 border-b border-slate-100",
                selectedApplicant.role === "guard"
                  ? "bg-gradient-to-r from-amber-50 to-white"
                  : selectedApplicant.role === "customer"
                    ? "bg-gradient-to-r from-blue-50 to-white"
                    : "bg-gradient-to-r from-slate-50 to-white"
              )}
            >
              <div className="flex items-center gap-3">
                <div
                  className={cn(
                    "p-2 rounded-xl",
                    selectedApplicant.role === "guard"
                      ? "bg-amber-100"
                      : selectedApplicant.role === "customer"
                        ? "bg-blue-100"
                        : "bg-slate-100"
                  )}
                >
                  {selectedApplicant.role === "guard" ? (
                    <Shield className="h-5 w-5 text-amber-600" />
                  ) : selectedApplicant.role === "customer" ? (
                    <UserCheck className="h-5 w-5 text-blue-600" />
                  ) : (
                    <Users className="h-5 w-5 text-slate-500" />
                  )}
                </div>
                <div>
                  <h2 className="text-xl font-bold text-slate-900">
                    {t.applicants.modal.reviewTitle}
                  </h2>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span
                      className={cn(
                        "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider",
                        selectedApplicant.role === "guard"
                          ? "bg-amber-100 text-amber-700"
                          : selectedApplicant.role === "customer"
                            ? "bg-blue-100 text-blue-700"
                            : "bg-slate-100 text-slate-500"
                      )}
                    >
                      {selectedApplicant.role === "guard"
                        ? t.applicants.badge.guard
                        : selectedApplicant.role === "customer"
                          ? t.applicants.badge.customer
                          : t.applicants.badge.noRole}
                    </span>
                  </div>
                </div>
              </div>
              <button
                onClick={closeModal}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            <div className="p-8 overflow-y-auto max-h-[60vh]">
              {/* Header Info */}
              <div className="flex items-start justify-between mb-8">
                <div className="flex items-center gap-6">
                  <div
                    className={cn(
                      "w-20 h-20 rounded-2xl flex items-center justify-center text-2xl font-bold shadow-inner",
                      selectedApplicant.role === "guard"
                        ? "bg-gradient-to-br from-amber-100 to-amber-50 text-amber-700"
                        : selectedApplicant.role === "customer"
                          ? "bg-gradient-to-br from-blue-100 to-blue-50 text-blue-700"
                          : "bg-gradient-to-br from-slate-100 to-slate-50 text-slate-500"
                    )}
                  >
                    {getInitials(selectedApplicant.full_name)}
                  </div>
                  <div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-1">
                      {selectedApplicant.full_name}
                    </h3>
                    <div className="flex items-center gap-2">
                      <span
                        className={cn(
                          "px-3 py-1 text-xs font-semibold rounded-full",
                          statusConfig[selectedApplicant.approval_status].bg,
                          statusConfig[selectedApplicant.approval_status].color
                        )}
                      >
                        {selectedApplicant.approval_status === "pending"
                          ? t.applicants.statusPending
                          : selectedApplicant.approval_status === "approved"
                            ? t.applicants.statusApproved
                            : t.applicants.statusRejected}
                      </span>
                      <span className="text-xs text-slate-400">
                        <Calendar className="h-3 w-3 inline mr-1" />
                        {formatDate(selectedApplicant.created_at)}
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Contact Info */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-4 mb-8 p-4 bg-slate-50 rounded-xl">
                <div className="flex items-center gap-3 text-slate-600">
                  <Phone className="h-5 w-5 text-slate-400" />
                  <span className="text-sm font-medium">{selectedApplicant.phone}</span>
                </div>
                <div className="flex items-center gap-3 text-slate-600">
                  <Mail className="h-5 w-5 text-slate-400" />
                  <span className="text-sm font-medium">{selectedApplicant.email}</span>
                </div>
              </div>

              {/* Guard Profile Sections */}
              {selectedApplicant.role === "guard" && (
                <div className="space-y-6">
                  {isGuardProfileLoading ? (
                    <div className="flex items-center gap-2 text-slate-400 text-sm py-4">
                      <Loader2 className="h-4 w-4 animate-spin" />
                      {t.applicants.modal.guardProfile.loadingProfile}
                    </div>
                  ) : guardProfile ? (
                    <>
                      {/* Personal Info */}
                      <div>
                        <h4 className="text-sm font-semibold text-slate-500 uppercase tracking-wider mb-3 flex items-center gap-2">
                          <FileText className="h-4 w-4" />
                          {t.applicants.modal.guardProfile.personalInfo}
                        </h4>
                        <div className="grid grid-cols-2 gap-3">
                          {guardProfile.gender && (
                            <div className="p-3 bg-slate-50 rounded-xl">
                              <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.gender}</p>
                              <p className="text-sm font-medium text-slate-800">{guardProfile.gender}</p>
                            </div>
                          )}
                          {guardProfile.date_of_birth && (
                            <div className="p-3 bg-slate-50 rounded-xl">
                              <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.dateOfBirth}</p>
                              <p className="text-sm font-medium text-slate-800">{guardProfile.date_of_birth}</p>
                            </div>
                          )}
                          {guardProfile.years_of_experience !== null && guardProfile.years_of_experience !== undefined && (
                            <div className="p-3 bg-slate-50 rounded-xl">
                              <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.yearsExp}</p>
                              <p className="text-sm font-medium text-slate-800">{guardProfile.years_of_experience}</p>
                            </div>
                          )}
                          {guardProfile.previous_workplace && (
                            <div className="p-3 bg-slate-50 rounded-xl">
                              <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.workplace}</p>
                              <p className="text-sm font-medium text-slate-800">{guardProfile.previous_workplace}</p>
                            </div>
                          )}
                        </div>
                      </div>

                      {/* Documents */}
                      <div>
                        <h4 className="text-sm font-semibold text-slate-500 uppercase tracking-wider mb-3 flex items-center gap-2">
                          <Shield className="h-4 w-4" />
                          {t.applicants.modal.guardProfile.documentsSection}
                        </h4>
                        <div className="space-y-2">
                          {([
                            ["id_card_url", t.applicants.modal.guardProfile.docIdCard],
                            ["security_license_url", t.applicants.modal.guardProfile.docSecurityLicense],
                            ["training_cert_url", t.applicants.modal.guardProfile.docTrainingCert],
                            ["criminal_check_url", t.applicants.modal.guardProfile.docCriminalCheck],
                            ["driver_license_url", t.applicants.modal.guardProfile.docDriverLicense],
                            ["passbook_photo_url", t.applicants.modal.guardProfile.passbookPhoto],
                          ] as [keyof GuardProfile, string][]).map(([field, label]) => {
                            const url = guardProfile[field] as string | null;
                            return (
                              <div key={field} className="flex items-center justify-between p-3 bg-slate-50 rounded-xl">
                                <span className="text-sm text-slate-700">{label}</span>
                                {url ? (
                                  <button
                                    onClick={() => setPreviewUrl(url)}
                                    className="flex items-center gap-1 text-xs font-semibold text-emerald-600 hover:text-emerald-700 transition-colors"
                                  >
                                    <Eye className="h-3.5 w-3.5" />
                                    {t.applicants.modal.guardProfile.viewDocument}
                                  </button>
                                ) : (
                                  <span className="text-xs text-slate-400">{t.applicants.modal.guardProfile.notUploaded}</span>
                                )}
                              </div>
                            );
                          })}
                        </div>
                      </div>

                      {/* Bank Account */}
                      {(guardProfile.bank_name || guardProfile.account_number || guardProfile.account_name) && (
                        <div>
                          <h4 className="text-sm font-semibold text-slate-500 uppercase tracking-wider mb-3 flex items-center gap-2">
                            <Landmark className="h-4 w-4" />
                            {t.applicants.modal.guardProfile.bankSection}
                          </h4>
                          <div className="grid grid-cols-2 gap-3">
                            {guardProfile.bank_name && (
                              <div className="p-3 bg-slate-50 rounded-xl">
                                <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.bankName}</p>
                                <p className="text-sm font-medium text-slate-800">{guardProfile.bank_name}</p>
                              </div>
                            )}
                            {guardProfile.account_number && (
                              <div className="p-3 bg-slate-50 rounded-xl">
                                <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.accountNumber}</p>
                                <p className="text-sm font-medium text-slate-800 font-mono">
                                  {"•".repeat(Math.max(0, guardProfile.account_number.length - 4)) + guardProfile.account_number.slice(-4)}
                                </p>
                              </div>
                            )}
                            {guardProfile.account_name && (
                              <div className="p-3 bg-slate-50 rounded-xl col-span-2">
                                <p className="text-xs text-slate-400 mb-0.5">{t.applicants.modal.guardProfile.accountName}</p>
                                <p className="text-sm font-medium text-slate-800">{guardProfile.account_name}</p>
                              </div>
                            )}
                          </div>
                        </div>
                      )}
                    </>
                  ) : (
                    <p className="text-sm text-slate-400 italic py-2">
                      {t.applicants.modal.guardProfile.noProfile}
                    </p>
                  )}
                </div>
              )}

              {/* Approved Note */}
              {selectedApplicant.approval_status === "approved" &&
                (selectedApplicant.role === "guard" || selectedApplicant.role === "customer") && (
                  <div className="mt-6 p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
                    <p className="text-sm text-emerald-700 font-medium flex items-center gap-2">
                      <Check className="h-4 w-4" />
                      {t.applicants.approvedNote[selectedApplicant.role]}
                    </p>
                  </div>
                )}
            </div>

            {/* Action Buttons */}
            {selectedApplicant.approval_status === "pending" &&
            (selectedApplicant.role === "guard" || selectedApplicant.role === "customer") ? (
              <div className="p-6 bg-slate-50 border-t border-slate-100 flex gap-4">
                <button
                  onClick={() => handleReject(selectedApplicant.id)}
                  disabled={isActionLoading}
                  className="flex-1 py-3 px-4 bg-white border-2 border-red-200 text-red-600 rounded-xl text-sm font-bold hover:bg-red-50 hover:border-red-300 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {isActionLoading ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Ban className="h-4 w-4" />
                  )}
                  {t.applicants.modal.reject}
                </button>
                <button
                  onClick={() => handleApprove(selectedApplicant.id)}
                  disabled={isActionLoading}
                  className="flex-1 py-3 px-4 bg-primary text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-all shadow-lg shadow-primary/20 flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {isActionLoading ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Check className="h-4 w-4" />
                  )}
                  {t.applicants.modal.approve}
                </button>
              </div>
            ) : selectedApplicant.approval_status === "pending" ? (
              <div className="p-6 bg-slate-50 border-t border-slate-100 space-y-3">
                <div className="flex items-start gap-3 p-4 bg-amber-50 border border-amber-200 rounded-xl">
                  <AlertCircle className="h-5 w-5 text-amber-600 flex-shrink-0 mt-0.5" />
                  <p className="text-sm text-amber-700 font-medium leading-relaxed">
                    {t.applicants.modal.awaitingRole}
                  </p>
                </div>
                <button
                  onClick={closeModal}
                  className="w-full py-3 px-4 bg-slate-200 text-slate-700 rounded-xl text-sm font-bold hover:bg-slate-300 transition-all"
                >
                  {t.applicants.modal.close}
                </button>
              </div>
            ) : (
              <div className="p-6 bg-slate-50 border-t border-slate-100">
                <button
                  onClick={closeModal}
                  className="w-full py-3 px-4 bg-slate-200 text-slate-700 rounded-xl text-sm font-bold hover:bg-slate-300 transition-all"
                >
                  {t.applicants.modal.close}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Document preview lightbox — z-[60] sits above the applicant modal (z-50) */}
      {previewUrl && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4 animate-in fade-in duration-150"
          onClick={() => setPreviewUrl(null)}
        >
          <div
            className="relative max-w-4xl w-full flex flex-col items-center"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Controls */}
            <div className="absolute top-3 right-3 flex items-center gap-2 z-10">
              <a
                href={previewUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-lg p-2 transition-colors"
                title="Open in new tab"
              >
                <ExternalLink className="h-4 w-4 text-white" />
              </a>
              <button
                onClick={() => setPreviewUrl(null)}
                className="bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-lg p-2 transition-colors"
              >
                <X className="h-4 w-4 text-white" />
              </button>
            </div>
            {/* Image */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={previewUrl}
              alt="Document preview"
              className="max-w-full max-h-[85vh] rounded-xl object-contain shadow-2xl"
            />
          </div>
        </div>
      )}
    </div>
  );
}
