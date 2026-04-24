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
  Save,
  ArrowLeft,
  Building2,
  MapPin,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { authApi, type UserResponse, type GuardProfile, type CustomerProfile } from "@/lib/api";

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

  // Panel state (replaces modal)
  const [selectedApplicant, setSelectedApplicant] = useState<UserResponse | null>(null);
  const [isActionLoading, setIsActionLoading] = useState(false);

  // Guard profile state (fetched when a guard applicant panel opens)
  const [guardProfile, setGuardProfile] = useState<GuardProfile | null>(null);
  const [isGuardProfileLoading, setIsGuardProfileLoading] = useState(false);

  // Customer profile state (fetched when a customer applicant panel opens)
  const [customerProfile, setCustomerProfile] = useState<CustomerProfile | null>(null);
  const [isCustomerProfileLoading, setIsCustomerProfileLoading] = useState(false);

  // Document preview lightbox
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  // Pending counts per tab (fetched independently)
  const [guardPendingCount, setGuardPendingCount] = useState(0);
  const [customerPendingCount, setCustomerPendingCount] = useState(0);

  // Editable guard profile state (for pending applicants)
  const [editedProfile, setEditedProfile] = useState<Record<string, unknown>>({});
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Bulk-action state. Tracks which applicant ids are checked so the
  // operator can approve/reject many at once. Cleared whenever the
  // filter/tab changes so we never act on stale selections.
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkError, setBulkError] = useState<string | null>(null);
  const [bulkInFlight, setBulkInFlight] = useState(false);

  // Fetch applicants from API
  const fetchApplicants = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      if (activeTab === "customer") {
        // Customer applicants come from customer_profiles table
        const params: Record<string, string | number> = { limit: 100 };
        if (statusFilter !== "all") params.approval_status = statusFilter;
        if (searchQuery.trim()) params.search = searchQuery.trim();
        const result = await authApi.listCustomerApplicants(params as Parameters<typeof authApi.listCustomerApplicants>[0]);
        setApplicants(result.users);
        setTotal(result.total);
      } else {
        const params: Record<string, string | number> = { limit: 100 };
        if (activeTab !== "all") params.role = activeTab;
        if (statusFilter !== "all") params.approval_status = statusFilter;
        if (searchQuery.trim()) params.search = searchQuery.trim();
        const result = await authApi.listUsers(params as Parameters<typeof authApi.listUsers>[0]);
        setApplicants(result.users);
        setTotal(result.total);
      }
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

  // Reset the bulk selection whenever the filter or tab changes so the
  // operator never accidentally approves rows they can no longer see.
  useEffect(() => {
    setSelectedIds(new Set());
    setBulkError(null);
  }, [activeTab, statusFilter, searchQuery]);

  // Only pending rows are eligible for bulk approve / reject.
  const pendingVisibleIds = applicants
    .filter((a) => a.approval_status === "pending")
    .map((a) => a.id);

  const toggleSelected = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAll = () => {
    setSelectedIds((prev) => {
      const allSelected =
        pendingVisibleIds.length > 0 &&
        pendingVisibleIds.every((id) => prev.has(id));
      return allSelected ? new Set() : new Set(pendingVisibleIds);
    });
  };

  const runBulk = async (action: "approved" | "rejected") => {
    if (selectedIds.size === 0) return;
    setBulkInFlight(true);
    setBulkError(null);
    const api =
      activeTab === "customer"
        ? authApi.updateCustomerApproval
        : authApi.updateApprovalStatus;
    const ids = Array.from(selectedIds);
    const results = await Promise.allSettled(
      ids.map((id) => api(id, action))
    );
    const failed = results
      .map((r, i) => (r.status === "rejected" ? ids[i] : null))
      .filter((x): x is string => x !== null);
    await fetchApplicants();
    refreshCounts();
    setSelectedIds(new Set());
    setBulkInFlight(false);
    if (failed.length > 0) {
      setBulkError(
        locale === "th"
          ? `บางรายการไม่สำเร็จ (${failed.length}/${ids.length})`
          : `Some updates failed (${failed.length}/${ids.length})`
      );
    }
  };

  // Fetch pending counts per tab (independent of active tab)
  const fetchPendingCounts = useCallback(async () => {
    try {
      const [guardResult, customerResult] = await Promise.all([
        authApi.listUsers({ approval_status: "pending", limit: 1 }),
        authApi.listCustomerApplicants({ approval_status: "pending", limit: 1 }),
      ]);
      setGuardPendingCount(guardResult.total);
      setCustomerPendingCount(customerResult.total);
    } catch (_) {}
  }, []);

  useEffect(() => { fetchPendingCounts(); }, [fetchPendingCounts]);

  // Refresh counts after approval/rejection
  const refreshCounts = () => { fetchPendingCounts(); };

  // Fetch guard profile when a guard applicant is selected
  useEffect(() => {
    if (selectedApplicant && selectedApplicant.role === "guard") {
      setGuardProfile(null);
      setEditedProfile({});
      setSaveSuccess(false);
      setIsGuardProfileLoading(true);
      authApi.getGuardProfile(selectedApplicant.id)
        .then((profile) => {
          setGuardProfile(profile);
          setEditedProfile({
            gender: profile.gender ?? "",
            date_of_birth: profile.date_of_birth ?? "",
            years_of_experience: profile.years_of_experience ?? "",
            previous_workplace: profile.previous_workplace ?? "",
            bank_name: profile.bank_name ?? "",
            account_number: profile.account_number ?? "",
            account_name: profile.account_name ?? "",
            id_card_expiry: profile.id_card_expiry ?? "",
            security_license_expiry: profile.security_license_expiry ?? "",
            training_cert_expiry: profile.training_cert_expiry ?? "",
            criminal_check_expiry: profile.criminal_check_expiry ?? "",
            driver_license_expiry: profile.driver_license_expiry ?? "",
          });
        })
        .catch(() => setGuardProfile(null))
        .finally(() => setIsGuardProfileLoading(false));
    } else if (!selectedApplicant) {
      setGuardProfile(null);
      setEditedProfile({});
    }
  }, [selectedApplicant?.id, selectedApplicant?.role]);

  // Fetch customer profile when a customer applicant is selected
  useEffect(() => {
    if (selectedApplicant && selectedApplicant.role === "customer") {
      setCustomerProfile(null);
      setIsCustomerProfileLoading(true);
      authApi.getCustomerProfile(selectedApplicant.id)
        .then(setCustomerProfile)
        .catch(() => setCustomerProfile(null))
        .finally(() => setIsCustomerProfileLoading(false));
    } else if (!selectedApplicant) {
      setCustomerProfile(null);
    }
  }, [selectedApplicant?.id, selectedApplicant?.role]);

  // Stats scoped to current view
  const stats = {
    total,
    pending: applicants.filter((a) => a.approval_status === "pending").length,
    approved: applicants.filter((a) => a.approval_status === "approved").length,
    rejected: applicants.filter((a) => a.approval_status === "rejected").length,
  };

  const closePanel = () => {
    setSelectedApplicant(null);
    setGuardProfile(null);
    setCustomerProfile(null);
    setPreviewUrl(null);
    setEditedProfile({});
    setSaveSuccess(false);
    setIsEditing(false);
  };

  const handleApprove = async (userId: string) => {
    setIsActionLoading(true);
    try {
      if (activeTab === "customer") {
        await authApi.updateCustomerApproval(userId, "approved");
      } else {
        await authApi.updateApprovalStatus(userId, "approved");
      }
      await fetchApplicants();
      refreshCounts();
      closePanel();
    } catch {
      // Keep panel open on error
    } finally {
      setIsActionLoading(false);
    }
  };

  const handleReject = async (userId: string) => {
    setIsActionLoading(true);
    try {
      if (activeTab === "customer") {
        await authApi.updateCustomerApproval(userId, "rejected");
      } else {
        await authApi.updateApprovalStatus(userId, "rejected");
      }
      await fetchApplicants();
      refreshCounts();
      closePanel();
    } catch {
      // Keep panel open on error
    } finally {
      setIsActionLoading(false);
    }
  };

  const handleSaveProfile = async (userId: string) => {
    setIsSaving(true);
    setSaveSuccess(false);
    try {
      // Build payload: only send non-empty values, convert types
      const payload: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(editedProfile)) {
        if (key === "years_of_experience") {
          payload[key] = value === "" ? null : Number(value);
        } else {
          payload[key] = value === "" ? null : value;
        }
      }
      await authApi.updateGuardProfile(userId, payload);
      // Reload profile after save
      const updated = await authApi.getGuardProfile(userId);
      setGuardProfile(updated);
      setEditedProfile({
        gender: updated.gender ?? "",
        date_of_birth: updated.date_of_birth ?? "",
        years_of_experience: updated.years_of_experience ?? "",
        previous_workplace: updated.previous_workplace ?? "",
        bank_name: updated.bank_name ?? "",
        account_number: updated.account_number ?? "",
        account_name: updated.account_name ?? "",
        id_card_expiry: updated.id_card_expiry ?? "",
        security_license_expiry: updated.security_license_expiry ?? "",
        training_cert_expiry: updated.training_cert_expiry ?? "",
        criminal_check_expiry: updated.criminal_check_expiry ?? "",
        driver_license_expiry: updated.driver_license_expiry ?? "",
      });
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch {
      // Keep panel open on error
    } finally {
      setIsSaving(false);
    }
  };

  const isPending = selectedApplicant?.approval_status === "pending";
  const [isEditing, setIsEditing] = useState(false);

  const updateEditField = (field: string, value: unknown) => {
    setEditedProfile((prev) => ({ ...prev, [field]: value }));
  };

  // Editable only when pending AND editing mode is on
  const canEdit = isPending && isEditing;

  const tabs: { key: TabType; label: string; icon: React.ReactNode; badge?: number }[] = [
    { key: "all", label: t.applicants.tabs.all, icon: <Users className="h-4 w-4" />, badge: guardPendingCount + customerPendingCount || undefined },
    { key: "guard", label: t.applicants.tabs.guard, icon: <Shield className="h-4 w-4" />, badge: guardPendingCount || undefined },
    { key: "customer", label: t.applicants.tabs.customer, icon: <UserCheck className="h-4 w-4" />, badge: customerPendingCount || undefined },
  ];

  const panelOpen = selectedApplicant !== null;

  // When panel is open, show ONLY the detail panel (full page replacement)
  if (panelOpen && selectedApplicant) {
    return (
      <div className="space-y-0">
        {/* Full-page detail panel */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm flex flex-col min-h-[calc(100vh-120px)] animate-in fade-in duration-200">
          {/* Panel Header */}
          <div
            className={cn(
              "flex items-center justify-between px-6 py-4 border-b border-slate-100 sticky top-0 z-10 rounded-t-2xl",
              selectedApplicant.role === "guard"
                ? "bg-gradient-to-r from-amber-50 to-white"
                : selectedApplicant.role === "customer"
                  ? "bg-gradient-to-r from-blue-50 to-white"
                  : "bg-gradient-to-r from-slate-50 to-white"
            )}
          >
            <div className="flex items-center gap-3">
              <button
                onClick={closePanel}
                className="p-2 hover:bg-slate-100 rounded-xl transition-colors"
              >
                <ArrowLeft className="h-5 w-5 text-slate-500" />
              </button>
              <div
                className={cn(
                  "p-2.5 rounded-xl",
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
                <h1 className="text-xl font-bold text-slate-900">
                  {t.applicants.modal.reviewTitle}
                </h1>
                <span
                  className={cn(
                    "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold",
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
            {/* Action buttons in header */}
            {selectedApplicant.approval_status === "pending" &&
            (selectedApplicant.role === "guard" || selectedApplicant.role === "customer") && (
              <div className="hidden md:flex items-center gap-3">
                <button
                  onClick={() => handleReject(selectedApplicant.id)}
                  disabled={isActionLoading || isSaving}
                  className="px-5 py-2 text-sm font-bold text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
                >
                  {t.applicants.modal.reject}
                </button>
                {selectedApplicant.role === "guard" && guardProfile && (
                  isEditing ? (
                    <button
                      onClick={async () => {
                        await handleSaveProfile(selectedApplicant.id);
                        setIsEditing(false);
                      }}
                      disabled={isActionLoading || isSaving}
                      className="px-5 py-2 text-sm font-bold text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2 shadow-lg shadow-blue-200"
                    >
                      {isSaving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
                      {isSaving ? t.applicants.modal.guardProfile.saving : t.applicants.modal.guardProfile.save}
                    </button>
                  ) : (
                    <button
                      onClick={() => setIsEditing(true)}
                      className="px-5 py-2 text-sm font-bold text-blue-600 border border-blue-200 rounded-lg hover:bg-blue-50 transition-colors flex items-center gap-2"
                    >
                      <FileText className="h-4 w-4" />
                      {t.applicants.modal.guardProfile.edit}
                    </button>
                  )
                )}
                <button
                  onClick={() => handleApprove(selectedApplicant.id)}
                  disabled={isActionLoading || isSaving}
                  className="px-6 py-2 text-sm font-bold text-white bg-primary rounded-lg shadow-lg shadow-primary/20 hover:bg-emerald-600 transition-all disabled:opacity-50 flex items-center gap-2"
                >
                  {isActionLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
                  {t.applicants.modal.approve}
                </button>
              </div>
            )}
          </div>

          {/* Save success */}
          {saveSuccess && (
            <div className="mx-6 mt-4 flex items-center gap-2 p-3 bg-emerald-50 border border-emerald-200 rounded-xl">
              <Check className="h-4 w-4 text-emerald-600" />
              <span className="text-sm text-emerald-700 font-medium">{t.applicants.modal.guardProfile.saveSuccess}</span>
            </div>
          )}

          {/* Panel Content — 2 column layout */}
          <div className="flex-1 overflow-y-auto">
            <div className="max-w-6xl mx-auto p-6 lg:p-8">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
                {/* Left: Profile sidebar */}
                <aside className="lg:col-span-4 space-y-6">
                  {/* Profile card */}
                  <div className="bg-slate-50 rounded-2xl p-6">
                    <div className="flex flex-col items-center text-center">
                      <div
                        className={cn(
                          "w-24 h-24 rounded-full flex items-center justify-center text-3xl font-bold shadow-inner mb-4",
                          selectedApplicant.role === "guard"
                            ? "bg-gradient-to-br from-amber-100 to-amber-50 text-amber-700"
                            : selectedApplicant.role === "customer"
                              ? "bg-gradient-to-br from-blue-100 to-blue-50 text-blue-700"
                              : "bg-gradient-to-br from-slate-100 to-slate-50 text-slate-500"
                        )}
                      >
                        {getInitials(selectedApplicant.full_name)}
                      </div>
                      <h2 className="text-xl font-bold text-slate-900">{selectedApplicant.full_name}</h2>
                      <div className="flex items-center gap-2 mt-2">
                        <span className={cn("w-2 h-2 rounded-full animate-pulse", statusConfig[selectedApplicant.approval_status].dot)} />
                        <span className="text-xs font-bold text-slate-400 uppercase tracking-widest">
                          {selectedApplicant.approval_status === "pending"
                            ? t.applicants.statusPending
                            : selectedApplicant.approval_status === "approved"
                              ? t.applicants.statusApproved
                              : t.applicants.statusRejected}
                        </span>
                      </div>
                    </div>
                    {/* Contact info */}
                    <div className="mt-6 space-y-3">
                      <div className="p-3 bg-white rounded-xl">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Mobile</p>
                        <div className="flex items-center gap-2 text-sm font-semibold text-slate-700">
                          <Phone className="h-4 w-4 text-slate-400" />
                          {selectedApplicant.phone}
                        </div>
                      </div>
                      <div className="p-3 bg-white rounded-xl">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Email</p>
                        <div className="flex items-center gap-2 text-sm font-semibold text-slate-700">
                          <Mail className="h-4 w-4 text-slate-400" />
                          <span className="truncate">{selectedApplicant.email}</span>
                        </div>
                      </div>
                      <div className="p-3 bg-white rounded-xl">
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Applied</p>
                        <div className="flex items-center gap-2 text-sm font-semibold text-slate-700">
                          <Calendar className="h-4 w-4 text-slate-400" />
                          {formatDate(selectedApplicant.created_at)}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Personal Info (guard) */}
                  {selectedApplicant.role === "guard" && guardProfile && (
                    <div className="bg-slate-50 rounded-2xl p-6 space-y-4">
                      <h3 className="text-xs font-bold text-slate-900 uppercase tracking-wider">
                        {t.applicants.modal.guardProfile.personalInfo}
                      </h3>
                      <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-1">
                          <p className="text-[10px] text-slate-400 uppercase">{t.applicants.modal.guardProfile.gender}</p>
                          {canEdit ? (
                            <input type="text" value={String(editedProfile.gender ?? "")} onChange={(e) => updateEditField("gender", e.target.value)}
                              className="w-full text-sm font-bold text-slate-800 bg-white border border-slate-200 rounded-lg px-2.5 py-1.5 focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none" />
                          ) : (
                            <p className="text-sm font-bold">{guardProfile.gender || "—"}</p>
                          )}
                        </div>
                        <div className="space-y-1">
                          <p className="text-[10px] text-slate-400 uppercase">{t.applicants.modal.guardProfile.dateOfBirth}</p>
                          {canEdit ? (
                            <input type="date" value={String(editedProfile.date_of_birth ?? "")} onChange={(e) => updateEditField("date_of_birth", e.target.value)}
                              className="w-full text-sm font-bold text-slate-800 bg-white border border-slate-200 rounded-lg px-2.5 py-1.5 focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none" />
                          ) : (
                            <p className="text-sm font-bold">{guardProfile.date_of_birth || "—"}</p>
                          )}
                        </div>
                        <div className="space-y-1">
                          <p className="text-[10px] text-slate-400 uppercase">{t.applicants.modal.guardProfile.yearsExp}</p>
                          {canEdit ? (
                            <input type="number" min="0" value={String(editedProfile.years_of_experience ?? "")} onChange={(e) => updateEditField("years_of_experience", e.target.value)}
                              className="w-full text-sm font-bold text-primary bg-white border border-slate-200 rounded-lg px-2.5 py-1.5 focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none" />
                          ) : (
                            <p className="text-sm font-bold text-primary">{guardProfile.years_of_experience ?? "—"}</p>
                          )}
                        </div>
                        <div className="space-y-1">
                          <p className="text-[10px] text-slate-400 uppercase">{t.applicants.modal.guardProfile.workplace}</p>
                          {canEdit ? (
                            <input type="text" value={String(editedProfile.previous_workplace ?? "")} onChange={(e) => updateEditField("previous_workplace", e.target.value)}
                              className="w-full text-sm font-bold text-slate-800 bg-white border border-slate-200 rounded-lg px-2.5 py-1.5 focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none" />
                          ) : (
                            <p className="text-sm font-bold">{guardProfile.previous_workplace || "—"}</p>
                          )}
                        </div>
                      </div>
                    </div>
                  )}
                </aside>

                {/* Right: Documents + Bank */}
                <div className="lg:col-span-8 space-y-8">
                  {/* Guard sections */}
                  {selectedApplicant.role === "guard" && (
                    <>
                      {isGuardProfileLoading ? (
                        <div className="flex items-center gap-2 text-slate-400 text-sm py-16 justify-center">
                          <Loader2 className="h-5 w-5 animate-spin" />
                          {t.applicants.modal.guardProfile.loadingProfile}
                        </div>
                      ) : guardProfile ? (
                        <>
                          {/* Documents */}
                          <section>
                            <div className="flex items-center justify-between border-b border-slate-200 pb-4 mb-6">
                              <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                                <FileText className="h-5 w-5 text-primary" />
                                {t.applicants.modal.guardProfile.documentsSection}
                              </h3>
                            </div>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                              {([
                                ["id_card_url", t.applicants.modal.guardProfile.docIdCard, "id_card_expiry", "bg-blue-100 text-blue-600"],
                                ["security_license_url", t.applicants.modal.guardProfile.docSecurityLicense, "security_license_expiry", "bg-amber-100 text-amber-600"],
                                ["training_cert_url", t.applicants.modal.guardProfile.docTrainingCert, "training_cert_expiry", "bg-emerald-100 text-emerald-600"],
                                ["criminal_check_url", t.applicants.modal.guardProfile.docCriminalCheck, "criminal_check_expiry", "bg-purple-100 text-purple-600"],
                                ["driver_license_url", t.applicants.modal.guardProfile.docDriverLicense, "driver_license_expiry", "bg-rose-100 text-rose-600"],
                                ["passbook_photo_url", t.applicants.modal.guardProfile.passbookPhoto, null, "bg-cyan-100 text-cyan-600"],
                              ] as [keyof GuardProfile, string, string | null, string][]).map(([field, label, expiryField, iconColor]) => {
                                const url = guardProfile[field] as string | null;
                                const expiryValue = expiryField ? (editedProfile[expiryField] as string ?? "") : "";
                                const storedExpiry = expiryField ? (guardProfile[expiryField as keyof GuardProfile] as string | null) : null;
                                return (
                                  <div
                                    key={field}
                                    className={cn(
                                      "flex items-center justify-between p-5 rounded-2xl border-2 transition-all",
                                      url
                                        ? "bg-white border-slate-100 hover:border-primary/30"
                                        : "bg-slate-50 border-slate-100 opacity-60 grayscale"
                                    )}
                                  >
                                    <div className="flex items-center gap-4 flex-1 min-w-0">
                                      <div className={cn("w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0", url ? iconColor : "bg-slate-200 text-slate-400")}>
                                        <FileText className="h-5 w-5" />
                                      </div>
                                      <div className="min-w-0">
                                        <p className="text-sm font-bold text-slate-800 truncate">{label}</p>
                                        {url ? (
                                          <>
                                            <p className="text-[10px] text-primary font-bold uppercase tracking-widest mt-0.5">Verified</p>
                                            {expiryField && (
                                              <div className="flex items-center gap-1.5 mt-1">
                                                <span className="text-[10px] text-slate-400">{t.applicants.modal.guardProfile.expiryDate}:</span>
                                                {canEdit ? (
                                                  <input type="date" value={expiryValue} onChange={(e) => updateEditField(expiryField, e.target.value)}
                                                    className="text-[11px] text-slate-700 bg-white border border-slate-200 rounded px-1.5 py-0.5 focus:ring-1 focus:ring-primary/20 outline-none" />
                                                ) : (
                                                  <span className="text-[11px] text-slate-600">
                                                    {storedExpiry ? new Date(storedExpiry).toLocaleDateString(locale === "th" ? "th-TH" : "en-US") : t.applicants.modal.guardProfile.noExpiry}
                                                  </span>
                                                )}
                                              </div>
                                            )}
                                          </>
                                        ) : (
                                          <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mt-0.5">{t.applicants.modal.guardProfile.notUploaded}</p>
                                        )}
                                      </div>
                                    </div>
                                    {url ? (
                                      <button onClick={() => setPreviewUrl(url)}
                                        className="w-10 h-10 flex items-center justify-center text-blue-600 bg-blue-50 rounded-lg hover:bg-blue-100 transition-all flex-shrink-0">
                                        <ExternalLink className="h-4 w-4" />
                                      </button>
                                    ) : (
                                      <div className="w-10 h-10 flex items-center justify-center text-slate-300">
                                        <Ban className="h-4 w-4" />
                                      </div>
                                    )}
                                  </div>
                                );
                              })}
                            </div>
                          </section>

                          {/* Bank Account */}
                          <section>
                            <div className="flex items-center justify-between border-b border-slate-200 pb-4 mb-6">
                              <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                                <Landmark className="h-5 w-5 text-primary" />
                                {t.applicants.modal.guardProfile.bankSection}
                              </h3>
                            </div>
                            <div className="bg-slate-50 p-6 rounded-2xl border border-slate-100 flex flex-col md:flex-row items-center gap-6 md:gap-12">
                              <div className="flex items-center gap-4">
                                <div className="w-14 h-14 bg-primary rounded-2xl flex items-center justify-center text-white shadow-lg">
                                  <Landmark className="h-7 w-7" />
                                </div>
                                <div>
                                  <p className="text-[10px] text-slate-400 uppercase font-bold tracking-widest mb-0.5">{t.applicants.modal.guardProfile.bankName}</p>
                                  {canEdit ? (
                                    <input type="text" value={String(editedProfile.bank_name ?? "")} onChange={(e) => updateEditField("bank_name", e.target.value)}
                                      className="text-base font-bold text-slate-800 bg-white border border-slate-200 rounded-lg px-2.5 py-1 focus:ring-2 focus:ring-primary/20 outline-none" />
                                  ) : (
                                    <p className="text-base font-extrabold text-slate-900">{guardProfile.bank_name || "—"}</p>
                                  )}
                                </div>
                              </div>
                              <div className="h-px w-full md:h-12 md:w-px bg-slate-200" />
                              <div>
                                <p className="text-[10px] text-slate-400 uppercase font-bold tracking-widest mb-0.5">{t.applicants.modal.guardProfile.accountNumber}</p>
                                {canEdit ? (
                                  <input type="text" value={String(editedProfile.account_number ?? "")} onChange={(e) => updateEditField("account_number", e.target.value)}
                                    className="text-base font-bold font-mono text-slate-800 bg-white border border-slate-200 rounded-lg px-2.5 py-1 focus:ring-2 focus:ring-primary/20 outline-none tracking-wider" />
                                ) : (
                                  <p className="text-base font-bold font-mono tracking-[0.15em] text-slate-900">
                                    {"*".repeat(Math.max(0, (guardProfile.account_number ?? "").length - 4)) + (guardProfile.account_number ?? "").slice(-4)}
                                  </p>
                                )}
                              </div>
                              <div className="h-px w-full md:h-12 md:w-px bg-slate-200" />
                              <div>
                                <p className="text-[10px] text-slate-400 uppercase font-bold tracking-widest mb-0.5">{t.applicants.modal.guardProfile.accountName}</p>
                                {canEdit ? (
                                  <input type="text" value={String(editedProfile.account_name ?? "")} onChange={(e) => updateEditField("account_name", e.target.value)}
                                    className="text-base font-bold text-slate-800 bg-white border border-slate-200 rounded-lg px-2.5 py-1 focus:ring-2 focus:ring-primary/20 outline-none" />
                                ) : (
                                  <p className="text-base font-bold text-slate-900">{guardProfile.account_name || "—"}</p>
                                )}
                              </div>
                            </div>
                          </section>
                        </>
                      ) : (
                        <p className="text-sm text-slate-400 italic py-8 text-center">{t.applicants.modal.guardProfile.noProfile}</p>
                      )}
                    </>
                  )}

                  {/* Customer sections */}
                  {selectedApplicant.role === "customer" && (
                    <>
                      {isCustomerProfileLoading ? (
                        <div className="flex items-center gap-2 text-slate-400 text-sm py-16 justify-center">
                          <Loader2 className="h-5 w-5 animate-spin" />
                          {t.applicants.modal.customerProfile.loadingProfile}
                        </div>
                      ) : customerProfile ? (
                        <section>
                          <div className="flex items-center justify-between border-b border-slate-200 pb-4 mb-6">
                            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                              <Building2 className="h-5 w-5 text-primary" />
                              {t.applicants.modal.customerProfile.companyInfo}
                            </h3>
                          </div>
                          <div className="grid grid-cols-2 gap-4">
                            <div className="p-4 bg-slate-50 rounded-xl">
                              <p className="text-[10px] text-slate-400 uppercase tracking-wider font-bold mb-1">{t.applicants.modal.customerProfile.fullName}</p>
                              <p className="text-sm font-bold text-slate-800">{customerProfile.full_name || "—"}</p>
                            </div>
                            <div className="p-4 bg-slate-50 rounded-xl">
                              <p className="text-[10px] text-slate-400 uppercase tracking-wider font-bold mb-1">{t.applicants.modal.customerProfile.contactPhone}</p>
                              <p className="text-sm font-bold text-slate-800">{customerProfile.contact_phone || "—"}</p>
                            </div>
                            <div className="p-4 bg-slate-50 rounded-xl">
                              <p className="text-[10px] text-slate-400 uppercase tracking-wider font-bold mb-1">{t.applicants.modal.customerProfile.email}</p>
                              <p className="text-sm font-bold text-slate-800">{customerProfile.email || "—"}</p>
                            </div>
                            <div className="p-4 bg-slate-50 rounded-xl">
                              <p className="text-[10px] text-slate-400 uppercase tracking-wider font-bold mb-1">{t.applicants.modal.customerProfile.companyName}</p>
                              <p className="text-sm font-bold text-slate-800">{customerProfile.company_name || "—"}</p>
                            </div>
                            <div className="p-4 bg-slate-50 rounded-xl col-span-2">
                              <p className="text-[10px] text-slate-400 uppercase tracking-wider font-bold mb-1 flex items-center gap-1">
                                <MapPin className="h-3 w-3" />
                                {t.applicants.modal.customerProfile.address}
                              </p>
                              <p className="text-sm font-bold text-slate-800">{customerProfile.address || "—"}</p>
                            </div>
                          </div>
                        </section>
                      ) : (
                        <p className="text-sm text-slate-400 italic py-8 text-center">{t.applicants.modal.customerProfile.noProfile}</p>
                      )}
                    </>
                  )}

                  {/* No role warning */}
                  {!selectedApplicant.role && (
                    <div className="flex items-start gap-3 p-4 bg-amber-50 border border-amber-200 rounded-xl">
                      <AlertCircle className="h-5 w-5 text-amber-600 flex-shrink-0 mt-0.5" />
                      <p className="text-sm text-amber-700 font-medium">{t.applicants.modal.awaitingRole}</p>
                    </div>
                  )}

                  {/* Approved note */}
                  {selectedApplicant.approval_status === "approved" &&
                    (selectedApplicant.role === "guard" || selectedApplicant.role === "customer") && (
                      <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
                        <p className="text-sm text-emerald-700 font-medium flex items-center gap-2">
                          <Check className="h-4 w-4" />
                          {t.applicants.approvedNote[selectedApplicant.role]}
                        </p>
                      </div>
                    )}
                </div>
              </div>
            </div>
          </div>

          {/* Mobile action buttons (sticky bottom) */}
          {selectedApplicant.approval_status === "pending" &&
          (selectedApplicant.role === "guard" || selectedApplicant.role === "customer") && (
            <div className="md:hidden p-4 bg-slate-50 border-t border-slate-100 flex gap-3">
              <button onClick={() => handleReject(selectedApplicant.id)} disabled={isActionLoading || isSaving}
                className="flex-1 py-2.5 bg-white border-2 border-red-200 text-red-600 rounded-xl text-sm font-bold flex items-center justify-center gap-2 disabled:opacity-50">
                <Ban className="h-4 w-4" /> {t.applicants.modal.reject}
              </button>
              <button onClick={() => handleApprove(selectedApplicant.id)} disabled={isActionLoading || isSaving}
                className="flex-1 py-2.5 bg-primary text-white rounded-xl text-sm font-bold shadow-lg flex items-center justify-center gap-2 disabled:opacity-50">
                <Check className="h-4 w-4" /> {t.applicants.modal.approve}
              </button>
            </div>
          )}
        </div>

        {/* Document preview lightbox */}
        {previewUrl && (
          <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4" onClick={() => setPreviewUrl(null)}>
            <div className="relative max-w-4xl w-full flex flex-col items-center" onClick={(e) => e.stopPropagation()}>
              <div className="flex gap-3 mb-4">
                <a href={previewUrl} target="_blank" rel="noopener noreferrer"
                  className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white text-sm font-medium backdrop-blur-sm flex items-center gap-2">
                  <ExternalLink className="h-4 w-4" /> Open
                </a>
                <button onClick={() => setPreviewUrl(null)}
                  className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white text-sm font-medium backdrop-blur-sm">
                  <X className="h-4 w-4" />
                </button>
              </div>
              <img src={previewUrl} alt="Document" className="max-h-[85vh] rounded-lg object-contain" />
            </div>
          </div>
        )}
      </div>
    );
  }

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
            {tab.badge != null && tab.badge > 0 && (
              <span className={cn(
                "ml-1 min-w-[20px] h-5 px-1.5 rounded-full text-xs font-bold flex items-center justify-center",
                activeTab === tab.key
                  ? "bg-white/25 text-white"
                  : "bg-amber-100 text-amber-700"
              )}>
                {tab.badge}
              </span>
            )}
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

      {/* Bulk action bar — appears when at least one pending row is checked */}
      {selectedIds.size > 0 && (
        <div className="flex items-center justify-between gap-4 rounded-xl bg-emerald-50 border border-emerald-200 px-4 py-3 text-sm">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-emerald-700">
              {locale === "th"
                ? `เลือก ${selectedIds.size} รายการ`
                : `${selectedIds.size} selected`}
            </span>
            {bulkError && <span className="text-red-600">• {bulkError}</span>}
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setSelectedIds(new Set())}
              disabled={bulkInFlight}
              className="px-3 py-1.5 rounded-lg text-slate-600 hover:bg-white transition-colors text-sm"
            >
              {locale === "th" ? "ล้าง" : "Clear"}
            </button>
            <button
              onClick={() => runBulk("rejected")}
              disabled={bulkInFlight}
              className="px-3 py-1.5 rounded-lg bg-white border border-red-300 text-red-700 text-sm font-medium hover:bg-red-50 transition-colors disabled:opacity-50"
            >
              {locale === "th" ? "ปฏิเสธทั้งหมด" : "Reject all"}
            </button>
            <button
              onClick={() => runBulk("approved")}
              disabled={bulkInFlight}
              className="px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 transition-colors inline-flex items-center gap-2 disabled:opacity-50"
            >
              {bulkInFlight && (
                <Loader2 className="h-3.5 w-3.5 animate-spin" />
              )}
              {locale === "th" ? "อนุมัติทั้งหมด" : "Approve all"}
            </button>
          </div>
        </div>
      )}

      {/* Table */}
      {!isLoading && !error && (
        <div>
          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm w-full">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="bg-slate-50/80 border-b border-slate-200">
                    <th className="w-10 py-4 px-4">
                      <input
                        type="checkbox"
                        className="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
                        disabled={pendingVisibleIds.length === 0}
                        checked={
                          pendingVisibleIds.length > 0 &&
                          pendingVisibleIds.every((id) => selectedIds.has(id))
                        }
                        onChange={toggleSelectAll}
                        aria-label="Select all pending"
                      />
                    </th>
                    <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                      {t.applicants.table.applicant}
                    </th>
                    {(
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                        {t.applicants.table.phone}
                      </th>
                    )}
                    <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                      {t.applicants.table.type}
                    </th>
                    {(
                      <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                        {t.applicants.table.appliedDate}
                      </th>
                    )}
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
                    const isPending = applicant.approval_status === "pending";
                    return (
                      <tr
                        key={applicant.id}
                        onClick={() => setSelectedApplicant(applicant)}
                        className="hover:bg-slate-50/50 transition-colors group cursor-pointer"
                      >
                        {/* Bulk-select checkbox — disabled for non-pending rows */}
                        <td
                          className="py-4 px-4"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <input
                            type="checkbox"
                            className="h-4 w-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed"
                            disabled={!isPending}
                            checked={selectedIds.has(applicant.id)}
                            onChange={() => toggleSelected(applicant.id)}
                            aria-label={`Select ${applicant.full_name}`}
                          />
                        </td>
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
                            <div className="min-w-0">
                              <p className="font-semibold text-slate-900 truncate">{applicant.full_name}</p>
                              <p className="text-xs text-slate-400 truncate">{applicant.email}</p>
                            </div>
                          </div>
                        </td>
                        {/* Phone (hidden when panel open) */}
                        {(
                          <td className="py-4 px-5">
                            <p className="text-sm text-slate-600">{applicant.phone}</p>
                          </td>
                        )}
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
                        {/* Applied date (hidden when panel open) */}
                        {(
                          <td className="py-4 px-5">
                            <p className="text-sm text-slate-500">{formatDate(applicant.created_at)}</p>
                          </td>
                        )}
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
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedApplicant(applicant);
                            }}
                            className="p-2.5 rounded-xl transition-all group-hover:shadow-sm bg-slate-100 hover:bg-primary hover:text-white"
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

        </div>
      )}
    </div>
  );
}
