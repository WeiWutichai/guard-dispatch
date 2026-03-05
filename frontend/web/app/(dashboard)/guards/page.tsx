"use client";

import { useState, useEffect, useCallback } from "react";
import {
  Users,
  Search,
  Phone,
  Mail,
  Eye,
  X,
  Shield,
  UserCheck,
  UserX,
  Calendar,
  Briefcase,
  Landmark,
  CreditCard,
  FileText,
  Loader2,
  RefreshCw,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { authApi, type UserResponse, type GuardProfile } from "@/lib/api";

export default function GuardsPage() {
  const { t } = useLanguage();

  const [guards, setGuards] = useState<UserResponse[]>([]);
  const [total, setTotal] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  const [selectedGuard, setSelectedGuard] = useState<UserResponse | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [guardProfile, setGuardProfile] = useState<GuardProfile | null>(null);
  const [isProfileLoading, setIsProfileLoading] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [previewLabel, setPreviewLabel] = useState("");

  // Fetch approved guards from backend
  const fetchGuards = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const params: Record<string, string | number> = {
        role: "guard",
        approval_status: "approved",
        limit: 100,
      };
      if (searchQuery.trim()) params.search = searchQuery.trim();
      const result = await authApi.listUsers(
        params as Parameters<typeof authApi.listUsers>[0]
      );
      setGuards(result.users);
      setTotal(result.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsLoading(false);
    }
  }, [searchQuery]);

  useEffect(() => {
    const debounce = setTimeout(fetchGuards, 300);
    return () => clearTimeout(debounce);
  }, [fetchGuards]);

  // Load guard profile when modal opens
  useEffect(() => {
    if (isModalOpen && selectedGuard) {
      setGuardProfile(null);
      setIsProfileLoading(true);
      authApi
        .getGuardProfile(selectedGuard.id)
        .then(setGuardProfile)
        .catch(() => setGuardProfile(null))
        .finally(() => setIsProfileLoading(false));
    } else {
      setGuardProfile(null);
    }
  }, [isModalOpen, selectedGuard]);

  const stats = {
    total,
    active: guards.filter((g) => g.is_active).length,
    inactive: guards.filter((g) => !g.is_active).length,
  };

  const getInitials = (name: string) => {
    const parts = name.trim().split(" ");
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.slice(0, 2).toUpperCase();
  };

  const formatDate = (dateStr: string) => {
    try {
      return new Date(dateStr).toLocaleDateString("th-TH", {
        year: "numeric",
        month: "short",
        day: "numeric",
      });
    } catch {
      return dateStr;
    }
  };

  const openModal = (guard: UserResponse) => {
    setSelectedGuard(guard);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setSelectedGuard(null);
    setPreviewUrl(null);
  };

  // Document definitions for guard profile modal
  const docEntries = (gp: GuardProfile) => [
    { label: t.guards.modal.docIdCard, url: gp.id_card_url },
    { label: t.guards.modal.docSecurityLicense, url: gp.security_license_url },
    { label: t.guards.modal.docTrainingCert, url: gp.training_cert_url },
    { label: t.guards.modal.docCriminalCheck, url: gp.criminal_check_url },
    { label: t.guards.modal.docDriverLicense, url: gp.driver_license_url },
    { label: t.guards.modal.passbookPhoto, url: gp.passbook_photo_url },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">{t.guards.title}</h1>
        <p className="text-slate-500 mt-1">{t.guards.subtitle}</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">
                {t.guards.totalGuards}
              </p>
              <p className="text-3xl font-bold text-slate-900 mt-1">
                {stats.total}
              </p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Users className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-2xl border border-emerald-100 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600">
                {t.guards.activeGuards}
              </p>
              <p className="text-3xl font-bold text-emerald-700 mt-1">
                {stats.active}
              </p>
            </div>
            <div className="p-3 bg-emerald-100 rounded-xl">
              <UserCheck className="h-6 w-6 text-emerald-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">
                {t.guards.inactiveGuards}
              </p>
              <p className="text-3xl font-bold text-slate-900 mt-1">
                {stats.inactive}
              </p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <UserX className="h-6 w-6 text-slate-400" />
            </div>
          </div>
        </div>
      </div>

      {/* Search */}
      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
          <input
            type="text"
            placeholder={t.guards.searchPlaceholder}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 pl-12 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
          />
        </div>
      </div>

      {/* Loading / Error */}
      {isLoading && (
        <div className="py-12 text-center">
          <Loader2 className="h-8 w-8 text-primary mx-auto mb-3 animate-spin" />
          <p className="text-slate-500">{t.guards.loading}</p>
        </div>
      )}

      {error && (
        <div className="py-12 text-center">
          <p className="text-red-500 font-medium mb-2">
            {t.guards.errorLoading}
          </p>
          <button
            onClick={fetchGuards}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-primary hover:bg-primary/10 rounded-lg transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            {t.guards.retry}
          </button>
        </div>
      )}

      {/* Guards Table */}
      {!isLoading && !error && (
        <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-200">
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.guards.table.guard}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.guards.table.phone}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.guards.table.joined}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.guards.table.status}
                  </th>
                  <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.guards.table.actions}
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {guards.map((guard) => (
                  <tr
                    key={guard.id}
                    className="hover:bg-slate-50/50 transition-colors group"
                  >
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-amber-100 to-amber-50 flex items-center justify-center flex-shrink-0">
                          <span className="text-sm font-bold text-amber-700">
                            {getInitials(guard.full_name || "?")}
                          </span>
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900">
                            {guard.full_name || "-"}
                          </p>
                          <p className="text-xs text-slate-400">
                            {guard.email || guard.phone}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-600 font-medium">
                        {guard.phone}
                      </p>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-500">
                        {formatDate(guard.created_at)}
                      </p>
                    </td>
                    <td className="py-4 px-5">
                      <span
                        className={cn(
                          "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                          guard.is_active
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-slate-100 text-slate-500"
                        )}
                      >
                        <span
                          className={cn(
                            "w-1.5 h-1.5 rounded-full",
                            guard.is_active ? "bg-emerald-500" : "bg-slate-400"
                          )}
                        />
                        {guard.is_active
                          ? t.guards.statusActive
                          : t.guards.statusInactive}
                      </span>
                    </td>
                    <td className="py-4 px-5 text-right">
                      <button
                        onClick={() => openModal(guard)}
                        className="p-2.5 bg-slate-100 hover:bg-primary hover:text-white rounded-xl transition-all group-hover:shadow-sm"
                      >
                        <Eye className="h-4 w-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {guards.length === 0 && (
            <div className="py-16 text-center">
              <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <Users className="h-8 w-8 text-slate-400" />
              </div>
              <p className="text-slate-500 font-medium">
                {t.guards.noGuardsFound}
              </p>
            </div>
          )}
        </div>
      )}

      {/* Guard Profile Modal */}
      {isModalOpen && selectedGuard && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 w-full max-w-2xl max-h-[90vh] overflow-hidden animate-in fade-in zoom-in duration-200 flex flex-col">
            {/* Modal header */}
            <div className="flex items-center justify-between p-6 border-b border-slate-100">
              <h2 className="text-xl font-bold text-slate-900">
                {t.guards.modal.profileTitle}
              </h2>
              <button
                onClick={closeModal}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            {/* Modal body */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6">
              {/* Guard header */}
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-amber-100 to-amber-50 flex items-center justify-center">
                  <span className="text-xl font-bold text-amber-700">
                    {getInitials(selectedGuard.full_name || "?")}
                  </span>
                </div>
                <div>
                  <h3 className="text-lg font-bold text-slate-900">
                    {selectedGuard.full_name || "-"}
                  </h3>
                  <div className="flex items-center gap-2 mt-1">
                    <span
                      className={cn(
                        "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold",
                        selectedGuard.is_active
                          ? "bg-emerald-100 text-emerald-700"
                          : "bg-slate-100 text-slate-500"
                      )}
                    >
                      <span
                        className={cn(
                          "w-1.5 h-1.5 rounded-full",
                          selectedGuard.is_active
                            ? "bg-emerald-500"
                            : "bg-slate-400"
                        )}
                      />
                      {selectedGuard.is_active
                        ? t.guards.statusActive
                        : t.guards.statusInactive}
                    </span>
                    <span className="text-xs text-slate-400">
                      {formatDate(selectedGuard.created_at)}
                    </span>
                  </div>
                </div>
              </div>

              {/* Contact info */}
              <div className="bg-slate-50 rounded-xl p-4 space-y-3">
                <h4 className="text-sm font-bold text-slate-700">
                  {t.guards.modal.contactInfo}
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Phone className="h-4 w-4 text-slate-400" />
                    {selectedGuard.phone}
                  </div>
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Mail className="h-4 w-4 text-slate-400" />
                    {selectedGuard.email || "-"}
                  </div>
                </div>
              </div>

              {/* Guard profile data */}
              {isProfileLoading && (
                <div className="py-8 text-center">
                  <Loader2 className="h-6 w-6 text-primary mx-auto mb-2 animate-spin" />
                  <p className="text-sm text-slate-500">
                    {t.guards.modal.loadingProfile}
                  </p>
                </div>
              )}

              {!isProfileLoading && !guardProfile && (
                <div className="py-8 text-center">
                  <p className="text-sm text-slate-400">
                    {t.guards.modal.noProfile}
                  </p>
                </div>
              )}

              {guardProfile && (
                <>
                  {/* Personal info */}
                  <div className="bg-slate-50 rounded-xl p-4 space-y-3">
                    <h4 className="text-sm font-bold text-slate-700">
                      {t.guards.modal.personalInfo}
                    </h4>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      {guardProfile.gender && (
                        <div className="flex items-center gap-2 text-sm text-slate-600">
                          <Shield className="h-4 w-4 text-slate-400" />
                          <span className="text-slate-400">
                            {t.guards.modal.gender}:
                          </span>{" "}
                          {guardProfile.gender}
                        </div>
                      )}
                      {guardProfile.date_of_birth && (
                        <div className="flex items-center gap-2 text-sm text-slate-600">
                          <Calendar className="h-4 w-4 text-slate-400" />
                          <span className="text-slate-400">
                            {t.guards.modal.dateOfBirth}:
                          </span>{" "}
                          {formatDate(guardProfile.date_of_birth)}
                        </div>
                      )}
                      {guardProfile.years_of_experience != null && (
                        <div className="flex items-center gap-2 text-sm text-slate-600">
                          <Briefcase className="h-4 w-4 text-slate-400" />
                          <span className="text-slate-400">
                            {t.guards.modal.yearsExp}:
                          </span>{" "}
                          {guardProfile.years_of_experience}
                        </div>
                      )}
                      {guardProfile.previous_workplace && (
                        <div className="flex items-center gap-2 text-sm text-slate-600">
                          <Briefcase className="h-4 w-4 text-slate-400" />
                          <span className="text-slate-400">
                            {t.guards.modal.workplace}:
                          </span>{" "}
                          {guardProfile.previous_workplace}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Documents */}
                  <div className="bg-slate-50 rounded-xl p-4 space-y-3">
                    <h4 className="text-sm font-bold text-slate-700">
                      {t.guards.modal.documentsSection}
                    </h4>
                    <div className="space-y-2">
                      {docEntries(guardProfile).map((doc) => (
                        <div
                          key={doc.label}
                          className="flex items-center justify-between py-2"
                        >
                          <div className="flex items-center gap-2">
                            <FileText className="h-4 w-4 text-slate-400" />
                            <span className="text-sm text-slate-600">
                              {doc.label}
                            </span>
                          </div>
                          {doc.url ? (
                            <button
                              onClick={() => {
                                setPreviewLabel(doc.label);
                                setPreviewUrl(doc.url!);
                              }}
                              className="text-xs font-semibold text-primary hover:text-emerald-700 transition-colors"
                            >
                              {t.guards.modal.viewDocument}
                            </button>
                          ) : (
                            <span className="text-xs text-slate-400">
                              {t.guards.modal.notUploaded}
                            </span>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Bank account */}
                  {(guardProfile.bank_name ||
                    guardProfile.account_number ||
                    guardProfile.account_name) && (
                    <div className="bg-slate-50 rounded-xl p-4 space-y-3">
                      <h4 className="text-sm font-bold text-slate-700">
                        {t.guards.modal.bankSection}
                      </h4>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        {guardProfile.bank_name && (
                          <div className="flex items-center gap-2 text-sm text-slate-600">
                            <Landmark className="h-4 w-4 text-slate-400" />
                            <span className="text-slate-400">
                              {t.guards.modal.bankName}:
                            </span>{" "}
                            {guardProfile.bank_name}
                          </div>
                        )}
                        {guardProfile.account_number && (
                          <div className="flex items-center gap-2 text-sm text-slate-600">
                            <CreditCard className="h-4 w-4 text-slate-400" />
                            <span className="text-slate-400">
                              {t.guards.modal.accountNumber}:
                            </span>{" "}
                            {guardProfile.account_number}
                          </div>
                        )}
                        {guardProfile.account_name && (
                          <div className="flex items-center gap-2 text-sm text-slate-600">
                            <Shield className="h-4 w-4 text-slate-400" />
                            <span className="text-slate-400">
                              {t.guards.modal.accountName}:
                            </span>{" "}
                            {guardProfile.account_name}
                          </div>
                        )}
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Modal footer */}
            <div className="p-4 border-t border-slate-100 flex justify-end">
              <button
                onClick={closeModal}
                className="px-6 py-2.5 bg-slate-100 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-200 transition-colors"
              >
                {t.guards.modal.close}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Document Preview Lightbox */}
      {previewUrl && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-slate-900/80 backdrop-blur-md">
          <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col animate-in fade-in zoom-in duration-200">
            <div className="flex items-center justify-between p-4 border-b border-slate-100">
              <h3 className="text-lg font-bold text-slate-900">
                {previewLabel}
              </h3>
              <button
                onClick={() => setPreviewUrl(null)}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="flex-1 overflow-auto p-4 bg-slate-100 flex items-center justify-center">
              <img
                src={previewUrl}
                alt={previewLabel}
                className="max-w-full h-auto rounded-lg shadow-lg border border-slate-200"
              />
            </div>
            <div className="p-4 border-t border-slate-100 flex justify-end">
              <button
                onClick={() => setPreviewUrl(null)}
                className="px-6 py-2 bg-slate-200 text-slate-700 rounded-lg text-sm font-bold hover:bg-slate-300 transition-colors"
              >
                {t.guards.modal.close}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
