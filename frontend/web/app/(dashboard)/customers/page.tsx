"use client";

import { useState } from "react";
import {
  Users,
  UserCheck,
  UserPlus,
  Search,
  Eye,
  Star,
  X,
  Mail,
  Calendar,
  ChevronDown,
  User,
  AlertCircle,
  Shield,
  CreditCard,
  Phone,
  CheckCircle2,
  UserX,
  RotateCcw,
  Trash2,
  Send,
  Activity,
  Building2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

type CustomerStatus = "active" | "pending" | "suspended";

interface Booking {
  id: string;
  dateTime: string;
  assignedGuard: string;
  serviceType: string;
  status: "completed" | "canceled" | "in-progress";
}

interface Customer {
  id: string;
  name: string;
  phone: string;
  email: string;
  status: CustomerStatus;
  companyName?: string;
  bookings: number;
  rating: number;
  memberSince: string;
  bookingHistory?: Booking[];
}

const sampleBookings: Booking[] = [
  { id: "B001", dateTime: "9/8/2567", assignedGuard: "วิไล ปลอดภัย", serviceType: "บอดี้การ์ด", status: "canceled" },
  { id: "B002", dateTime: "25/12/2567", assignedGuard: "สมหญิง เก่งกาจ", serviceType: "รักษาความปลอดภัยงาน", status: "completed" },
  { id: "B003", dateTime: "23/2/2567", assignedGuard: "นิรันดร์ รักงาน", serviceType: "บอดี้การ์ด", status: "completed" },
  { id: "B004", dateTime: "1/5/2567", assignedGuard: "อนุชา ใจดี", serviceType: "เฝ้าบ้าน", status: "completed" },
  { id: "B005", dateTime: "3/11/2567", assignedGuard: "วิไล ใจดี", serviceType: "รักษาความปลอดภัยงาน", status: "completed" },
  { id: "B006", dateTime: "11/7/2567", assignedGuard: "สุดา พิทักษ์", serviceType: "รักษาความปลอดภัยงาน", status: "completed" },
  { id: "B007", dateTime: "17/5/2567", assignedGuard: "สมชาย ใจดี", serviceType: "รักษาความปลอดภัยงาน", status: "in-progress" },
  { id: "B008", dateTime: "10/7/2567", assignedGuard: "วิไล ชื่อสัตย์", serviceType: "เฝ้าบ้าน", status: "completed" },
];

const initialCustomers: Customer[] = [
  { id: "C001", name: "สุดา เก่งกาจ", phone: "0828069033", email: "customer1@example.com", status: "active", companyName: "บริษัท เอสจี เซอร์วิส จำกัด", bookings: 12, rating: 4.9, memberSince: "15/1/2567", bookingHistory: sampleBookings },
  { id: "C002", name: "นิรันดร์ กล้าหาญ", phone: "0804353134", email: "customer2@example.com", status: "pending", companyName: "ไทยแลนด์ ซีเคียวริตี้ คอร์ป", bookings: 9, rating: 3.2, memberSince: "20/2/2567", bookingHistory: sampleBookings.slice(0, 4) },
  { id: "C003", name: "นิรันดร์ มั่นคง", phone: "0867623617", email: "customer3@example.com", status: "pending", bookings: 10, rating: 3.9, memberSince: "5/3/2567", bookingHistory: sampleBookings.slice(2, 6) },
  { id: "C004", name: "สมหญิง ปลอดภัย", phone: "0819937267", email: "customer4@example.com", status: "active", companyName: "เบสท์ การ์ด เรียลตี้", bookings: 9, rating: 3.2, memberSince: "12/1/2567", bookingHistory: sampleBookings.slice(1, 4) },
  { id: "C005", name: "วิทยา เก่งกาจ", phone: "0833149636", email: "customer5@example.com", status: "active", bookings: 9, rating: 4.8, memberSince: "8/4/2567", bookingHistory: sampleBookings.slice(0, 3) },
  { id: "C006", name: "วิไล ใจดี", phone: "0868573407", email: "customer6@example.com", status: "suspended", bookings: 19, rating: 3.6, memberSince: "1/5/2567" },
  { id: "C007", name: "ประยุทธ์ ชื่อสัตย์", phone: "0892619734", email: "customer7@example.com", status: "suspended", bookings: 2, rating: 4.0, memberSince: "25/6/2567" },
  { id: "C008", name: "มานะ ขยันดี", phone: "0845678901", email: "customer8@example.com", status: "active", bookings: 15, rating: 4.5, memberSince: "10/7/2567" },
];

const statusConfig: Record<CustomerStatus, { label: { th: string; en: string }; color: string; bg: string }> = {
  active: { label: { th: "ระงับ", en: "Active" }, color: "text-emerald-700", bg: "bg-emerald-100" },
  pending: { label: { th: "รอดำเนินการ", en: "Pending" }, color: "text-amber-700", bg: "bg-amber-100" },
  suspended: { label: { th: "ใช้งานอยู่", en: "Suspended" }, color: "text-red-700", bg: "bg-red-100" },
};

export default function CustomersPage() {
  const { t, locale } = useLanguage();
  const [customers] = useState<Customer[]>(initialCustomers);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<CustomerStatus | "all">("all");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [activeTab, setActiveTab] = useState<"info" | "bookings" | "complaints" | "actions">("info");

  const filteredCustomers = customers.filter((customer) => {
    const matchesSearch = customer.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      customer.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      customer.phone.includes(searchQuery);
    const matchesStatus = statusFilter === "all" || customer.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const stats = {
    total: customers.length,
    active: customers.filter(c => c.status === "active").length,
    newThisMonth: 12,
  };

  const openCustomerModal = (customer: Customer) => {
    setSelectedCustomer(customer);
    setActiveTab("info");
    setIsModalOpen(true);
  };

  const tabs = [
    { id: "info" as const, label: locale === "th" ? "ข้อมูลส่วนตัว" : "Personal Info", icon: User },
    { id: "bookings" as const, label: locale === "th" ? "ประวัติการจอง" : "Booking History", icon: Calendar },
    { id: "complaints" as const, label: locale === "th" ? "ข้อร้องเรียนและรายงาน" : "Complaints & Reports", icon: AlertCircle },
    { id: "actions" as const, label: locale === "th" ? "การดำเนินการบัญชี" : "Account Actions", icon: Shield },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{t.customers.title}</h1>
          <p className="text-slate-500 mt-1">{t.customers.subtitle}</p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">{t.customers.totalCustomers}</p>
              <p className="text-3xl font-bold text-slate-900 mt-1">{stats.total}</p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Users className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-2xl border border-emerald-100 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600">{t.customers.activeCustomers}</p>
              <p className="text-3xl font-bold text-emerald-700 mt-1">{stats.active}</p>
            </div>
            <div className="p-3 bg-emerald-100 rounded-xl">
              <UserCheck className="h-6 w-6 text-emerald-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-blue-50 to-white p-5 rounded-2xl border border-blue-100 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-blue-600">{t.customers.newThisMonth}</p>
              <p className="text-3xl font-bold text-blue-700 mt-1">{stats.newThisMonth}</p>
            </div>
            <div className="p-3 bg-blue-100 rounded-xl">
              <UserPlus className="h-6 w-6 text-blue-600" />
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
              placeholder={t.customers.searchPlaceholder}
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
              <span>{statusFilter === "all" ? t.customers.statusAll : statusConfig[statusFilter].label[locale]}</span>
              <ChevronDown className={cn("h-4 w-4 transition-transform", isFilterOpen && "rotate-180")} />
            </button>
            {isFilterOpen && (
              <div className="absolute right-0 mt-2 w-52 bg-white rounded-xl border border-slate-200 shadow-xl py-2 z-50">
                <button
                  onClick={() => { setStatusFilter("all"); setIsFilterOpen(false); }}
                  className={cn(
                    "w-full px-4 py-2.5 text-sm text-left transition-colors",
                    statusFilter === "all" ? "bg-primary/10 text-primary font-medium" : "text-slate-700 hover:bg-slate-50"
                  )}
                >
                  {t.customers.statusAll}
                </button>
                {(Object.keys(statusConfig) as CustomerStatus[]).map((status) => (
                  <button
                    key={status}
                    onClick={() => { setStatusFilter(status); setIsFilterOpen(false); }}
                    className={cn(
                      "w-full px-4 py-2.5 text-sm text-left transition-colors",
                      statusFilter === status ? "bg-primary/10 text-primary font-medium" : "text-slate-700 hover:bg-slate-50"
                    )}
                  >
                    {statusConfig[status].label[locale]}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Customers Table */}
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50/80 border-b border-slate-200">
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.fullName}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.phone}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.email}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.accountStatus}</th>
                <th className="text-center py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.bookings}</th>
                <th className="text-center py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.avgRating}</th>
                <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{t.customers.actions}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredCustomers.map((customer) => {
                const status = statusConfig[customer.status];
                return (
                  <tr key={customer.id} className="hover:bg-slate-50/50 transition-colors group">
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary/20 to-primary/10 flex items-center justify-center flex-shrink-0">
                          <span className="text-sm font-bold text-primary">{customer.name.charAt(0)}</span>
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900">{customer.name}</p>
                          <p className="text-xs text-slate-400">ID: {customer.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-600 font-medium">{customer.phone}</p>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-500">{customer.email}</p>
                    </td>
                    <td className="py-4 px-5">
                      <span className={cn(
                        "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                        status.bg, status.color
                      )}>
                        <span className={cn(
                          "w-1.5 h-1.5 rounded-full",
                          customer.status === "active" ? "bg-emerald-500" :
                            customer.status === "pending" ? "bg-amber-500" : "bg-red-500"
                        )}></span>
                        {status.label[locale]}
                      </span>
                    </td>
                    <td className="py-4 px-5 text-center">
                      <span className="inline-flex items-center justify-center w-8 h-8 bg-slate-100 rounded-lg text-sm font-bold text-slate-700">
                        {customer.bookings}
                      </span>
                    </td>
                    <td className="py-4 px-5">
                      <div className="flex items-center justify-center gap-1.5 bg-amber-50 rounded-lg px-3 py-1.5 w-fit mx-auto">
                        <Star className="h-4 w-4 text-amber-400 fill-amber-400" />
                        <span className="text-sm font-bold text-amber-700">{customer.rating}</span>
                      </div>
                    </td>
                    <td className="py-4 px-5 text-right">
                      <button
                        onClick={() => openCustomerModal(customer)}
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

        {filteredCustomers.length === 0 && (
          <div className="py-16 text-center">
            <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Users className="h-8 w-8 text-slate-400" />
            </div>
            <p className="text-slate-500 font-medium">{t.customers.noCustomersFound}</p>
          </div>
        )}
      </div>

      {/* Customer Profile Modal */}
      {isModalOpen && selectedCustomer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 w-full max-w-4xl max-h-[90vh] overflow-hidden animate-in fade-in zoom-in duration-200 flex flex-col">
            <div className="flex items-center justify-between p-6 border-b border-slate-100">
              <h2 className="text-xl font-bold text-slate-900">
                {t.customers.customerProfile}: {selectedCustomer.name}
              </h2>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            <div className="flex flex-col md:flex-row flex-1 min-h-0">
              {/* Sidebar */}
              <div className="w-full md:w-64 bg-slate-50 border-r border-slate-100 p-4 space-y-1">
                {tabs.map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={cn(
                      "w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all",
                      activeTab === tab.id
                        ? "bg-primary text-white shadow-lg shadow-primary/20 scale-[1.02]"
                        : "text-slate-600 hover:bg-white hover:shadow-sm"
                    )}
                  >
                    <tab.icon className={cn("h-5 w-5", activeTab === tab.id ? "text-white" : "text-slate-400")} />
                    {tab.label}
                  </button>
                ))}
              </div>

              {/* Tab Content */}
              <div className="flex-1 overflow-y-auto p-8 custom-scrollbar">
                {activeTab === "info" && (
                  <div className="space-y-8">
                    <div>
                      <h3 className="text-lg font-bold text-slate-900">Profile Settings</h3>
                      <p className="text-sm text-slate-500 mt-1">Update customer personal information</p>
                    </div>

                    {/* Avatar/Header Mockup */}
                    <div className="flex items-center gap-6 pb-8 border-b border-slate-100">
                      <div className="w-20 h-20 rounded-2xl bg-primary/10 flex items-center justify-center">
                        <User className="h-10 w-10 text-primary" />
                      </div>
                      <div>
                        <h4 className="font-bold text-slate-900 text-lg">{selectedCustomer.name}</h4>
                        <p className="text-sm text-slate-500 mt-0.5">Customer ID: {selectedCustomer.id}</p>
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div className="space-y-2">
                        <label className="text-sm font-bold text-slate-700  ml-1">{t.customers.fullName}</label>
                        <div className="relative group">
                          <User className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 group-focus-within:text-primary transition-colors" />
                          <input
                            type="text"
                            readOnly
                            value={selectedCustomer.name}
                            className="w-full pl-10 pr-4 py-3 bg-slate-50  border-none rounded-xl text-sm text-slate-900  focus:ring-2 focus:ring-primary/20 outline-none transition-all"
                          />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <label className="text-sm font-bold text-slate-700  ml-1">{t.customers.phone}</label>
                        <div className="relative group">
                          <Phone className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 group-focus-within:text-primary transition-colors" />
                          <input
                            type="text"
                            readOnly
                            value={selectedCustomer.phone}
                            className="w-full pl-10 pr-4 py-3 bg-slate-50  border-none rounded-xl text-sm text-slate-900  focus:ring-2 focus:ring-primary/20 outline-none transition-all"
                          />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <label className="text-sm font-bold text-slate-700  ml-1">{t.customers.email}</label>
                        <div className="relative group">
                          <Mail className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 group-focus-within:text-primary transition-colors" />
                          <input
                            type="text"
                            readOnly
                            value={selectedCustomer.email}
                            className="w-full pl-10 pr-4 py-3 bg-slate-50  border-none rounded-xl text-sm text-slate-900  focus:ring-2 focus:ring-primary/20 outline-none transition-all"
                          />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <label className="text-sm font-bold text-slate-700  ml-1">{t.customers.memberSince}</label>
                        <div className="relative group">
                          <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 group-focus-within:text-primary transition-colors" />
                          <input
                            type="text"
                            readOnly
                            value={selectedCustomer.memberSince}
                            className="w-full pl-10 pr-4 py-3 bg-slate-50  border-none rounded-xl text-sm text-slate-900  focus:ring-2 focus:ring-primary/20 outline-none transition-all"
                          />
                        </div>
                      </div>
                      <div className="space-y-2">
                        <label className="text-sm font-bold text-slate-700  ml-1">{t.customers.companyName}</label>
                        <div className="relative group">
                          <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 group-focus-within:text-primary transition-colors" />
                          <input
                            type="text"
                            readOnly
                            value={selectedCustomer.companyName || "-"}
                            className="w-full pl-10 pr-4 py-3 bg-slate-50  border-none rounded-xl text-sm text-slate-900  focus:ring-2 focus:ring-primary/20 outline-none transition-all"
                          />
                        </div>
                      </div>
                    </div>

                    <div className="pt-6 border-t border-slate-100  flex justify-end gap-3">
                      <button
                        onClick={() => setIsModalOpen(false)}
                        className="px-6 py-2.5 bg-primary text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-all shadow-lg shadow-primary/20 active:scale-95"
                      >
                        Save Changes
                      </button>
                    </div>
                  </div>
                )}

                {activeTab === "bookings" && (
                  <div className="space-y-4">
                    <div className="flex items-center justify-between mb-4">
                      <h3 className="text-lg font-bold text-slate-900 ">{locale === "th" ? "ประวัติการจอง" : "Booking History"}</h3>
                      <span className="px-3 py-1 bg-primary/10 text-primary text-xs font-bold rounded-lg border border-primary/20">
                        {selectedCustomer.bookingHistory?.length || 0} {locale === "th" ? "รายการ" : "Items"}
                      </span>
                    </div>

                    {!selectedCustomer.bookingHistory || selectedCustomer.bookingHistory.length === 0 ? (
                      <div className="flex flex-col items-center justify-center py-20 text-center">
                        <div className="w-16 h-16 bg-slate-100  rounded-2xl flex items-center justify-center mb-4">
                          <Calendar className="h-8 w-8 text-slate-300" />
                        </div>
                        <h3 className="text-lg font-bold text-slate-900 ">{locale === "th" ? "ไม่มีประวัติการจอง" : "No booking history"}</h3>
                        <p className="text-sm text-slate-500 mt-1 max-w-xs">This customer hasn&apos;t made any bookings yet.</p>
                      </div>
                    ) : (
                      <div className="space-y-3 pb-4">
                        {selectedCustomer.bookingHistory.map((booking) => (
                          <div key={booking.id} className="bg-white border border-slate-100 rounded-2xl p-5 shadow-sm hover:shadow-md transition-all group relative overflow-hidden">
                            {/* Accent line */}
                            <div className={cn(
                              "absolute left-0 top-0 bottom-0 w-1",
                              booking.status === "completed" ? "bg-emerald-500" :
                                booking.status === "canceled" ? "bg-red-500" :
                                  "bg-slate-400"
                            )}></div>

                            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 items-center">
                              <div className="space-y-1.5">
                                <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-700">
                                  <Calendar className="h-3.5 w-3.5 text-slate-500" />
                                  <span>{locale === "th" ? "วันที่และเวลา" : "Date & Time"}</span>
                                </div>
                                <p className="text-sm text-slate-500 pl-5">{booking.dateTime}</p>
                              </div>

                              <div className="space-y-1.5">
                                <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-700">
                                  <User className="h-3.5 w-3.5 text-slate-500" />
                                  <span>{locale === "th" ? "เจ้าหน้าที่" : "Guard"}</span>
                                </div>
                                <p className="text-sm text-emerald-600 pl-5">{booking.assignedGuard}</p>
                              </div>

                              <div className="space-y-1.5">
                                <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-700">
                                  <Shield className="h-3.5 w-3.5 text-slate-500" />
                                  <span>{locale === "th" ? "บริการ" : "Service"}</span>
                                </div>
                                <p className="text-sm text-blue-600 pl-5">{booking.serviceType}</p>
                              </div>

                              <div className="flex md:justify-end">
                                <div className="text-left md:text-right space-y-1.5">
                                  <p className="text-xs font-semibold text-slate-700">{locale === "th" ? "สถานะ" : "Status"}</p>
                                  <span className={cn(
                                    "inline-flex items-center px-3 py-1 rounded-full text-xs font-medium",
                                    booking.status === "completed" ? "bg-emerald-50 text-emerald-600" :
                                      booking.status === "canceled" ? "bg-red-50 text-red-600" :
                                        "bg-slate-100 text-slate-600"
                                  )}>
                                    <span className={cn(
                                      "h-1.5 w-1.5 rounded-full mr-2",
                                      booking.status === "completed" ? "bg-emerald-500" :
                                        booking.status === "canceled" ? "bg-red-500" :
                                          "bg-slate-500"
                                    )}></span>
                                    {booking.status === "completed" ? (locale === "th" ? "เสร็จสิ้น" : "Completed") :
                                      booking.status === "canceled" ? (locale === "th" ? "ยกเลิก" : "Canceled") :
                                        (locale === "th" ? "กำลังดำเนินการ" : "In Progress")}
                                  </span>
                                </div>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {activeTab === "complaints" && (
                  <div className="flex flex-col items-center justify-center py-20 text-center">
                    <div className="w-16 h-16 bg-slate-100  rounded-2xl flex items-center justify-center mb-4">
                      <AlertCircle className="h-8 w-8 text-slate-300" />
                    </div>
                    <h3 className="text-lg font-bold text-slate-900 ">{locale === "th" ? "ไม่มีข้อร้องเรียน" : "No complaints"}</h3>
                    <p className="text-sm text-slate-500 mt-1 max-w-xs">There are no reports or complaints for this customer.</p>
                  </div>
                )}

                {activeTab === "actions" && (
                  <div className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <button className="flex items-center justify-center gap-2 p-4 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors group">
                        <CheckCircle2 className="h-5 w-5 text-emerald-500" />
                        <span className="font-bold text-slate-700 dark:text-slate-300">{locale === "th" ? "อนุมัติ" : "Approve"}</span>
                      </button>
                      <button className="flex items-center justify-center gap-2 p-4 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors group">
                        <UserX className="h-5 w-5 text-amber-500" />
                        <span className="font-bold text-slate-700 dark:text-slate-300">{locale === "th" ? "ระงับ" : "Suspend"}</span>
                      </button>
                      <button className="flex items-center justify-center gap-2 p-4 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors group">
                        <RotateCcw className="h-5 w-5 text-slate-500" />
                        <span className="font-bold text-slate-700 dark:text-slate-300">{locale === "th" ? "รีเซ็ตรหัสผ่าน" : "Reset Password"}</span>
                      </button>
                      <button className="flex items-center justify-center gap-2 p-4 bg-red-500 border border-red-600 rounded-xl hover:bg-red-600 transition-colors group shadow-lg shadow-red-500/20">
                        <Trash2 className="h-5 w-5 text-white" />
                        <span className="font-bold text-white">{locale === "th" ? "ลบบัญชี" : "Delete Account"}</span>
                      </button>
                    </div>

                    <div className="pt-6 border-t border-slate-100 dark:border-slate-800">
                      <h3 className="text-sm font-bold text-slate-900 dark:text-white mb-4">{locale === "th" ? "ส่งข้อความ" : "Send Message"}</h3>
                      <div className="space-y-4">
                        <textarea
                          placeholder={locale === "th" ? "เขียนข้อความถึงลูกค้า..." : "Write a message to the customer..."}
                          className="w-full h-32 p-4 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-800 rounded-2xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all resize-none dark:text-slate-300"
                        />
                        <button className="flex items-center gap-2 px-6 py-3 bg-primary text-white rounded-xl font-bold hover:bg-primary-dark transition-all transform hover:scale-105 active:scale-95 shadow-lg shadow-primary/20">
                          <Send className="h-4 w-4" />
                          <span>{locale === "th" ? "ส่งข้อความ" : "Send Message"}</span>
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
