"use client";

import { useState } from "react";
import {
  Search,
  Star,
  ChevronDown,
  MoreHorizontal,
  Eye,
  EyeOff,
  AlertTriangle,
  Award,
  Filter,
  RotateCcw,
  Users,
  X,
  Send,
  Trophy,
  Medal,
  Crown,
  Sparkles,
  Check,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

type ReviewStatus = "shown" | "hidden";

interface Review {
  id: string;
  customerName: string;
  guardName: string;
  rating: number;
  comment: string;
  date: string;
  status: ReviewStatus;
  area?: string;
}

const initialReviews: Review[] = [
  {
    id: "R001",
    customerName: "สมชาย วงศ์ทอง",
    guardName: "อนุชา สมบูรณ์",
    rating: 5,
    comment: "บริการดีมาก รักษาความปลอดภัยได้อย่างมีประสิทธิภาพ ตรงเวลาทุกครั้ง",
    date: "2024-01-15",
    status: "shown",
    area: "Central Plaza",
  },
  {
    id: "R002",
    customerName: "สุนีย์ จันทร์แก้ว",
    guardName: "วิเชียร อำนาจ",
    rating: 2,
    comment: "มาสาย และไม่ค่อยใส่ใจในการรักษาความปลอดภัย",
    date: "2024-01-14",
    status: "shown",
    area: "Siam Paragon",
  },
  {
    id: "R003",
    customerName: "ประยุทธ์ ใจดี",
    guardName: "สมพงษ์ แก้วใส",
    rating: 4,
    comment: "ทำงานดี มีความรับผิดชอบ แต่ควรปรับปรุงการสื่อสาร",
    date: "2024-01-13",
    status: "shown",
    area: "EmQuartier",
  },
  {
    id: "R004",
    customerName: "มาลี สีทราช",
    guardName: "อนุชา สมบูรณ์",
    rating: 5,
    comment: "เป็นมืออาชีพมาก พูดจาสุภาพ และทำงานได้ตามมาตรฐาน",
    date: "2024-01-12",
    status: "shown",
    area: "ICONSIAM",
  },
  {
    id: "R005",
    customerName: "วิชัย มั่งคั่ง",
    guardName: "วิเชียร อำนาจ",
    rating: 1,
    comment: "ไม่พอใจมาก ไม่ตรงเวลา และไม่มีความรับผิดชอบ",
    date: "2024-01-11",
    status: "hidden",
    area: "Terminal 21",
  },
  {
    id: "R006",
    customerName: "นภา ศรีสุข",
    guardName: "สมชาย ใจดี",
    rating: 4,
    comment: "ให้บริการดี แต่ควรเพิ่มความรวดเร็วในการตอบสนอง",
    date: "2024-01-10",
    status: "shown",
    area: "MBK Center",
  },
];

const guards = ["ทั้งหมด", "อนุชา สมบูรณ์", "วิเชียร อำนาจ", "สมพงษ์ แก้วใส", "สมชาย ใจดี"];
const areas = ["ทั้งหมด", "Central Plaza", "Siam Paragon", "EmQuartier", "ICONSIAM", "Terminal 21", "MBK Center"];
const ratings = ["ทั้งหมด", "5", "4", "3", "2", "1"];
const statuses = ["ทั้งหมด", "แสดง", "ซ่อน"];

export default function ReviewsPage() {
  const { locale } = useLanguage();
  const [reviews, setReviews] = useState<Review[]>(initialReviews);
  const [searchQuery, setSearchQuery] = useState("");
  const [ratingFilter, setRatingFilter] = useState("ทั้งหมด");
  const [statusFilter, setStatusFilter] = useState("ทั้งหมด");
  const [guardFilter, setGuardFilter] = useState("ทั้งหมด");
  const [areaFilter, setAreaFilter] = useState("ทั้งหมด");
  const [openDropdownId, setOpenDropdownId] = useState<string | null>(null);

  // Modal states
  const [warningModalOpen, setWarningModalOpen] = useState(false);
  const [badgeModalOpen, setBadgeModalOpen] = useState(false);
  const [selectedReview, setSelectedReview] = useState<Review | null>(null);
  const [warningMessage, setWarningMessage] = useState("");
  const [selectedBadge, setSelectedBadge] = useState<string | null>(null);

  // Filter dropdowns state
  const [isRatingOpen, setIsRatingOpen] = useState(false);
  const [isStatusOpen, setIsStatusOpen] = useState(false);
  const [isGuardOpen, setIsGuardOpen] = useState(false);
  const [isAreaOpen, setIsAreaOpen] = useState(false);

  const filteredReviews = reviews.filter((review) => {
    const matchesSearch =
      review.customerName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      review.guardName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      review.comment.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesRating = ratingFilter === "ทั้งหมด" || review.rating === parseInt(ratingFilter);
    const matchesStatus =
      statusFilter === "ทั้งหมด" ||
      (statusFilter === "แสดง" && review.status === "shown") ||
      (statusFilter === "ซ่อน" && review.status === "hidden");
    const matchesGuard = guardFilter === "ทั้งหมด" || review.guardName === guardFilter;
    const matchesArea = areaFilter === "ทั้งหมด" || review.area === areaFilter;
    return matchesSearch && matchesRating && matchesStatus && matchesGuard && matchesArea;
  });

  const handleToggleStatus = (reviewId: string) => {
    setReviews(reviews.map(r =>
      r.id === reviewId ? { ...r, status: r.status === "shown" ? "hidden" : "shown" } : r
    ));
    setOpenDropdownId(null);
  };

  const handleReset = () => {
    setSearchQuery("");
    setRatingFilter("ทั้งหมด");
    setStatusFilter("ทั้งหมด");
    setGuardFilter("ทั้งหมด");
    setAreaFilter("ทั้งหมด");
  };

  const handleOpenWarningModal = (review: Review) => {
    setSelectedReview(review);
    setWarningMessage("");
    setWarningModalOpen(true);
    setOpenDropdownId(null);
  };

  const handleOpenBadgeModal = (review: Review) => {
    setSelectedReview(review);
    setSelectedBadge(null);
    setBadgeModalOpen(true);
    setOpenDropdownId(null);
  };

  const handleSendWarning = () => {
    if (selectedReview && warningMessage.trim()) {
      // In a real app, this would send the warning via API
      console.log(`Warning sent to ${selectedReview.guardName}: ${warningMessage}`);
      setWarningModalOpen(false);
      setSelectedReview(null);
      setWarningMessage("");
    }
  };

  const handleAwardBadge = () => {
    if (selectedReview && selectedBadge) {
      // In a real app, this would award the badge via API
      console.log(`Badge "${selectedBadge}" awarded to ${selectedReview.guardName}`);
      setBadgeModalOpen(false);
      setSelectedReview(null);
      setSelectedBadge(null);
    }
  };

  const badges = [
    { id: "excellent", name: locale === "th" ? "ยอดเยี่ยม" : "Excellent", icon: Trophy, color: "text-amber-500" },
    { id: "professional", name: locale === "th" ? "มืออาชีพ" : "Professional", icon: Medal, color: "text-blue-500" },
    { id: "outstanding", name: locale === "th" ? "โดดเด่น" : "Outstanding", icon: Crown, color: "text-purple-500" },
    { id: "star", name: locale === "th" ? "ดาวเด่น" : "Rising Star", icon: Sparkles, color: "text-pink-500" },
  ];

  const stats = {
    total: reviews.length,
    shown: reviews.filter(r => r.status === "shown").length,
    avgRating: (reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length).toFixed(1),
  };

  const renderStars = (rating: number) => {
    return (
      <div className="flex items-center gap-0.5">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            className={cn(
              "h-4 w-4",
              star <= rating ? "text-amber-400 fill-amber-400" : "text-slate-200"
            )}
          />
        ))}
        <span className="ml-1.5 text-sm text-slate-500">({rating})</span>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">
          {locale === "th" ? "รีวิวและประเมิน" : "Reviews & Evaluation"}
        </h1>
        <p className="text-slate-500 mt-1">
          {locale === "th"
            ? "จัดการรีวิวของลูกค้าและประเมินผลการทำงานของเจ้าหน้าที่รักษาความปลอดภัย"
            : "Manage customer reviews and evaluate security guard performance"}
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="bg-gradient-to-br from-slate-50 to-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-slate-500">{locale === "th" ? "รีวิวทั้งหมด" : "Total Reviews"}</p>
              <p className="text-3xl font-bold text-slate-900 mt-1">{stats.total}</p>
            </div>
            <div className="p-3 bg-slate-100 rounded-xl">
              <Star className="h-6 w-6 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-2xl border border-emerald-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-emerald-600">{locale === "th" ? "กำลังแสดง" : "Visible"}</p>
              <p className="text-3xl font-bold text-emerald-700 mt-1">{stats.shown}</p>
            </div>
            <div className="p-3 bg-emerald-100 rounded-xl">
              <Eye className="h-6 w-6 text-emerald-600" />
            </div>
          </div>
        </div>
        <div className="bg-gradient-to-br from-amber-50 to-white p-5 rounded-2xl border border-amber-100 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-amber-600">{locale === "th" ? "คะแนนเฉลี่ย" : "Avg Rating"}</p>
              <p className="text-3xl font-bold text-amber-700 mt-1">{stats.avgRating}</p>
            </div>
            <div className="p-3 bg-amber-100 rounded-xl">
              <Star className="h-6 w-6 text-amber-600 fill-amber-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
        <div className="flex items-center gap-2 mb-4">
          <Filter className="h-5 w-5 text-slate-400" />
          <h2 className="font-semibold text-slate-700">
            {locale === "th" ? "เครื่องมือค้นหาและกรอง" : "Search & Filter Tools"}
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-6 gap-4">
          {/* Search */}
          <div className="md:col-span-2">
            <label className="text-xs font-medium text-slate-500 mb-1.5 block">{locale === "th" ? "ค้นหา" : "Search"}</label>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
              <input
                type="text"
                placeholder={locale === "th" ? "ค้นหาลูกค้า, เจ้าหน้าที่..." : "Search customer, guard..."}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl py-2.5 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
              />
            </div>
          </div>

          {/* Rating Filter */}
          <div className="relative">
            <label className="text-xs font-medium text-slate-500 mb-1.5 block">{locale === "th" ? "คะแนน" : "Rating"}</label>
            <button
              onClick={() => { setIsRatingOpen(!isRatingOpen); setIsStatusOpen(false); setIsGuardOpen(false); setIsAreaOpen(false); }}
              className="w-full flex items-center justify-between px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 hover:bg-slate-100 transition-colors"
            >
              <span>{ratingFilter}</span>
              <ChevronDown className={cn("h-4 w-4 transition-transform", isRatingOpen && "rotate-180")} />
            </button>
            {isRatingOpen && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl border border-slate-200 shadow-lg py-1 z-50">
                {ratings.map((r) => (
                  <button
                    key={r}
                    onClick={() => { setRatingFilter(r); setIsRatingOpen(false); }}
                    className={cn(
                      "w-full px-4 py-2 text-sm text-left transition-colors",
                      ratingFilter === r ? "bg-primary/10 text-primary font-medium" : "text-slate-700 hover:bg-slate-50"
                    )}
                  >
                    {r}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Status Filter */}
          <div className="relative">
            <label className="text-xs font-medium text-slate-500 mb-1.5 block">{locale === "th" ? "สถานะ" : "Status"}</label>
            <button
              onClick={() => { setIsStatusOpen(!isStatusOpen); setIsRatingOpen(false); setIsGuardOpen(false); setIsAreaOpen(false); }}
              className="w-full flex items-center justify-between px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 hover:bg-slate-100 transition-colors"
            >
              <span>{statusFilter}</span>
              <ChevronDown className={cn("h-4 w-4 transition-transform", isStatusOpen && "rotate-180")} />
            </button>
            {isStatusOpen && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl border border-slate-200 shadow-lg py-1 z-50">
                {statuses.map((s) => (
                  <button
                    key={s}
                    onClick={() => { setStatusFilter(s); setIsStatusOpen(false); }}
                    className={cn(
                      "w-full px-4 py-2 text-sm text-left transition-colors",
                      statusFilter === s ? "bg-primary/10 text-primary font-medium" : "text-slate-700 hover:bg-slate-50"
                    )}
                  >
                    {s}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Guard Filter */}
          <div className="relative">
            <label className="text-xs font-medium text-slate-500 mb-1.5 block">{locale === "th" ? "เจ้าหน้าที่" : "Guard"}</label>
            <button
              onClick={() => { setIsGuardOpen(!isGuardOpen); setIsRatingOpen(false); setIsStatusOpen(false); setIsAreaOpen(false); }}
              className="w-full flex items-center justify-between px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 hover:bg-slate-100 transition-colors"
            >
              <span className="truncate">{guardFilter}</span>
              <ChevronDown className={cn("h-4 w-4 transition-transform flex-shrink-0", isGuardOpen && "rotate-180")} />
            </button>
            {isGuardOpen && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl border border-slate-200 shadow-lg py-1 z-50">
                {guards.map((g) => (
                  <button
                    key={g}
                    onClick={() => { setGuardFilter(g); setIsGuardOpen(false); }}
                    className={cn(
                      "w-full px-4 py-2 text-sm text-left transition-colors",
                      guardFilter === g ? "bg-primary/10 text-primary font-medium" : "text-slate-700 hover:bg-slate-50"
                    )}
                  >
                    {g}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Area Filter */}
          <div className="relative">
            <label className="text-xs font-medium text-slate-500 mb-1.5 block">{locale === "th" ? "พื้นที่" : "Area"}</label>
            <button
              onClick={() => { setIsAreaOpen(!isAreaOpen); setIsRatingOpen(false); setIsStatusOpen(false); setIsGuardOpen(false); }}
              className="w-full flex items-center justify-between px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 hover:bg-slate-100 transition-colors"
            >
              <span className="truncate">{areaFilter}</span>
              <ChevronDown className={cn("h-4 w-4 transition-transform flex-shrink-0", isAreaOpen && "rotate-180")} />
            </button>
            {isAreaOpen && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl border border-slate-200 shadow-lg py-1 z-50">
                {areas.map((a) => (
                  <button
                    key={a}
                    onClick={() => { setAreaFilter(a); setIsAreaOpen(false); }}
                    className={cn(
                      "w-full px-4 py-2 text-sm text-left transition-colors",
                      areaFilter === a ? "bg-primary/10 text-primary font-medium" : "text-slate-700 hover:bg-slate-50"
                    )}
                  >
                    {a}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3 mt-4 justify-end">
          <button
            onClick={handleReset}
            className="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors flex items-center gap-2"
          >
            <RotateCcw className="h-4 w-4" />
            {locale === "th" ? "รีเซ็ต" : "Reset"}
          </button>
          <button className="px-6 py-2 text-sm font-medium text-white bg-primary rounded-xl hover:bg-emerald-600 transition-colors flex items-center gap-2">
            <Search className="h-4 w-4" />
            {locale === "th" ? "ค้นหา" : "Search"}
          </button>
        </div>
      </div>

      {/* Reviews Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm">
        <div className="p-5 border-b border-slate-100">
          <h2 className="text-lg font-bold text-slate-900">
            {locale === "th" ? `ตารางรีวิวทั้งหมด (${filteredReviews.length} รายการ)` : `All Reviews (${filteredReviews.length} items)`}
          </h2>
          <p className="text-sm text-slate-500 mt-0.5">
            {locale === "th" ? "แสดงรีวิวและประเมินจากลูกค้าทั้งหมด" : "Display all customer reviews and evaluations"}
          </p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50/80 border-b border-slate-200">
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ลูกค้า" : "Customer"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "เจ้าหน้าที่" : "Guard"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "คะแนน" : "Rating"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "ความเห็น" : "Comment"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "วันที่" : "Date"}</th>
                <th className="text-left py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "สถานะการแสดงผล" : "Display Status"}</th>
                <th className="text-right py-4 px-5 text-xs font-bold text-slate-500 uppercase tracking-wider">{locale === "th" ? "การดำเนินการ" : "Actions"}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredReviews.map((review) => (
                <tr key={review.id} className="hover:bg-slate-50/50 transition-colors">
                  <td className="py-4 px-5">
                    <p className="font-medium text-slate-900">{review.customerName}</p>
                  </td>
                  <td className="py-4 px-5">
                    <p className="text-sm font-medium text-primary">{review.guardName}</p>
                  </td>
                  <td className="py-4 px-5">
                    {renderStars(review.rating)}
                  </td>
                  <td className="py-4 px-5">
                    <p className="text-sm text-slate-600 max-w-xs truncate" title={review.comment}>
                      {review.comment}
                    </p>
                  </td>
                  <td className="py-4 px-5">
                    <p className="text-sm text-slate-500">{review.date}</p>
                  </td>
                  <td className="py-4 px-5">
                    <span className={cn(
                      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
                      review.status === "shown"
                        ? "bg-emerald-100 text-emerald-700"
                        : "bg-slate-100 text-slate-600"
                    )}>
                      {review.status === "shown" ? (
                        <>
                          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                          {locale === "th" ? "แสดง" : "Shown"}
                        </>
                      ) : (
                        <>
                          <span className="w-1.5 h-1.5 rounded-full bg-slate-400"></span>
                          {locale === "th" ? "ซ่อน" : "Hidden"}
                        </>
                      )}
                    </span>
                  </td>
                  <td className="py-4 px-5 text-right relative">
                    <button
                      onClick={() => setOpenDropdownId(openDropdownId === review.id ? null : review.id)}
                      className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                    >
                      <MoreHorizontal className="h-4 w-4 text-slate-400" />
                    </button>

                    {openDropdownId === review.id && (
                      <div className="absolute right-5 top-full mt-1 w-56 bg-white rounded-xl border border-slate-200 shadow-xl py-2 z-50">
                        <button
                          onClick={() => handleToggleStatus(review.id)}
                          className="w-full px-4 py-2.5 text-sm text-left text-slate-700 hover:bg-slate-50 flex items-center gap-3"
                        >
                          {review.status === "shown" ? (
                            <>
                              <EyeOff className="h-4 w-4 text-slate-400" />
                              {locale === "th" ? "ซ่อนรีวิวนี้" : "Hide this review"}
                            </>
                          ) : (
                            <>
                              <Eye className="h-4 w-4 text-slate-400" />
                              {locale === "th" ? "แสดงรีวิวนี้" : "Show this review"}
                            </>
                          )}
                        </button>
                        <button
                          onClick={() => handleOpenWarningModal(review)}
                          className="w-full px-4 py-2.5 text-sm text-left text-slate-700 hover:bg-slate-50 flex items-center gap-3"
                        >
                          <AlertTriangle className="h-4 w-4 text-amber-500" />
                          {locale === "th" ? "ส่งคำเตือนถึงเจ้าหน้าที่" : "Send warning to guard"}
                        </button>
                        <button
                          onClick={() => handleOpenBadgeModal(review)}
                          className="w-full px-4 py-2.5 text-sm text-left text-slate-700 hover:bg-slate-50 flex items-center gap-3"
                        >
                          <Award className="h-4 w-4 text-primary" />
                          {locale === "th" ? "มอบรางวัล / Badge" : "Award badge"}
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredReviews.length === 0 && (
          <div className="py-16 text-center">
            <div className="w-16 h-16 bg-slate-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Users className="h-8 w-8 text-slate-400" />
            </div>
            <p className="text-slate-500 font-medium">{locale === "th" ? "ไม่พบรีวิว" : "No reviews found"}</p>
          </div>
        )}
      </div>

      {/* Warning Modal */}
      {warningModalOpen && selectedReview && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-amber-100 rounded-xl">
                  <AlertTriangle className="h-5 w-5 text-amber-600" />
                </div>
                <div>
                  <h2 className="text-lg font-bold text-slate-900">
                    {locale === "th" ? "ส่งคำเตือนถึงเจ้าหน้าที่" : "Send Warning to Guard"}
                  </h2>
                  <p className="text-sm text-slate-500">{selectedReview.guardName}</p>
                </div>
              </div>
              <button
                onClick={() => { setWarningModalOpen(false); setSelectedReview(null); }}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-5 space-y-4">
              {/* Review Reference */}
              <div className="bg-slate-50 rounded-xl p-4">
                <p className="text-xs font-medium text-slate-500 mb-2">
                  {locale === "th" ? "รีวิวที่เกี่ยวข้อง" : "Related Review"}
                </p>
                <div className="flex items-start gap-3">
                  <div className="flex-1">
                    <p className="text-sm font-medium text-slate-900">{selectedReview.customerName}</p>
                    <div className="flex items-center gap-1 mt-1">
                      {[1, 2, 3, 4, 5].map((star) => (
                        <Star
                          key={star}
                          className={cn(
                            "h-3.5 w-3.5",
                            star <= selectedReview.rating ? "text-amber-400 fill-amber-400" : "text-slate-200"
                          )}
                        />
                      ))}
                    </div>
                    <p className="text-sm text-slate-600 mt-2 line-clamp-2">{selectedReview.comment}</p>
                  </div>
                </div>
              </div>

              {/* Warning Message */}
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "ข้อความคำเตือน" : "Warning Message"}
                </label>
                <textarea
                  value={warningMessage}
                  onChange={(e) => setWarningMessage(e.target.value)}
                  placeholder={locale === "th" ? "กรุณาระบุรายละเอียดคำเตือน..." : "Please specify warning details..."}
                  rows={4}
                  className="w-full bg-slate-50 border border-slate-200 rounded-xl py-3 px-4 text-sm focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 focus:bg-white transition-all outline-none resize-none"
                />
              </div>
            </div>

            {/* Modal Footer */}
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => { setWarningModalOpen(false); setSelectedReview(null); }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleSendWarning}
                disabled={!warningMessage.trim()}
                className={cn(
                  "flex-1 px-4 py-2.5 text-sm font-medium text-white rounded-xl flex items-center justify-center gap-2 transition-colors",
                  warningMessage.trim()
                    ? "bg-amber-500 hover:bg-amber-600"
                    : "bg-slate-300 cursor-not-allowed"
                )}
              >
                <Send className="h-4 w-4" />
                {locale === "th" ? "ส่งคำเตือน" : "Send Warning"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Badge Award Modal */}
      {badgeModalOpen && selectedReview && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-primary/10 rounded-xl">
                  <Award className="h-5 w-5 text-primary" />
                </div>
                <div>
                  <h2 className="text-lg font-bold text-slate-900">
                    {locale === "th" ? "มอบรางวัล / Badge" : "Award Badge"}
                  </h2>
                  <p className="text-sm text-slate-500">{selectedReview.guardName}</p>
                </div>
              </div>
              <button
                onClick={() => { setBadgeModalOpen(false); setSelectedReview(null); }}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            {/* Modal Body */}
            <div className="p-5 space-y-4">
              {/* Review Reference */}
              <div className="bg-slate-50 rounded-xl p-4">
                <p className="text-xs font-medium text-slate-500 mb-2">
                  {locale === "th" ? "รีวิวที่เกี่ยวข้อง" : "Related Review"}
                </p>
                <div className="flex items-start gap-3">
                  <div className="flex-1">
                    <p className="text-sm font-medium text-slate-900">{selectedReview.customerName}</p>
                    <div className="flex items-center gap-1 mt-1">
                      {[1, 2, 3, 4, 5].map((star) => (
                        <Star
                          key={star}
                          className={cn(
                            "h-3.5 w-3.5",
                            star <= selectedReview.rating ? "text-amber-400 fill-amber-400" : "text-slate-200"
                          )}
                        />
                      ))}
                    </div>
                    <p className="text-sm text-slate-600 mt-2 line-clamp-2">{selectedReview.comment}</p>
                  </div>
                </div>
              </div>

              {/* Badge Selection */}
              <div>
                <label className="text-sm font-medium text-slate-700 mb-3 block">
                  {locale === "th" ? "เลือก Badge ที่ต้องการมอบ" : "Select Badge to Award"}
                </label>
                <div className="grid grid-cols-2 gap-3">
                  {badges.map((badge) => {
                    const IconComponent = badge.icon;
                    return (
                      <button
                        key={badge.id}
                        onClick={() => setSelectedBadge(badge.id)}
                        className={cn(
                          "relative p-4 rounded-xl border-2 transition-all flex flex-col items-center gap-2",
                          selectedBadge === badge.id
                            ? "border-primary bg-primary/5"
                            : "border-slate-200 hover:border-slate-300 hover:bg-slate-50"
                        )}
                      >
                        {selectedBadge === badge.id && (
                          <div className="absolute top-2 right-2">
                            <Check className="h-4 w-4 text-primary" />
                          </div>
                        )}
                        <div className={cn("p-3 rounded-xl bg-slate-100", selectedBadge === badge.id && "bg-primary/10")}>
                          <IconComponent className={cn("h-6 w-6", badge.color)} />
                        </div>
                        <span className={cn(
                          "text-sm font-medium",
                          selectedBadge === badge.id ? "text-primary" : "text-slate-700"
                        )}>
                          {badge.name}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => { setBadgeModalOpen(false); setSelectedReview(null); }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleAwardBadge}
                disabled={!selectedBadge}
                className={cn(
                  "flex-1 px-4 py-2.5 text-sm font-medium text-white rounded-xl flex items-center justify-center gap-2 transition-colors",
                  selectedBadge
                    ? "bg-primary hover:bg-emerald-600"
                    : "bg-slate-300 cursor-not-allowed"
                )}
              >
                <Award className="h-4 w-4" />
                {locale === "th" ? "มอบรางวัล" : "Award Badge"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
