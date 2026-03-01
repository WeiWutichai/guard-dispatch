"use client";

import { useState } from "react";
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
  MapPin,
  Building2,
  UserCheck,
  Briefcase,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

// --- Types ---
type ApplicantType = "guard" | "customer";
type ApplicantStatus = "pending" | "approved" | "rejected";

interface BaseApplicant {
  id: string;
  name: string;
  avatar: string;
  phone: string;
  email: string;
  appliedDate: string;
  status: ApplicantStatus;
  location?: string;
}

interface GuardApplicant extends BaseApplicant {
  type: "guard";
  experience: string;
  expectedSalary: string;
  documents: { name: string; status: "submitted" | "pending" | "missing"; url?: string }[];
  certificates: string[];
  bio: string;
}

interface CustomerApplicant extends BaseApplicant {
  type: "customer";
  companyName?: string;
  bookingPurpose: string;
}

type Applicant = GuardApplicant | CustomerApplicant;

type TabType = "all" | "guard" | "customer";

// --- Mock Data ---
const initialApplicants: Applicant[] = [
  // Guard applicants
  {
    id: "GA001",
    type: "guard",
    name: "สมศักดิ์ มานะ",
    avatar: "สม",
    phone: "089-123-4567",
    email: "somsak.m@email.com",
    appliedDate: "2024-01-15",
    experience: "3 ปี - รปภ. หมู่บ้าน",
    expectedSalary: "18,000 บาท",
    status: "pending",
    location: "บางนา, กรุงเทพฯ",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted", url: "https://picsum.photos/id/10/1000/1500" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "submitted", url: "https://picsum.photos/id/11/1000/1500" },
      { name: "ใบผ่านการตรวจสอบประวัติอาชญากรรม", status: "pending" },
      { name: "ใบขับขี่", status: "submitted", url: "https://picsum.photos/id/12/1000/1500" },
    ],
    certificates: ["First Aid", "Fire Safety"],
    bio: "มีประสบการณ์ทำงานรักษาความปลอดภัยหมู่บ้านจัดสรร 3 ปี มีความรับผิดชอบสูง",
  },
  {
    id: "GA002",
    type: "guard",
    name: "วิชัย ใจดี",
    avatar: "วช",
    phone: "091-234-5678",
    email: "wichai.j@email.com",
    appliedDate: "2024-01-18",
    experience: "5 ปี - รปภ. ห้างสรรพสินค้า",
    expectedSalary: "22,000 บาท",
    status: "pending",
    location: "ปทุมวัน, กรุงเทพฯ",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted", url: "https://picsum.photos/id/20/1000/1500" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "submitted", url: "https://picsum.photos/id/21/1000/1500" },
      { name: "ใบผ่านการตรวจสอบประวัติอาชญากรรม", status: "submitted", url: "https://picsum.photos/id/22/1000/1500" },
      { name: "ใบขับขี่", status: "submitted", url: "https://picsum.photos/id/23/1000/1500" },
    ],
    certificates: ["CPR", "Crowd Control", "Emergency Response"],
    bio: "อดีตทหาร มีประสบการณ์ด้านรักษาความปลอดภัยห้างสรรพสินค้า 5 ปี",
  },
  {
    id: "GA003",
    type: "guard",
    name: "ประเสริฐ ทองดี",
    avatar: "ปส",
    phone: "084-567-8901",
    email: "prasert.t@email.com",
    appliedDate: "2024-01-20",
    experience: "1 ปี - รปภ. คอนโด",
    expectedSalary: "15,000 บาท",
    status: "pending",
    location: "คลองเตย, กรุงเทพฯ",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted", url: "https://picsum.photos/id/30/1000/1500" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "pending" },
      { name: "ใบผ่านการตรวจสอบประวัติอาชญากรรม", status: "missing" },
    ],
    certificates: [],
    bio: "เพิ่งเริ่มทำงานด้านรักษาความปลอดภัย มีความกระตือรือร้นในการเรียนรู้",
  },
  {
    id: "GA004",
    type: "guard",
    name: "สุรชัย แสนดี",
    avatar: "สร",
    phone: "086-789-0123",
    email: "surachai.s@email.com",
    appliedDate: "2024-01-10",
    experience: "7 ปี - รปภ. โรงงาน",
    expectedSalary: "25,000 บาท",
    status: "approved",
    location: "สมุทรปราการ",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted", url: "https://picsum.photos/id/40/1000/1500" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "submitted", url: "https://picsum.photos/id/41/1000/1500" },
      { name: "ใบผ่านการตรวจสอบประวัติอาชญากรรม", status: "submitted", url: "https://picsum.photos/id/42/1000/1500" },
      { name: "ใบขับขี่", status: "submitted", url: "https://picsum.photos/id/43/1000/1500" },
    ],
    certificates: ["Industrial Safety", "First Aid", "Fire Fighting"],
    bio: "มีประสบการณ์รักษาความปลอดภัยโรงงานอุตสาหกรรม 7 ปี เชี่ยวชาญด้านความปลอดภัยในโรงงาน",
  },
  {
    id: "GA005",
    type: "guard",
    name: "อนันต์ มั่นคง",
    avatar: "อน",
    phone: "088-901-2345",
    email: "anan.m@email.com",
    appliedDate: "2024-01-08",
    experience: "2 ปี - รปภ. อาคารสำนักงาน",
    expectedSalary: "16,000 บาท",
    status: "rejected",
    location: "สาทร, กรุงเทพฯ",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted", url: "https://picsum.photos/id/50/1000/1500" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "missing" },
    ],
    certificates: [],
    bio: "เคยทำงานรักษาความปลอดภัยอาคารสำนักงาน 2 ปี",
  },
  // Customer applicants
  {
    id: "CA001",
    type: "customer",
    name: "นภา สุขใจ",
    avatar: "นภ",
    phone: "081-111-2222",
    email: "napa.s@email.com",
    appliedDate: "2024-01-16",
    status: "pending",
    location: "สีลม, กรุงเทพฯ",
    companyName: "บริษัท สุขใจ จำกัด",
    bookingPurpose: "รักษาความปลอดภัยอาคารสำนักงาน",
  },
  {
    id: "CA002",
    type: "customer",
    name: "พิมพ์ชนก วงศ์สว่าง",
    avatar: "พช",
    phone: "082-333-4444",
    email: "pimchanok.w@email.com",
    appliedDate: "2024-01-17",
    status: "pending",
    location: "ลาดพร้าว, กรุงเทพฯ",
    bookingPurpose: "รักษาความปลอดภัยงานอีเวนต์",
  },
  {
    id: "CA003",
    type: "customer",
    name: "ธนพล เจริญรุ่ง",
    avatar: "ธน",
    phone: "083-555-6666",
    email: "thanapol.c@email.com",
    appliedDate: "2024-01-12",
    status: "approved",
    location: "พระโขนง, กรุงเทพฯ",
    companyName: "บริษัท เจริญรุ่ง พร็อพเพอร์ตี้ จำกัด",
    bookingPurpose: "รักษาความปลอดภัยโครงการหมู่บ้านจัดสรร",
  },
  {
    id: "CA004",
    type: "customer",
    name: "สุวรรณา ลีลาวดี",
    avatar: "สว",
    phone: "085-777-8888",
    email: "suwanna.l@email.com",
    appliedDate: "2024-01-09",
    status: "rejected",
    location: "รังสิต, ปทุมธานี",
    bookingPurpose: "รักษาความปลอดภัยส่วนบุคคล",
  },
];

const statusConfig: Record<ApplicantStatus, { color: string; bg: string; dot: string }> = {
  pending: { color: "text-amber-700", bg: "bg-amber-100", dot: "bg-amber-500" },
  approved: { color: "text-emerald-700", bg: "bg-emerald-100", dot: "bg-emerald-500" },
  rejected: { color: "text-red-700", bg: "bg-red-100", dot: "bg-red-500" },
};

export default function ApplicantsPage() {
  const { t, locale } = useLanguage();
  const [applicants, setApplicants] = useState<Applicant[]>(initialApplicants);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<ApplicantStatus | "all">("all");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [activeTab, setActiveTab] = useState<TabType>("all");
  const [selectedApplicant, setSelectedApplicant] = useState<Applicant | null>(null);
  const [isApplicantModalOpen, setIsApplicantModalOpen] = useState(false);
  const [selectedDoc, setSelectedDoc] = useState<{ name: string; url: string } | null>(null);

  // Filter applicants by tab, search, and status
  const filteredApplicants = applicants.filter((applicant) => {
    const matchesTab = activeTab === "all" || applicant.type === activeTab;
    const matchesSearch =
      applicant.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      applicant.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      applicant.phone.includes(searchQuery);
    const matchesStatus = statusFilter === "all" || applicant.status === statusFilter;
    return matchesTab && matchesSearch && matchesStatus;
  });

  // Stats scoped to active tab
  const tabApplicants = applicants.filter((a) => activeTab === "all" || a.type === activeTab);
  const stats = {
    total: tabApplicants.length,
    pending: tabApplicants.filter((a) => a.status === "pending").length,
    approved: tabApplicants.filter((a) => a.status === "approved").length,
    rejected: tabApplicants.filter((a) => a.status === "rejected").length,
  };

  const handleApproveApplicant = (applicantId: string) => {
    setApplicants(
      applicants.map((a) =>
        a.id === applicantId ? { ...a, status: "approved" as ApplicantStatus } : a
      )
    );
    setIsApplicantModalOpen(false);
    setSelectedApplicant(null);
  };

  const handleRejectApplicant = (applicantId: string) => {
    setApplicants(
      applicants.map((a) =>
        a.id === applicantId ? { ...a, status: "rejected" as ApplicantStatus } : a
      )
    );
    setIsApplicantModalOpen(false);
    setSelectedApplicant(null);
  };

  const getStatusLabel = (status: ApplicantStatus) => {
    const labels: Record<ApplicantStatus, { th: string; en: string }> = {
      pending: { th: t.applicants.stats.pending, en: t.applicants.stats.pending },
      approved: { th: t.applicants.stats.approved, en: t.applicants.stats.approved },
      rejected: { th: t.applicants.stats.rejected, en: t.applicants.stats.rejected },
    };
    return labels[status];
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
        {tabs.map((tab) => {
          const count = applicants.filter(
            (a) => tab.key === "all" || a.type === tab.key
          ).length;
          return (
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
              <span
                className={cn(
                  "ml-1 px-2 py-0.5 rounded-full text-xs font-bold",
                  activeTab === tab.key
                    ? "bg-white/20 text-white"
                    : "bg-slate-100 text-slate-500"
                )}
              >
                {count}
              </span>
            </button>
          );
        })}
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
                  : getStatusLabel(statusFilter)[locale === "th" ? "th" : "en"]}
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

      {/* Applicants Table */}
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
                {/* Show type column only on "all" tab */}
                {activeTab === "all" && (
                  <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                    {t.applicants.table.type}
                  </th>
                )}
                {/* Guard-specific columns */}
                {(activeTab === "all" || activeTab === "guard") && (
                  <>
                    <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                      {t.applicants.table.experience}
                    </th>
                    <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                      {t.applicants.table.expectedSalary}
                    </th>
                  </>
                )}
                {/* Customer-specific columns */}
                {activeTab === "customer" && (
                  <>
                    <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                      {t.applicants.table.companyName}
                    </th>
                    <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                      {t.applicants.table.bookingPurpose}
                    </th>
                  </>
                )}
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
              {filteredApplicants.map((applicant) => {
                const status = statusConfig[applicant.status];
                return (
                  <tr key={applicant.id} className="hover:bg-slate-50/50 transition-colors group">
                    {/* Applicant Name + Avatar */}
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div
                          className={cn(
                            "w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0",
                            applicant.type === "guard"
                              ? "bg-gradient-to-br from-amber-100 to-amber-50"
                              : "bg-gradient-to-br from-blue-100 to-blue-50"
                          )}
                        >
                          <span
                            className={cn(
                              "text-sm font-bold",
                              applicant.type === "guard" ? "text-amber-700" : "text-blue-700"
                            )}
                          >
                            {applicant.avatar}
                          </span>
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900">{applicant.name}</p>
                          <p className="text-xs text-slate-400">{applicant.id}</p>
                        </div>
                      </div>
                    </td>
                    {/* Phone */}
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-600">{applicant.phone}</p>
                    </td>
                    {/* Type badge (all tab only) */}
                    {activeTab === "all" && (
                      <td className="py-4 px-5">
                        <span
                          className={cn(
                            "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                            applicant.type === "guard"
                              ? "bg-amber-100 text-amber-700"
                              : "bg-blue-100 text-blue-700"
                          )}
                        >
                          {applicant.type === "guard" ? (
                            <Shield className="h-3 w-3" />
                          ) : (
                            <UserCheck className="h-3 w-3" />
                          )}
                          {t.applicants.badge[applicant.type]}
                        </span>
                      </td>
                    )}
                    {/* Guard-specific data */}
                    {(activeTab === "all" || activeTab === "guard") && (
                      <>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-600 font-medium">
                            {applicant.type === "guard" ? applicant.experience : "-"}
                          </p>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-primary font-bold">
                            {applicant.type === "guard" ? applicant.expectedSalary : "-"}
                          </p>
                        </td>
                      </>
                    )}
                    {/* Customer-specific data */}
                    {activeTab === "customer" && (
                      <>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-600 font-medium">
                            {applicant.type === "customer" ? (applicant.companyName || "-") : "-"}
                          </p>
                        </td>
                        <td className="py-4 px-5">
                          <p className="text-sm text-slate-600">
                            {applicant.type === "customer" ? applicant.bookingPurpose : "-"}
                          </p>
                        </td>
                      </>
                    )}
                    {/* Applied date */}
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-500">{applicant.appliedDate}</p>
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
                        {applicant.status === "pending"
                          ? t.applicants.statusPending
                          : applicant.status === "approved"
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

        {filteredApplicants.length === 0 && (
          <div className="py-16 text-center">
            <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Users className="h-8 w-8 text-slate-400" />
            </div>
            <p className="text-slate-500 font-medium">{t.applicants.noApplicantsFound}</p>
          </div>
        )}
      </div>

      {/* Applicant Review Modal */}
      {isApplicantModalOpen && selectedApplicant && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl border border-slate-200 w-full max-w-2xl overflow-hidden animate-in fade-in zoom-in duration-200">
            {/* Modal Header */}
            <div
              className={cn(
                "flex items-center justify-between p-6 border-b border-slate-100",
                selectedApplicant.type === "guard"
                  ? "bg-gradient-to-r from-amber-50 to-white"
                  : "bg-gradient-to-r from-blue-50 to-white"
              )}
            >
              <div className="flex items-center gap-3">
                <div
                  className={cn(
                    "p-2 rounded-xl",
                    selectedApplicant.type === "guard" ? "bg-amber-100" : "bg-blue-100"
                  )}
                >
                  {selectedApplicant.type === "guard" ? (
                    <Shield className="h-5 w-5 text-amber-600" />
                  ) : (
                    <UserCheck className="h-5 w-5 text-blue-600" />
                  )}
                </div>
                <div>
                  <h2 className="text-xl font-bold text-slate-900">
                    {t.applicants.modal.reviewTitle}
                  </h2>
                  <div className="flex items-center gap-2 mt-0.5">
                    <p className="text-sm text-slate-500">{selectedApplicant.id}</p>
                    <span
                      className={cn(
                        "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider",
                        selectedApplicant.type === "guard"
                          ? "bg-amber-100 text-amber-700"
                          : "bg-blue-100 text-blue-700"
                      )}
                    >
                      {t.applicants.badge[selectedApplicant.type]}
                    </span>
                  </div>
                </div>
              </div>
              <button
                onClick={() => {
                  setIsApplicantModalOpen(false);
                  setSelectedApplicant(null);
                }}
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
                      selectedApplicant.type === "guard"
                        ? "bg-gradient-to-br from-amber-100 to-amber-50 text-amber-700"
                        : "bg-gradient-to-br from-blue-100 to-blue-50 text-blue-700"
                    )}
                  >
                    {selectedApplicant.avatar}
                  </div>
                  <div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-1">
                      {selectedApplicant.name}
                    </h3>
                    {selectedApplicant.type === "guard" && (
                      <p className="text-sm text-slate-500 mb-2">
                        {selectedApplicant.experience}
                      </p>
                    )}
                    {selectedApplicant.type === "customer" && selectedApplicant.companyName && (
                      <p className="text-sm text-slate-500 mb-2 flex items-center gap-1.5">
                        <Building2 className="h-3.5 w-3.5" />
                        {selectedApplicant.companyName}
                      </p>
                    )}
                    <div className="flex items-center gap-2">
                      <span
                        className={cn(
                          "px-3 py-1 text-xs font-semibold rounded-full",
                          statusConfig[selectedApplicant.status].bg,
                          statusConfig[selectedApplicant.status].color
                        )}
                      >
                        {selectedApplicant.status === "pending"
                          ? t.applicants.statusPending
                          : selectedApplicant.status === "approved"
                            ? t.applicants.statusApproved
                            : t.applicants.statusRejected}
                      </span>
                      <span className="text-xs text-slate-400">
                        <Calendar className="h-3 w-3 inline mr-1" />
                        {selectedApplicant.appliedDate}
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
                {selectedApplicant.location && (
                  <div className="flex items-center gap-3 text-slate-600">
                    <MapPin className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">{selectedApplicant.location}</span>
                  </div>
                )}
                {selectedApplicant.type === "guard" && (
                  <div className="flex items-center gap-3 text-slate-600">
                    <Shield className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">
                      {t.applicants.table.expectedSalary}:{" "}
                      <span className="text-primary font-bold">
                        {selectedApplicant.expectedSalary}
                      </span>
                    </span>
                  </div>
                )}
                {selectedApplicant.type === "customer" && (
                  <div className="flex items-center gap-3 text-slate-600">
                    <Briefcase className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">
                      {selectedApplicant.bookingPurpose}
                    </span>
                  </div>
                )}
              </div>

              {/* Guard-specific: Documents */}
              {selectedApplicant.type === "guard" && (
                <div className="mb-8">
                  <h4 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wider">
                    {t.applicants.modal.documents}
                  </h4>
                  <div className="space-y-3">
                    {selectedApplicant.documents.map((doc, idx) => (
                      <div
                        key={idx}
                        className="flex items-center justify-between p-3 bg-white border border-slate-100 rounded-xl hover:shadow-sm transition-all"
                      >
                        <span className="text-sm font-medium text-slate-700">{doc.name}</span>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            if (doc.url) setSelectedDoc({ name: doc.name, url: doc.url });
                          }}
                          disabled={!doc.url}
                          className={cn(
                            "text-[10px] font-bold uppercase tracking-widest px-3 py-1.5 rounded-full transition-all",
                            doc.status === "submitted"
                              ? "bg-emerald-100 text-emerald-700 hover:bg-emerald-200 cursor-pointer"
                              : doc.status === "pending"
                                ? "bg-amber-100 text-amber-700"
                                : "bg-red-100 text-red-700"
                          )}
                        >
                          {doc.status === "submitted"
                            ? t.applicants.modal.submitted
                            : doc.status === "pending"
                              ? t.applicants.modal.pendingDoc
                              : t.applicants.modal.missing}
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Guard-specific: Certificates */}
              {selectedApplicant.type === "guard" && selectedApplicant.certificates.length > 0 && (
                <div className="mb-8">
                  <h4 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wider">
                    {t.applicants.modal.certificates}
                  </h4>
                  <div className="flex flex-wrap gap-2">
                    {selectedApplicant.certificates.map((cert) => (
                      <span
                        key={cert}
                        className="px-4 py-1.5 bg-blue-50 text-blue-700 rounded-full text-xs font-bold border border-blue-100"
                      >
                        {cert}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Guard-specific: Bio */}
              {selectedApplicant.type === "guard" && (
                <div className="pt-6 border-t border-slate-100">
                  <h4 className="text-sm font-bold text-slate-900 mb-3 uppercase tracking-wider">
                    {t.applicants.modal.background}
                  </h4>
                  <p className="text-slate-600 text-sm leading-relaxed">
                    {selectedApplicant.bio}
                  </p>
                </div>
              )}

              {/* Approved Note */}
              {selectedApplicant.status === "approved" && (
                <div className="mt-6 p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
                  <p className="text-sm text-emerald-700 font-medium flex items-center gap-2">
                    <Check className="h-4 w-4" />
                    {t.applicants.approvedNote[selectedApplicant.type]}
                  </p>
                </div>
              )}
            </div>

            {/* Action Buttons */}
            {selectedApplicant.status === "pending" ? (
              <div className="p-6 bg-slate-50 border-t border-slate-100 flex gap-4">
                <button
                  onClick={() => handleRejectApplicant(selectedApplicant.id)}
                  className="flex-1 py-3 px-4 bg-white border-2 border-red-200 text-red-600 rounded-xl text-sm font-bold hover:bg-red-50 hover:border-red-300 transition-all flex items-center justify-center gap-2"
                >
                  <Ban className="h-4 w-4" />
                  {t.applicants.modal.reject}
                </button>
                <button
                  onClick={() => handleApproveApplicant(selectedApplicant.id)}
                  className="flex-1 py-3 px-4 bg-primary text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-all shadow-lg shadow-primary/20 flex items-center justify-center gap-2"
                >
                  <Check className="h-4 w-4" />
                  {t.applicants.modal.approve}
                </button>
              </div>
            ) : (
              <div className="p-6 bg-slate-50 border-t border-slate-100">
                <button
                  onClick={() => {
                    setIsApplicantModalOpen(false);
                    setSelectedApplicant(null);
                  }}
                  className="w-full py-3 px-4 bg-slate-200 text-slate-700 rounded-xl text-sm font-bold hover:bg-slate-300 transition-all"
                >
                  {t.applicants.modal.close}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Document Viewer Modal (Guard only) */}
      {selectedDoc && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-slate-900/80 backdrop-blur-md">
          <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col animate-in fade-in zoom-in duration-200">
            <div className="flex items-center justify-between p-4 border-b border-slate-100">
              <h3 className="text-lg font-bold text-slate-900">{selectedDoc.name}</h3>
              <button
                onClick={() => setSelectedDoc(null)}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="flex-1 overflow-auto p-4 bg-slate-100 flex items-center justify-center">
              <img
                src={selectedDoc.url}
                alt={selectedDoc.name}
                className="max-w-full h-auto rounded-lg shadow-lg border border-slate-200"
              />
            </div>
            <div className="p-4 border-t border-slate-100 flex justify-end gap-3">
              <button
                onClick={() => setSelectedDoc(null)}
                className="px-6 py-2 bg-slate-200 text-slate-700 rounded-lg text-sm font-bold hover:bg-slate-300 transition-colors"
              >
                {t.applicants.modal.close}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
