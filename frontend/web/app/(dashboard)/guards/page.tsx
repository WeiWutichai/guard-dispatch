"use client";

import { useState } from "react";
import {
  Users,
  Search,
  Plus,
  MoreHorizontal,
  MapPin,
  Phone,
  Mail,
  Shield,
  CheckCircle2,
  XCircle,
  Clock,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

type GuardStatus = "on-duty" | "off-duty" | "on-leave";

interface Guard {
  id: string;
  name: string;
  avatar: string;
  status: GuardStatus;
  phone: string;
  email: string;
  location: string;
  site: string;
  hireDate: string;
  rating: number;
  totalTasks: number;
  experience: string;
  bio: string;
  documents: { name: string; status: "submitted" | "pending" | "missing"; url?: string }[];
  certificates: string[];
}

const initialGuards: Guard[] = [
  {
    id: "G001",
    name: "Somchai Prasert",
    avatar: "SP",
    status: "on-duty",
    phone: "081-234-5678",
    email: "somchai.p@secureguard.com",
    location: "บางนา, กรุงเทพฯ",
    site: "Central Plaza",
    hireDate: "2023-03-15",
    rating: 4.9,
    totalTasks: 156,
    experience: "8 ปีประสบการณ์",
    bio: "8 years experience in corporate security and event management",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted", url: "https://picsum.photos/id/1/1000/1500" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "submitted", url: "https://picsum.photos/id/2/1000/1500" },
      { name: "ใบผ่านการตรวจสอบประวัติอาชญากรรม", status: "submitted", url: "https://picsum.photos/id/3/1000/1500" },
      { name: "ใบขับขี่", status: "submitted", url: "https://picsum.photos/id/4/1000/1500" },
      { name: "สมุดบัญชีธนาคาร", status: "submitted", url: "https://picsum.photos/id/5/1000/1500" },
    ],
    certificates: ["First Aid", "CPR", "Security Management"],
  },
  {
    id: "G002",
    name: "Niran Thongchai",
    avatar: "NT",
    status: "on-duty",
    phone: "082-345-6789",
    email: "niran.t@secureguard.com",
    location: "ปทุมวัน, กรุงเทพฯ",
    site: "Siam Paragon",
    hireDate: "2022-08-20",
    rating: 4.5,
    totalTasks: 92,
    experience: "5 ปีประสบการณ์",
    bio: "Specialized in VIP protection and crowd control.",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "submitted" },
    ],
    certificates: ["Crowd Control"],
  },
  {
    id: "G003",
    name: "Prawit Wongsuwan",
    avatar: "PW",
    status: "off-duty",
    phone: "083-456-7890",
    email: "prawit.w@secureguard.com",
    location: "คลองเตย, กรุงเทพฯ",
    site: "EmQuartier",
    hireDate: "2023-01-10",
    rating: 4.9,
    totalTasks: 210,
    experience: "12 ปีประสบการณ์",
    bio: "Ex-military personnel with extensive training in risk assessment.",
    documents: [
      { name: "บัตรประจำตัวประชาชน", status: "submitted" },
      { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "submitted" },
    ],
    certificates: ["Advanced Firearms", "Risk Management"],
  },
];

const locations = [
  "Central Plaza",
  "Siam Paragon",
  "EmQuartier",
  "Terminal 21",
  "MBK Center",
  "ICONSIAM",
  "CentralWorld",
  "Mega Bangna",
];

const statusConfig: Record<GuardStatus, { label: string; color: string; bg: string; icon: typeof CheckCircle2 }> = {
  "on-duty": { label: "On Duty", color: "text-emerald-700", bg: "bg-emerald-50", icon: CheckCircle2 },
  "off-duty": { label: "Off Duty", color: "text-slate-600", bg: "bg-slate-100", icon: Clock },
  "on-leave": { label: "On Leave", color: "text-amber-700", bg: "bg-amber-50", icon: XCircle },
};

export default function GuardsPage() {
  const { t } = useLanguage();
  const [guards, setGuards] = useState<Guard[]>(initialGuards);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<GuardStatus | "all">("all");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    phone: "",
    email: "",
    location: "",
    site: "",
    status: "off-duty" as GuardStatus,
  });

  const [selectedGuard, setSelectedGuard] = useState<Guard | null>(null);
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [selectedDoc, setSelectedDoc] = useState<{ name: string; url: string } | null>(null);

  const filteredGuards = guards.filter((guard) => {
    const matchesSearch = guard.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      guard.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      guard.location.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === "all" || guard.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const stats = {
    total: guards.length,
    onDuty: guards.filter(g => g.status === "on-duty").length,
    offDuty: guards.filter(g => g.status === "off-duty").length,
    onLeave: guards.filter(g => g.status === "on-leave").length,
  };

  const generateAvatar = (name: string) => {
    const parts = name.trim().split(" ");
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  const generateId = () => {
    const maxId = guards.reduce((max, g) => {
      const num = parseInt(g.id.replace("G", ""));
      return num > max ? num : max;
    }, 0);
    return `G${String(maxId + 1).padStart(3, "0")}`;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const newGuard: Guard = {
      id: generateId(),
      name: formData.name,
      avatar: generateAvatar(formData.name),
      status: formData.status,
      phone: formData.phone,
      email: formData.email,
      location: formData.location,
      site: formData.site,
      hireDate: new Date().toISOString().split("T")[0],
      rating: 0,
      totalTasks: 0,
      experience: "New Recruit",
      bio: "Newly added security guard.",
      documents: [
        { name: "บัตรประจำตัวประชาชน", status: "pending" },
        { name: "ใบอนุญาตประกอบวิชาชีพรักษาความปลอดภัย", status: "pending" },
      ],
      certificates: [],
    };
    setGuards([newGuard, ...guards]);
    setIsModalOpen(false);
    setFormData({
      name: "",
      phone: "",
      email: "",
      location: "",
      site: "",
      status: "off-duty",
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{t.guards.title}</h1>
          <p className="text-slate-500 mt-1">{t.guards.subtitle}</p>
        </div>
        <button
          onClick={() => setIsModalOpen(true)}
          className="inline-flex items-center px-4 py-2 bg-primary text-white rounded-lg font-medium text-sm hover:bg-emerald-600 transition-colors shadow-sm"
        >
          <Plus className="h-4 w-4 mr-2" />
          {t.guards.addGuard}
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-slate-100 rounded-lg">
              <Users className="h-5 w-5 text-slate-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.total}</p>
              <p className="text-sm text-slate-500">{t.guards.totalGuards}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-emerald-50 rounded-lg">
              <CheckCircle2 className="h-5 w-5 text-emerald-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.onDuty}</p>
              <p className="text-sm text-slate-500">{t.guards.onDuty}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-slate-100 rounded-lg">
              <Clock className="h-5 w-5 text-slate-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.offDuty}</p>
              <p className="text-sm text-slate-500">{t.guards.offDuty}</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-amber-50 rounded-lg">
              <XCircle className="h-5 w-5 text-amber-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.onLeave}</p>
              <p className="text-sm text-slate-500">{t.guards.onLeave}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-slate-200 p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input
              type="text"
              placeholder={t.guards.searchPlaceholder}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-50 border-none rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:bg-white transition-all outline-none"
            />
          </div>
          <div className="flex gap-2">
            {(["all", "on-duty", "off-duty", "on-leave"] as const).map((status) => (
              <button
                key={status}
                onClick={() => setStatusFilter(status)}
                className={cn(
                  "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                  statusFilter === status
                    ? "bg-primary text-white"
                    : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                )}
              >
                {status === "all" ? t.common.all : status === "on-duty" ? t.guards.onDuty : status === "off-duty" ? t.guards.offDuty : t.guards.onLeave}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Guards Table */}
      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">{t.guards.guard}</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">{t.guards.status}</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">{t.guards.location}</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">{t.guards.contact}</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">{t.guards.rating}</th>
                <th className="text-right py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">{t.guards.actions}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredGuards.map((guard) => {
                const status = statusConfig[guard.status];
                return (
                  <tr
                    key={guard.id}
                    className="hover:bg-slate-50 transition-colors cursor-pointer group"
                    onClick={() => {
                      setSelectedGuard(guard);
                      setIsProfileModalOpen(true);
                    }}
                  >
                    <td className="py-4 px-4">
                      <div className="flex items-center space-x-3">
                        <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                          <span className="text-sm font-semibold text-primary">{guard.avatar}</span>
                        </div>
                        <div>
                          <p className="font-medium text-slate-900 group-hover:text-primary transition-colors">{guard.name}</p>
                          <p className="text-sm text-slate-500">{guard.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <span className={cn("inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium", status.bg, status.color)}>
                        <status.icon className="h-3 w-3 mr-1" />
                        {guard.status === "on-duty" ? t.guards.onDuty : guard.status === "off-duty" ? t.guards.offDuty : t.guards.onLeave}
                      </span>
                    </td>
                    <td className="py-4 px-4">
                      <div className="flex items-center text-slate-600">
                        <MapPin className="h-4 w-4 mr-1.5 text-slate-400" />
                        <div>
                          <p className="text-sm">{guard.location}</p>
                          <p className="text-xs text-slate-400">{guard.site}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <div className="space-y-1">
                        <div className="flex items-center text-sm text-slate-600">
                          <Phone className="h-3 w-3 mr-1.5 text-slate-400" />
                          {guard.phone}
                        </div>
                        <div className="flex items-center text-sm text-slate-500">
                          <Mail className="h-3 w-3 mr-1.5 text-slate-400" />
                          {guard.email}
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <div className="flex items-center">
                        <Shield className="h-4 w-4 text-amber-400 mr-1" />
                        <span className="font-medium text-slate-900">{guard.rating}</span>
                        <span className="text-slate-400 text-sm">/5</span>
                      </div>
                    </td>
                    <td className="py-4 px-4 text-right">
                      <button className="p-2 hover:bg-slate-100 rounded-lg transition-colors">
                        <MoreHorizontal className="h-4 w-4 text-slate-400" />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {filteredGuards.length === 0 && (
          <div className="py-12 text-center">
            <Users className="h-12 w-12 text-slate-300 mx-auto mb-4" />
            <p className="text-slate-500 font-medium">{t.guards.noGuardsFound}</p>
            <p className="text-slate-400 text-sm mt-1">{t.guards.tryAdjusting}</p>
          </div>
        )}
      </div>

      {/* Add Guard Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl border border-slate-200 w-full max-w-lg overflow-hidden animate-in fade-in zoom-in duration-200">
            <div className="flex items-center justify-between p-6 border-b border-slate-100">
              <h2 className="text-xl font-bold text-slate-900">{t.guards.addNewGuard}</h2>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div className="grid grid-cols-1 gap-4">
                <div className="space-y-1.5">
                  <label htmlFor="name" className="text-sm font-medium text-slate-700">{t.guards.fullName}</label>
                  <input
                    id="name"
                    type="text"
                    required
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none text-slate-900"
                    placeholder="e.g. John Doe"
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <label htmlFor="phone" className="text-sm font-medium text-slate-700">{t.guards.phone}</label>
                    <input
                      id="phone"
                      type="tel"
                      required
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                      className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none text-slate-900"
                      placeholder="+66 8x xxx xxxx"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label htmlFor="email" className="text-sm font-medium text-slate-700">{t.guards.email}</label>
                    <input
                      id="email"
                      type="email"
                      required
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                      className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none text-slate-900"
                      placeholder="john@example.com"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <label htmlFor="location" className="text-sm font-medium text-slate-700">{t.guards.location}</label>
                    <select
                      id="location"
                      required
                      value={formData.location}
                      onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                      className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none text-slate-900"
                    >
                      <option value="">Select Location</option>
                      {locations.map((loc) => (
                        <option key={loc} value={loc}>{loc}</option>
                      ))}
                    </select>
                  </div>
                  <div className="space-y-1.5">
                    <label htmlFor="site" className="text-sm font-medium text-slate-700">{t.guards.site}</label>
                    <input
                      id="site"
                      type="text"
                      required
                      value={formData.site}
                      onChange={(e) => setFormData({ ...formData, site: e.target.value })}
                      className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none text-slate-900"
                      placeholder="e.g. Zone A"
                    />
                  </div>
                </div>

                <div className="space-y-1.5">
                  <label className="text-sm font-medium text-slate-700">{t.guards.status}</label>
                  <div className="flex gap-4">
                    {Object.entries(statusConfig).map(([key, config]) => (
                      <label key={key} className="flex items-center cursor-pointer group">
                        <input
                          type="radio"
                          name="status"
                          value={key}
                          checked={formData.status === key}
                          onChange={(e) => setFormData({ ...formData, status: e.target.value as GuardStatus })}
                          className="sr-only"
                        />
                        <div className={cn(
                          "px-3 py-1.5 rounded-lg border text-xs font-medium transition-all flex items-center gap-1.5",
                          formData.status === key
                            ? "bg-primary border-primary text-white"
                            : "border-slate-200 text-slate-500 hover:border-primary/50 group-hover:text-slate-700"
                        )}>
                          <config.icon className="h-3 w-3" />
                          {key === "on-duty" ? t.guards.onDuty : key === "off-duty" ? t.guards.offDuty : t.guards.onLeave}
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
              </div>

              <div className="pt-4 flex gap-3">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="flex-1 px-4 py-2 border border-slate-200 text-slate-700 rounded-lg text-sm font-medium hover:bg-slate-50 transition-colors"
                >
                  {t.common.cancel}
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-emerald-600 transition-colors shadow-sm"
                >
                  {t.guards.addGuard}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Guard Profile Modal */}
      {isProfileModalOpen && selectedGuard && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl border border-slate-200 w-full max-w-2xl overflow-hidden animate-in fade-in zoom-in duration-200">
            <div className="flex items-center justify-between p-6 border-b border-slate-100">
              <h2 className="text-xl font-bold text-slate-900">รายละเอียดโปรไฟล์เจ้าหน้าที่</h2>
              <button
                onClick={() => setIsProfileModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-full transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            <div className="p-8 overflow-y-auto max-h-[80vh]">
              {/* Header Info */}
              <div className="flex items-start justify-between mb-8">
                <div className="flex items-center gap-6">
                  <div className="w-24 h-24 rounded-2xl bg-primary/10 flex items-center justify-center text-3xl font-bold text-primary shadow-inner">
                    {selectedGuard.avatar}
                  </div>
                  <div>
                    <h3 className="text-2xl font-bold text-slate-900 mb-2">{selectedGuard.name}</h3>
                    <div className="flex items-center gap-3">
                      <span className={cn(
                        "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold",
                        statusConfig[selectedGuard.status].bg,
                        statusConfig[selectedGuard.status].color
                      )}>
                        <div className="w-1.5 h-1.5 rounded-full bg-current mr-2 animate-pulse" />
                        {selectedGuard.status === "on-duty" ? t.guards.onDuty : selectedGuard.status === "off-duty" ? t.guards.offDuty : t.guards.onLeave}
                      </span>
                      <div className="flex items-center gap-1 text-slate-900">
                        <Shield className="h-4 w-4 text-amber-400" />
                        <span className="font-bold">{selectedGuard.rating}</span>
                        <span className="text-slate-400 text-sm font-normal">({selectedGuard.totalTasks} งาน)</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Contact Info Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-6 mb-10">
                <div className="space-y-4">
                  <h4 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wider">ข้อมูลติดต่อ</h4>
                  <div className="flex items-center gap-3 text-slate-600">
                    <Phone className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">{selectedGuard.phone}</span>
                  </div>
                  <div className="flex items-center gap-3 text-slate-600">
                    <MapPin className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">{selectedGuard.location}</span>
                  </div>
                </div>
                <div className="space-y-4 pt-8">
                  <div className="flex items-center gap-3 text-slate-600">
                    <Mail className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">{selectedGuard.email}</span>
                  </div>
                  <div className="flex items-center gap-3 text-slate-600">
                    <Shield className="h-5 w-5 text-slate-400" />
                    <span className="text-sm font-medium">{selectedGuard.experience}</span>
                  </div>
                </div>
              </div>

              {/* Documents Section */}
              <div className="mb-10 pt-6 border-t border-slate-100">
                <h4 className="text-sm font-bold text-slate-900 mb-6 uppercase tracking-wider">เอกสารยืนยันตัวตน</h4>
                <div className="space-y-4">
                  {selectedGuard.documents.map((doc, idx) => (
                    <div key={idx} className="flex items-center justify-between group p-1 rounded-lg hover:bg-slate-50 transition-colors">
                      <span className="text-sm font-medium text-slate-700">{doc.name}</span>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          if (doc.url) setSelectedDoc({ name: doc.name, url: doc.url });
                        }}
                        disabled={!doc.url}
                        className={cn(
                          "text-[10px] font-bold uppercase tracking-widest px-3 py-1.5 rounded-full shadow-sm transition-all",
                          doc.status === "submitted"
                            ? "bg-emerald-400 hover:bg-emerald-500 text-white cursor-pointer active:scale-95"
                            : "bg-amber-400 text-white cursor-default"
                        )}
                      >
                        {doc.status}
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Certificates Tags */}
              <div className="mb-10">
                <h5 className="text-xs font-bold text-slate-900 mb-4">ใบประกาศนียบัตรเพิ่มเติม:</h5>
                <div className="flex flex-wrap gap-2">
                  {selectedGuard.certificates.map((cert) => (
                    <span key={cert} className="px-4 py-1.5 bg-slate-100 text-slate-600 rounded-full text-xs font-bold border border-slate-200">
                      {cert}
                    </span>
                  ))}
                </div>
              </div>

              {/* Experience Text */}
              <div className="pt-6 border-t border-slate-100">
                <h4 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wider">ประวัติการทำงานและผลงาน</h4>
                <p className="text-emerald-600 font-medium mb-4 italic">
                  {selectedGuard.bio}
                </p>
                <div className="flex gap-2">
                  <span className="px-3 py-1 bg-slate-100 text-slate-900 rounded-lg text-xs font-bold">คะแนนสูงสุด</span>
                  <span className="px-3 py-1 bg-slate-100 text-slate-900 rounded-lg text-xs font-bold">เชื่อถือได้</span>
                </div>
              </div>
            </div>

            <div className="p-6 bg-slate-50 border-t border-slate-100 flex gap-4">
              <button
                onClick={() => setIsProfileModalOpen(false)}
                className="flex-1 py-3 px-4 bg-primary text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-all shadow-lg active:scale-95"
              >
                มอบหมายงาน
              </button>
            </div>
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
