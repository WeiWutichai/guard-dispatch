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
  FileText,
  Calendar,
  ChevronDown,
  MapPin,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

type ApplicantStatus = "pending" | "approved" | "rejected";

interface Applicant {
  id: string;
  name: string;
  avatar: string;
  phone: string;
  email: string;
  appliedDate: string;
  experience: string;
  expectedSalary: string;
  status: ApplicantStatus;
  documents: { name: string; status: "submitted" | "pending" | "missing"; url?: string }[];
  certificates: string[];
  bio: string;
  location?: string;
}

const initialApplicants: Applicant[] = [
  {
    id: "A001",
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
    id: "A002",
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
    id: "A003",
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
    id: "A004",
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
    id: "A005",
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
];

const statusConfig: Record<ApplicantStatus, { label: { th: string; en: string }; color: string; bg: string }> = {
  pending: { label: { th: "รอพิจารณา", en: "Pending" }, color: "text-amber-700", bg: "bg-amber-100" },
  approved: { label: { th: "อนุมัติแล้ว", en: "Approved" }, color: "text-emerald-700", bg: "bg-emerald-100" },
  rejected: { label: { th: "ปฏิเสธ", en: "Rejected" }, color: "text-red-700", bg: "bg-red-100" },
};

export default function ApplicantsPage() {
  const { t, locale } = useLanguage();
  const [applicants, setApplicants] = useState<Applicant[]>(initialApplicants);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<ApplicantStatus | "all">("all");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const [selectedApplicant, setSelectedApplicant] = useState<Applicant | null>(null);
  const [isApplicantModalOpen, setIsApplicantModalOpen] = useState(false);
  const [selectedDoc, setSelectedDoc] = useState<{ name: string; url: string } | null>(null);

  const filteredApplicants = applicants.filter((applicant) => {
    const matchesSearch = applicant.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      applicant.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      applicant.phone.includes(searchQuery);
    const matchesStatus = statusFilter === "all" || applicant.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const stats = {
    total: applicants.length,
    pending: applicants.filter(a => a.status === "pending").length,
    approved: applicants.filter(a => a.status === "approved").length,
    rejected: applicants.filter(a => a.status === "rejected").length,
  };

  const handleApproveApplicant = (applicantId: string) => {
    setApplicants(applicants.map(a =>
      a.id === applicantId ? { ...a, status: "approved" as ApplicantStatus } : a
    ));
    setIsApplicantModalOpen(false);
    setSelectedApplicant(null);
  };

  const handleRejectApplicant = (applicantId: string) => {
    setApplicants(applicants.map(a =>
      a.id === applicantId ? { ...a, status: "rejected" as ApplicantStatus } : a
    ));
    setIsApplicantModalOpen(false);
    setSelectedApplicant(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">
            {locale === "th" ? "จัดการผู้สมัคร" : "Applicant Management"}
          </h1>
          <p className="text-slate-500 mt-1">
            {locale === "th" ? "ตรวจสอบและอนุมัติผู้สมัครเข้าทำงาน" : "Review and approve job applicants"}
          </p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-5">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">{locale === "th" ? "ผู้สมัครทั้งหมด" : "Total Applicants"}</p>
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
              <p className="text-sm font-medium text-amber-600">{locale === "th" ? "รอพิจารณา" : "Pending"}</p>
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
              <p className="text-sm font-medium text-emerald-600">{locale === "th" ? "อนุมัติแล้ว" : "Approved"}</p>
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
              <p className="text-sm font-medium text-red-600">{locale === "th" ? "ปฏิเสธ" : "Rejected"}</p>
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
              placeholder={locale === "th" ? "ค้นหาผู้สมัคร..." : "Search applicants..."}
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
              <span>{statusFilter === "all" ? (locale === "th" ? "สถานะทั้งหมด" : "All Status") : statusConfig[statusFilter].label[locale]}</span>
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
                  {locale === "th" ? "สถานะทั้งหมด" : "All Status"}
                </button>
                {(Object.keys(statusConfig) as ApplicantStatus[]).map((status) => (
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

      {/* Applicants Table */}
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50/80 border-b border-slate-200">
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ผู้สมัคร" : "Applicant"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ประสบการณ์" : "Experience"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เงินเดือนที่คาดหวัง" : "Expected Salary"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "วันที่สมัคร" : "Applied Date"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "สถานะ" : "Status"}</th>
                <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "การดำเนินการ" : "Actions"}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredApplicants.map((applicant) => {
                const status = statusConfig[applicant.status];
                return (
                  <tr key={applicant.id} className="hover:bg-slate-50/50 transition-colors group">
                    <td className="py-4 px-5">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-amber-100 to-amber-50 flex items-center justify-center flex-shrink-0">
                          <span className="text-sm font-bold text-amber-700">{applicant.avatar}</span>
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900">{applicant.name}</p>
                          <p className="text-xs text-slate-400">{applicant.phone}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-600 font-medium">{applicant.experience}</p>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-primary font-bold">{applicant.expectedSalary}</p>
                    </td>
                    <td className="py-4 px-5">
                      <p className="text-sm text-slate-500">{applicant.appliedDate}</p>
                    </td>
                    <td className="py-4 px-5">
                      <span className={cn(
                        "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                        status.bg, status.color
                      )}>
                        <span className={cn(
                          "w-1.5 h-1.5 rounded-full",
                          applicant.status === "pending" ? "bg-amber-500" :
                            applicant.status === "approved" ? "bg-emerald-500" : "bg-red-500"
                        )}></span>
                        {status.label[locale]}
                      </span>
                    </td>
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
            <p className="text-slate-500 font-medium">{locale === "th" ? "ไม่พบผู้สมัคร" : "No applicants found"}</p>
          </div>
        )}
      </div>

      {/* Applicant Review Modal */}
      {isApplicantModalOpen && selectedApplicant && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl border border-slate-200 w-full max-w-2xl overflow-hidden animate-in fade-in zoom-in duration-200">
            <div className="flex items-center justify-between p-6 border-b border-slate-100 bg-gradient-to-r from-amber-50 to-white">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-amber-100 rounded-xl">
                  <UserPlus className="h-5 w-5 text-amber-600" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-slate-900">
                    {locale === "th" ? "ตรวจสอบใบสมัคร" : "Review Application"}
                  </h2>
                  <p className="text-sm text-slate-500">{selectedApplicant.id}</p>
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
                  <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-amber-100 to-amber-50 flex items-center justify-center text-2xl font-bold text-amber-700 shadow-inner">
                    {selectedApplicant.avatar}
                  </div>
                  <div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-1">{selectedApplicant.name}</h3>
                    <p className="text-sm text-slate-500 mb-2">{selectedApplicant.experience}</p>
                    <div className="flex items-center gap-2">
                      <span className={cn(
                        "px-3 py-1 text-xs font-semibold rounded-full",
                        statusConfig[selectedApplicant.status].bg,
                        statusConfig[selectedApplicant.status].color
                      )}>
                        {statusConfig[selectedApplicant.status].label[locale]}
                      </span>
                      <span className="text-xs text-slate-400">
                        {locale === "th" ? "สมัครเมื่อ" : "Applied"}: {selectedApplicant.appliedDate}
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Contact & Salary Info */}
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
                <div className="flex items-center gap-3 text-slate-600">
                  <Shield className="h-5 w-5 text-slate-400" />
                  <span className="text-sm font-medium">
                    {locale === "th" ? "เงินเดือนที่คาดหวัง" : "Expected Salary"}: <span className="text-primary font-bold">{selectedApplicant.expectedSalary}</span>
                  </span>
                </div>
              </div>

              {/* Documents Section */}
              <div className="mb-8">
                <h4 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wider">
                  {locale === "th" ? "เอกสารยืนยันตัวตน" : "Identity Documents"}
                </h4>
                <div className="space-y-3">
                  {selectedApplicant.documents.map((doc, idx) => (
                    <div key={idx} className="flex items-center justify-between p-3 bg-white border border-slate-100 rounded-xl hover:shadow-sm transition-all">
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
                          ? (locale === "th" ? "ส่งแล้ว" : "Submitted")
                          : doc.status === "pending"
                            ? (locale === "th" ? "รอส่ง" : "Pending")
                            : (locale === "th" ? "ยังไม่ส่ง" : "Missing")}
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Certificates */}
              {selectedApplicant.certificates.length > 0 && (
                <div className="mb-8">
                  <h4 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wider">
                    {locale === "th" ? "ใบประกาศนียบัตร" : "Certificates"}
                  </h4>
                  <div className="flex flex-wrap gap-2">
                    {selectedApplicant.certificates.map((cert) => (
                      <span key={cert} className="px-4 py-1.5 bg-blue-50 text-blue-700 rounded-full text-xs font-bold border border-blue-100">
                        {cert}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Bio */}
              <div className="pt-6 border-t border-slate-100">
                <h4 className="text-sm font-bold text-slate-900 mb-3 uppercase tracking-wider">
                  {locale === "th" ? "ประวัติโดยย่อ" : "Background"}
                </h4>
                <p className="text-slate-600 text-sm leading-relaxed">
                  {selectedApplicant.bio}
                </p>
              </div>
            </div>

            {/* Action Buttons */}
            {selectedApplicant.status === "pending" ? (
              <div className="p-6 bg-slate-50 border-t border-slate-100 flex gap-4">
                <button
                  onClick={() => handleRejectApplicant(selectedApplicant.id)}
                  className="flex-1 py-3 px-4 bg-white border-2 border-red-200 text-red-600 rounded-xl text-sm font-bold hover:bg-red-50 hover:border-red-300 transition-all flex items-center justify-center gap-2"
                >
                  <Ban className="h-4 w-4" />
                  {locale === "th" ? "ปฏิเสธ" : "Reject"}
                </button>
                <button
                  onClick={() => handleApproveApplicant(selectedApplicant.id)}
                  className="flex-1 py-3 px-4 bg-primary text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-all shadow-lg shadow-primary/20 flex items-center justify-center gap-2"
                >
                  <Check className="h-4 w-4" />
                  {locale === "th" ? "อนุมัติ" : "Approve"}
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
                  {locale === "th" ? "ปิด" : "Close"}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Document Viewer Modal */}
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
                {t.common.cancel}
              </button>
              <button
                className="px-6 py-2 bg-primary text-white rounded-lg text-sm font-bold hover:bg-emerald-600 transition-colors shadow-lg shadow-primary/20"
              >
                Download
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
