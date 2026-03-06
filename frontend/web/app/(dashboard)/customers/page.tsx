"use client";

import { useState, useEffect, useCallback } from "react";
import {
  Users,
  UserCheck,
  Search,
  Eye,
  X,
  Phone,
  Mail,
  Calendar,
  Loader2,
  RefreshCw,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { authApi, type UserResponse, type CustomerProfile } from "@/lib/api";

export default function CustomersPage() {
  const { t } = useLanguage();

  const [customers, setCustomers] = useState<UserResponse[]>([]);
  const [total, setTotal] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  const [selectedCustomer, setSelectedCustomer] = useState<UserResponse | null>(
    null
  );
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [customerProfile, setCustomerProfile] = useState<CustomerProfile | null>(null);
  const [isProfileLoading, setIsProfileLoading] = useState(false);

  // Fetch approved customers from backend
  const fetchCustomers = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const params: Record<string, string | number> = {
        role: "customer",
        approval_status: "approved",
        limit: 100,
      };
      if (searchQuery.trim()) params.search = searchQuery.trim();
      const result = await authApi.listUsers(
        params as Parameters<typeof authApi.listUsers>[0]
      );
      setCustomers(result.users);
      setTotal(result.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsLoading(false);
    }
  }, [searchQuery]);

  useEffect(() => {
    const debounce = setTimeout(fetchCustomers, 300);
    return () => clearTimeout(debounce);
  }, [fetchCustomers]);

  const stats = {
    total,
    active: customers.filter((c) => c.is_active).length,
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

  const openModal = (customer: UserResponse) => {
    setSelectedCustomer(customer);
    setIsModalOpen(true);
    setCustomerProfile(null);
    setIsProfileLoading(true);
    authApi.getCustomerProfile(customer.id)
      .then(setCustomerProfile)
      .catch(() => setCustomerProfile(null))
      .finally(() => setIsProfileLoading(false));
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setSelectedCustomer(null);
    setCustomerProfile(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">
          {t.customers.title}
        </h1>
        <p className="text-slate-500 mt-1">{t.customers.subtitle}</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">
                {t.customers.totalCustomers}
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
                {t.customers.activeCustomers}
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
      </div>

      {/* Search */}
      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
          <input
            type="text"
            placeholder={t.customers.searchPlaceholder}
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
          <p className="text-slate-500">{t.customers.loading}</p>
        </div>
      )}

      {error && (
        <div className="py-12 text-center">
          <p className="text-red-500 font-medium mb-2">
            {t.customers.errorLoading}
          </p>
          <button
            onClick={fetchCustomers}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-primary hover:bg-primary/10 rounded-lg transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            {t.customers.retry}
          </button>
        </div>
      )}

      {/* Customers Table */}
      {!isLoading && !error && (
        <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-200">
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.customers.table.customer}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.customers.table.phone}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.customers.table.email}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.customers.table.status}
                  </th>
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.customers.table.joined}
                  </th>
                  <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.customers.table.actions}
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {customers.map((customer) => (
                  <tr
                    key={customer.id}
                    className="hover:bg-slate-50/50 transition-colors group"
                  >
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-100 to-blue-50 flex items-center justify-center flex-shrink-0">
                          <span className="text-sm font-bold text-blue-700">
                            {getInitials(customer.full_name || "?")}
                          </span>
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900">
                            {customer.full_name || "-"}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-600 font-medium">
                        {customer.phone}
                      </p>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-500">
                        {customer.email || "-"}
                      </p>
                    </td>
                    <td className="py-4 px-5">
                      <span
                        className={cn(
                          "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                          customer.is_active
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-slate-100 text-slate-500"
                        )}
                      >
                        <span
                          className={cn(
                            "w-1.5 h-1.5 rounded-full",
                            customer.is_active
                              ? "bg-emerald-500"
                              : "bg-slate-400"
                          )}
                        />
                        {customer.is_active
                          ? t.customers.statusActive
                          : t.customers.statusInactive}
                      </span>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-500">
                        {formatDate(customer.created_at)}
                      </p>
                    </td>
                    <td className="py-4 px-5 text-right">
                      <button
                        onClick={() => openModal(customer)}
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

          {customers.length === 0 && (
            <div className="py-16 text-center">
              <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                <Users className="h-8 w-8 text-slate-400" />
              </div>
              <p className="text-slate-500 font-medium">
                {t.customers.noCustomersFound}
              </p>
            </div>
          )}
        </div>
      )}

      {/* Customer Profile Modal */}
      {isModalOpen && selectedCustomer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 w-full max-w-lg overflow-hidden animate-in fade-in zoom-in duration-200">
            {/* Modal header */}
            <div className="flex items-center justify-between p-6 border-b border-slate-100">
              <h2 className="text-xl font-bold text-slate-900">
                {t.customers.modal.profileTitle}
              </h2>
              <button
                onClick={closeModal}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            {/* Modal body */}
            <div className="p-6 space-y-6">
              {/* Customer header */}
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-blue-100 to-blue-50 flex items-center justify-center">
                  <span className="text-xl font-bold text-blue-700">
                    {getInitials(selectedCustomer.full_name || "?")}
                  </span>
                </div>
                <div>
                  <h3 className="text-lg font-bold text-slate-900">
                    {selectedCustomer.full_name || "-"}
                  </h3>
                  <div className="flex items-center gap-2 mt-1">
                    <span
                      className={cn(
                        "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold",
                        selectedCustomer.is_active
                          ? "bg-emerald-100 text-emerald-700"
                          : "bg-slate-100 text-slate-500"
                      )}
                    >
                      <span
                        className={cn(
                          "w-1.5 h-1.5 rounded-full",
                          selectedCustomer.is_active
                            ? "bg-emerald-500"
                            : "bg-slate-400"
                        )}
                      />
                      {selectedCustomer.is_active
                        ? t.customers.statusActive
                        : t.customers.statusInactive}
                    </span>
                  </div>
                </div>
              </div>

              {/* Contact info */}
              <div className="bg-slate-50 rounded-xl p-4 space-y-3">
                <h4 className="text-sm font-bold text-slate-700">
                  {t.customers.modal.contactInfo}
                </h4>
                <div className="space-y-3">
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Phone className="h-4 w-4 text-slate-400" />
                    {selectedCustomer.phone}
                  </div>
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Mail className="h-4 w-4 text-slate-400" />
                    {selectedCustomer.email || "-"}
                  </div>
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <Calendar className="h-4 w-4 text-slate-400" />
                    <span className="text-slate-400">
                      {t.customers.modal.memberSince}:
                    </span>{" "}
                    {formatDate(selectedCustomer.created_at)}
                  </div>
                </div>
              </div>

              {/* Customer Profile — Company & Address */}
              {isProfileLoading ? (
                <div className="flex items-center gap-2 text-slate-400 text-sm">
                  <Loader2 className="h-4 w-4 animate-spin" />
                  {t.customers.modal.customerProfile.loadingProfile}
                </div>
              ) : customerProfile ? (
                <div className="bg-slate-50 rounded-xl p-4 space-y-3">
                  <h4 className="text-sm font-bold text-slate-700">
                    {t.customers.modal.customerProfile.companyInfo}
                  </h4>
                  <div className="space-y-3">
                    {customerProfile.company_name && (
                      <div>
                        <p className="text-xs text-slate-400 mb-0.5">{t.customers.modal.customerProfile.companyName}</p>
                        <p className="text-sm font-medium text-slate-800">{customerProfile.company_name}</p>
                      </div>
                    )}
                    <div>
                      <p className="text-xs text-slate-400 mb-0.5">{t.customers.modal.customerProfile.address}</p>
                      <p className="text-sm font-medium text-slate-800">{customerProfile.address}</p>
                    </div>
                  </div>
                </div>
              ) : (
                <p className="text-sm text-slate-400 italic">
                  {t.customers.modal.customerProfile.noProfile}
                </p>
              )}
            </div>

            {/* Modal footer */}
            <div className="p-4 border-t border-slate-100 flex justify-end">
              <button
                onClick={closeModal}
                className="px-6 py-2.5 bg-slate-100 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-200 transition-colors"
              >
                {t.customers.modal.close}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
