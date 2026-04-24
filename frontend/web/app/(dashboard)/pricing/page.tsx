"use client";

import { useState, useEffect, useCallback } from "react";
import {
  DollarSign,
  Plus,
  Trash2,
  Edit3,
  MapPin,
  History,
  X,
  Save,
  Calculator,
  Gift,
  Clock,
  Loader2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { pricingApi, type ServiceRateResponse } from "@/lib/api";

type PricingTab = "services" | "commission" | "areas" | "flexibility" | "promotions" | "history";

interface ServiceRate {
  id: string;
  name: string;
  description: string | null;
  baseFee: number;
  minHours: number;
  notes: string;
}

interface AreaRate {
  id: string;
  province: string;
  area: string;
  rate: number;
}

interface Promotion {
  id: string;
  name: string;
  code: string;
  discount: number;
  expiryDate: string;
  status: "active" | "inactive";
}

interface PriceHistory {
  id: string;
  date: string;
  admin: string;
  changeType: string;
  oldValue: string;
  newValue: string;
}

/** Map API response to local ServiceRate shape */
function toServiceRate(r: ServiceRateResponse): ServiceRate {
  return {
    id: r.id,
    name: r.name,
    description: r.description,
    baseFee: r.base_fee,
    minHours: r.min_hours,
    notes: r.notes ?? "",
  };
}

const initialAreaRates: AreaRate[] = [
  { id: "A001", province: "กรุงเทพฯ", area: "เขตเมือง", rate: 100 },
  { id: "A002", province: "กรุงเทพฯ", area: "เขตชานเมือง", rate: 90 },
  { id: "A003", province: "ต่างจังหวัด", area: "เมืองหลัก", rate: 90 },
  { id: "A004", province: "ต่างจังหวัด", area: "ชนบท", rate: 80 },
];

const initialPromotions: Promotion[] = [
  { id: "P001", name: "ส่วนลดสมาชิกใหม่", code: "NEW2024", discount: 20, expiryDate: "2024-12-31", status: "active" },
  { id: "P002", name: "แพ็กเกจรายเดือน", code: "MONTHLY", discount: 15, expiryDate: "2024-12-31", status: "active" },
  { id: "P003", name: "ส่วนลดช่วงเทศกาล", code: "FESTIVE10", discount: 10, expiryDate: "2024-02-28", status: "inactive" },
];

const initialPriceHistory: PriceHistory[] = [
  { id: "H001", date: "2024-01-15", admin: "ผู้ดูแลระบบ A", changeType: "บอดี้การ์ด", oldValue: "฿700-฿1,400", newValue: "฿800-฿1,500" },
  { id: "H002", date: "2024-01-10", admin: "ผู้ดูแลระบบ B", changeType: "ค่าคอมมิชชัน", oldValue: "10%", newValue: "15%" },
  { id: "H003", date: "2024-01-05", admin: "ผู้ดูแลระบบ A", changeType: "กรุงเทพฯ - เขตเมือง", oldValue: "฿90/ชม.", newValue: "฿100/ชม." },
  { id: "H004", date: "2024-01-02", admin: "ผู้ดูแลระบบ B", changeType: "เพิ่มโปรโมชัน", oldValue: "-", newValue: "NEW2024 (20%)" },
];

export default function PricingPage() {
  const { locale } = useLanguage();
  const [activeTab, setActiveTab] = useState<PricingTab>("services");
  const [serviceRates, setServiceRates] = useState<ServiceRate[]>([]);
  const [loadingServices, setLoadingServices] = useState(true);

  const loadServiceRates = useCallback(async () => {
    try {
      setLoadingServices(true);
      const data = await pricingApi.listServiceRates();
      setServiceRates(data.map(toServiceRate));
    } catch {
      // keep current state on error
    } finally {
      setLoadingServices(false);
    }
  }, []);

  useEffect(() => {
    loadServiceRates();
  }, [loadServiceRates]);
  const [areaRates, setAreaRates] = useState<AreaRate[]>(initialAreaRates);
  const [promotions, setPromotions] = useState<Promotion[]>(initialPromotions);
  const [priceHistory] = useState<PriceHistory[]>(initialPriceHistory);

  // Commission settings
  const [commissionRate, setCommissionRate] = useState(15);
  const [noTipCommission, setNoTipCommission] = useState(true);

  // Price flexibility settings
  const [flexiblePricing, setFlexiblePricing] = useState(true);
  const [maxDiscount, setMaxDiscount] = useState(10);
  const [maxIncrease, setMaxIncrease] = useState(20);

  // Modals
  const [addServiceModalOpen, setAddServiceModalOpen] = useState(false);
  const [editServiceModalOpen, setEditServiceModalOpen] = useState(false);
  const [editingService, setEditingService] = useState<ServiceRate | null>(null);
  const [addPromotionModalOpen, setAddPromotionModalOpen] = useState(false);
  const [editAreaModalOpen, setEditAreaModalOpen] = useState(false);
  const [selectedArea, setSelectedArea] = useState<AreaRate | null>(null);

  const [addServiceError, setAddServiceError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [pendingDeleteId, setPendingDeleteId] = useState<string | null>(null);
  const [pendingDeleteName, setPendingDeleteName] = useState<string>("");

  // New service form
  const [newService, setNewService] = useState<Partial<ServiceRate>>({
    name: "",
    baseFee: 0,
    minHours: 6,
    notes: "",
  });

  // New promotion form
  const [newPromotion, setNewPromotion] = useState<Partial<Promotion>>({
    name: "",
    code: "",
    discount: 0,
    expiryDate: "",
    status: "active",
  });

  // Only "services" is wired to the backend today. Commission, area
  // pricing, flexibility bounds, promotions, and history are all UI-only
  // mocks stored in local component state — they don't persist, so we
  // hide them from operators rather than ship a misleading surface.
  // Re-enable each entry here when its backend lands (see code-review-deep.md M1).
  const tabs: { id: PricingTab; label: string; labelEn: string; icon: typeof DollarSign }[] = [
    { id: "services", label: "อัตราค่าบริการ", labelEn: "Service Rates", icon: DollarSign },
  ];

  const handleAddService = async () => {
    const name = (newService.name ?? "").trim();
    const baseFee = newService.baseFee ?? 0;
    if (!name) {
      setAddServiceError(locale === "th" ? "กรุณากรอกชื่อบริการ" : "Service name is required");
      return;
    }
    if (baseFee < 0) {
      setAddServiceError(
        locale === "th" ? "ค่าบริการต้องไม่ติดลบ" : "Base fee cannot be negative",
      );
      return;
    }
    setAddServiceError(null);
    try {
      await pricingApi.createServiceRate({
        name,
        base_fee: baseFee,
        min_hours: newService.minHours ?? 6,
        notes: newService.notes || undefined,
      });
      setNewService({ name: "", baseFee: 0, minHours: 6, notes: "" });
      setAddServiceModalOpen(false);
      loadServiceRates();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setAddServiceError(msg || (locale === "th" ? "บันทึกไม่สำเร็จ" : "Failed to save"));
    }
  };

  const requestDeleteService = (svc: ServiceRate) => {
    setPendingDeleteId(svc.id);
    setPendingDeleteName(svc.name);
    setActionError(null);
  };

  const cancelDeleteService = () => {
    setPendingDeleteId(null);
    setPendingDeleteName("");
  };

  const confirmDeleteService = async () => {
    if (!pendingDeleteId) return;
    const id = pendingDeleteId;
    setActionError(null);
    try {
      await pricingApi.deleteServiceRate(id);
      setPendingDeleteId(null);
      setPendingDeleteName("");
      loadServiceRates();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setActionError(msg || (locale === "th" ? "ลบไม่สำเร็จ" : "Delete failed"));
    }
  };

  const handleOpenEditService = (service: ServiceRate) => {
    setEditingService({ ...service });
    setEditServiceModalOpen(true);
  };

  const handleUpdateService = async () => {
    if (!editingService) return;
    setActionError(null);
    try {
      await pricingApi.updateServiceRate(editingService.id, {
        name: editingService.name,
        base_fee: editingService.baseFee,
        min_hours: editingService.minHours,
        notes: editingService.notes || undefined,
      });
      setEditServiceModalOpen(false);
      setEditingService(null);
      loadServiceRates();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setActionError(msg || (locale === "th" ? "บันทึกไม่สำเร็จ" : "Update failed"));
    }
  };

  const handleAddPromotion = () => {
    if (newPromotion.name && newPromotion.code && newPromotion.discount) {
      setPromotions([...promotions, {
        id: `P${Date.now()}`,
        name: newPromotion.name,
        code: newPromotion.code,
        discount: newPromotion.discount || 0,
        expiryDate: newPromotion.expiryDate || "",
        status: newPromotion.status as "active" | "inactive" || "active",
      }]);
      setNewPromotion({ name: "", code: "", discount: 0, expiryDate: "", status: "active" });
      setAddPromotionModalOpen(false);
    }
  };

  const handleTogglePromotionStatus = (id: string) => {
    setPromotions(promotions.map(p =>
      p.id === id ? { ...p, status: p.status === "active" ? "inactive" : "active" } : p
    ));
  };

  const handleDeletePromotion = (id: string) => {
    setPromotions(promotions.filter(p => p.id !== id));
  };

  const handleEditArea = (area: AreaRate) => {
    setSelectedArea(area);
    setEditAreaModalOpen(true);
  };

  const handleSaveArea = () => {
    if (selectedArea) {
      setAreaRates(areaRates.map(a =>
        a.id === selectedArea.id ? selectedArea : a
      ));
      setEditAreaModalOpen(false);
      setSelectedArea(null);
    }
  };

  // Example calculation
  const exampleServiceFee = 1000;
  const exampleTip = 200;
  const exampleCommission = (exampleServiceFee * commissionRate) / 100;
  const exampleGuardReceives = exampleServiceFee - exampleCommission + exampleTip;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">
          {locale === "th" ? "กำหนดราคา" : "Pricing Management"}
        </h1>
        <p className="text-slate-500 mt-1">
          {locale === "th"
            ? "กำหนดอัตราค่าบริการ ค่าคอมมิชชัน และโปรโมชัน"
            : "Set service rates, commissions, and promotions"}
        </p>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Sidebar */}
        <div className="lg:w-64 flex-shrink-0">
          <div className="bg-white rounded-xl border border-slate-200 p-2">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors",
                  activeTab === tab.id
                    ? "bg-emerald-50 text-emerald-700"
                    : "text-slate-600 hover:bg-slate-50"
                )}
              >
                <tab.icon className={cn("h-5 w-5", activeTab === tab.id ? "text-emerald-600" : "text-slate-400")} />
                {locale === "th" ? tab.label : tab.labelEn}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 bg-white rounded-xl border border-slate-200 p-6">
          {/* Services Tab */}
          {activeTab === "services" && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-semibold text-slate-900">
                    {locale === "th" ? "ตารางอัตราค่าบริการ" : "Service Rate Table"}
                  </h2>
                  <p className="text-sm text-slate-500 mt-1">
                    {locale === "th"
                      ? "กำหนดค่าบริการพื้นฐานและชั่วโมงขั้นต่ำสำหรับแต่ละประเภทบริการ"
                      : "Set base fee and minimum hours for each service type"}
                  </p>
                </div>
                <button
                  onClick={() => setAddServiceModalOpen(true)}
                  className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-lg hover:bg-emerald-600 transition-colors flex items-center gap-2"
                >
                  <Plus className="h-4 w-4" />
                  {locale === "th" ? "เพิ่มบริการ" : "Add Service"}
                </button>
              </div>

              {actionError && (
                <div className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                  <span className="flex-1">{actionError}</span>
                  <button
                    onClick={() => setActionError(null)}
                    className="text-red-600 hover:text-red-800 font-medium"
                  >
                    {locale === "th" ? "ปิด" : "Dismiss"}
                  </button>
                </div>
              )}

              {loadingServices ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-6 w-6 text-primary animate-spin" />
                </div>
              ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-slate-200">
                      <th className="text-left py-3 px-4 text-xs font-bold text-slate-500 uppercase">{locale === "th" ? "ประเภทบริการ" : "Service Type"}</th>
                      <th className="text-right py-3 px-4 text-xs font-bold text-slate-500 uppercase">{locale === "th" ? "ค่าบริการพื้นฐาน" : "Base Fee"}</th>
                      <th className="text-center py-3 px-4 text-xs font-bold text-slate-500 uppercase">{locale === "th" ? "ชม.ขั้นต่ำ" : "Min Hrs"}</th>
                      <th className="text-left py-3 px-4 text-xs font-bold text-slate-500 uppercase">{locale === "th" ? "หมายเหตุ" : "Notes"}</th>
                      <th className="text-right py-3 px-4 text-xs font-bold text-slate-500 uppercase"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {serviceRates.map((service) => (
                      <tr key={service.id} className="hover:bg-slate-50">
                        <td className="py-3 px-4 font-medium text-slate-900">{service.name}</td>
                        <td className="py-3 px-4 text-right text-sm font-bold text-emerald-600">฿{service.baseFee}</td>
                        <td className="py-3 px-4 text-center">
                          <span className="inline-flex items-center gap-1 px-2 py-1 bg-slate-100 rounded text-xs font-medium text-slate-600">
                            <Clock className="h-3 w-3" />
                            {service.minHours}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-sm text-slate-500 max-w-[200px] truncate">{service.notes}</td>
                        <td className="py-3 px-4 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => handleOpenEditService(service)}
                              className="p-1.5 text-primary hover:bg-emerald-50 rounded transition-colors"
                              title={locale === "th" ? "แก้ไข" : "Edit"}
                            >
                              <Edit3 className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => requestDeleteService(service)}
                              className="p-1.5 text-red-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors"
                              title={locale === "th" ? "ลบ" : "Delete"}
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              )}
            </div>
          )}

          {/* Commission Tab */}
          {activeTab === "commission" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  {locale === "th" ? "ค่าคอมมิชชันของระบบ" : "System Commission"}
                </h2>
                <p className="text-sm text-slate-500 mt-1">
                  {locale === "th"
                    ? "กำหนดอัตราค่าคอมมิชชันที่จะหักจากค่าบริการ"
                    : "Set the commission rate to deduct from service fees"}
                </p>
              </div>

              <div className="space-y-4">
                <div className="p-4 bg-slate-50 rounded-lg">
                  <label className="text-sm font-medium text-slate-700 block mb-3">
                    {locale === "th" ? "อัตราค่าคอมมิชชัน:" : "Commission Rate:"} <span className="text-primary font-bold">{commissionRate}%</span>
                  </label>
                  <input
                    type="range"
                    min="0"
                    max="30"
                    value={commissionRate}
                    onChange={(e) => setCommissionRate(parseInt(e.target.value))}
                    className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-primary"
                  />
                  <p className="text-xs text-slate-500 mt-2">
                    {locale === "th"
                      ? `ระบบจะหักค่าคอมมิชชัน ${commissionRate}% จากยอดรวมของแต่ละงาน`
                      : `System will deduct ${commissionRate}% commission from total of each job`}
                  </p>
                </div>

                <div className="p-4 bg-slate-50 rounded-lg flex items-center justify-between">
                  <div>
                    <p className="font-medium text-slate-900">
                      {locale === "th" ? "ไม่หักค่าคอมมิชชันจากทิป" : "No Commission on Tips"}
                    </p>
                    <p className="text-sm text-slate-500">
                      {locale === "th"
                        ? "เงินทิปจะโอนไปให้เจ้าหน้าที่โดยตรง"
                        : "Tips will be transferred directly to the guard"}
                    </p>
                  </div>
                  <button
                    onClick={() => setNoTipCommission(!noTipCommission)}
                    className={cn(
                      "relative w-11 h-6 rounded-full transition-colors",
                      noTipCommission ? "bg-primary" : "bg-slate-300"
                    )}
                  >
                    <span className={cn(
                      "absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-transform",
                      noTipCommission ? "translate-x-6" : "translate-x-1"
                    )} />
                  </button>
                </div>
              </div>

              {/* Calculation Example */}
              <div className="pt-4 border-t border-slate-200">
                <h3 className="text-sm font-medium text-slate-700 flex items-center gap-2 mb-4">
                  <Calculator className="h-4 w-4 text-primary" />
                  {locale === "th" ? "ตัวอย่างการคำนวณ" : "Calculation Example"}
                </h3>
                <div className="bg-emerald-50 rounded-lg p-4 space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-600">{locale === "th" ? "ค่าบริการ:" : "Service Fee:"}</span>
                    <span className="font-medium text-slate-900">฿{exampleServiceFee.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-600">{locale === "th" ? "ทิป:" : "Tip:"}</span>
                    <span className="font-medium text-slate-900">฿{exampleTip.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-600">{locale === "th" ? `ค่าคอมมิชชัน (${commissionRate}%):` : `Commission (${commissionRate}%):`}</span>
                    <span className="font-medium text-red-500">-฿{exampleCommission.toLocaleString()}</span>
                  </div>
                  <div className="pt-2 border-t border-emerald-200 flex justify-between">
                    <span className="font-bold text-emerald-700">{locale === "th" ? "เจ้าหน้าที่รับ:" : "Guard Receives:"}</span>
                    <span className="font-bold text-emerald-700">฿{exampleGuardReceives.toLocaleString()}</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Areas Tab */}
          {activeTab === "areas" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  {locale === "th" ? "กำหนดราคาตามพื้นที่" : "Area-based Pricing"}
                </h2>
                <p className="text-sm text-slate-500 mt-1">
                  {locale === "th"
                    ? "ตั้งราคาที่แตกต่างกันสำหรับแต่ละจังหวัดและเขตพื้นที่"
                    : "Set different prices for each province and area"}
                </p>
              </div>

              <div className="space-y-3">
                {areaRates.map((area) => (
                  <div key={area.id} className="p-4 bg-slate-50 rounded-lg flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="p-2 bg-white rounded-lg">
                        <MapPin className="h-5 w-5 text-slate-600" />
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">{area.province}</p>
                        <p className="text-sm text-slate-500">{area.area}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-4">
                      <span className="text-lg font-bold text-emerald-600">฿{area.rate}/{locale === "th" ? "ชม." : "hr"}</span>
                      <button
                        onClick={() => handleEditArea(area)}
                        className="text-sm text-primary font-medium hover:underline"
                      >
                        {locale === "th" ? "แก้ไข" : "Edit"}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Flexibility Tab */}
          {activeTab === "flexibility" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  {locale === "th" ? "ขอบเขตราคา" : "Price Range"}
                </h2>
                <p className="text-sm text-slate-500 mt-1">
                  {locale === "th"
                    ? "กำหนดโมเดลการตั้งราคาและขอบเขตราคาที่อนุญาต"
                    : "Set pricing model and allowed price range"}
                </p>
              </div>

              <div className="space-y-4">
                <div className="p-4 bg-slate-50 rounded-lg flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className={cn("p-2 rounded-lg", flexiblePricing ? "bg-primary/10" : "bg-slate-200")}>
                      <DollarSign className={cn("h-5 w-5", flexiblePricing ? "text-primary" : "text-slate-500")} />
                    </div>
                    <div>
                      <p className="font-medium text-slate-900">
                        {locale === "th" ? "ราคาที่ยืดหยุ่นได้" : "Flexible Pricing"}
                      </p>
                      <p className="text-sm text-slate-500">
                        {locale === "th"
                          ? "ลูกค้าและเจ้าหน้าที่สามารถต่อรองราคาได้"
                          : "Customers and guards can negotiate prices"}
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => setFlexiblePricing(!flexiblePricing)}
                    className={cn(
                      "relative w-11 h-6 rounded-full transition-colors",
                      flexiblePricing ? "bg-primary" : "bg-slate-300"
                    )}
                  >
                    <span className={cn(
                      "absolute top-1 w-4 h-4 bg-white rounded-full shadow transition-transform",
                      flexiblePricing ? "translate-x-6" : "translate-x-1"
                    )} />
                  </button>
                </div>

                {flexiblePricing && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                    <div>
                      <label className="block text-sm font-medium text-slate-700 mb-2">
                        {locale === "th" ? "ส่วนลดสูงสุดที่อนุญาต (%)" : "Max Discount Allowed (%)"}
                      </label>
                      <input
                        type="number"
                        value={maxDiscount}
                        onChange={(e) => setMaxDiscount(parseInt(e.target.value) || 0)}
                        className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-slate-700 mb-2">
                        {locale === "th" ? "การเพิ่มราคาสูงสุดที่อนุญาต (%)" : "Max Increase Allowed (%)"}
                      </label>
                      <input
                        type="number"
                        value={maxIncrease}
                        onChange={(e) => setMaxIncrease(parseInt(e.target.value) || 0)}
                        className="w-full px-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                      />
                    </div>
                  </div>
                )}
              </div>

              <div className="pt-4 border-t border-slate-200 flex justify-end">
                <button className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-emerald-600 transition-colors">
                  {locale === "th" ? "บันทึกการตั้งค่า" : "Save Settings"}
                </button>
              </div>
            </div>
          )}

          {/* Promotions Tab */}
          {activeTab === "promotions" && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-semibold text-slate-900">
                    {locale === "th" ? "โปรโมชัน / แพ็กเกจส่วนลด" : "Promotions / Discounts"}
                  </h2>
                  <p className="text-sm text-slate-500 mt-1">
                    {locale === "th"
                      ? "จัดการโปรโมชัน รหัสส่วนลด และแพ็กเกจพิเศษ"
                      : "Manage promotions, discount codes, and packages"}
                  </p>
                </div>
                <button
                  onClick={() => setAddPromotionModalOpen(true)}
                  className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-lg hover:bg-emerald-600 transition-colors flex items-center gap-2"
                >
                  <Plus className="h-4 w-4" />
                  {locale === "th" ? "สร้างโปรโมชัน" : "Create Promotion"}
                </button>
              </div>

              <div className="space-y-3">
                {promotions.map((promo) => (
                  <div key={promo.id} className="p-4 bg-slate-50 rounded-lg flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      <div className="p-2 bg-white rounded-lg">
                        <Gift className={cn("h-5 w-5", promo.status === "active" ? "text-primary" : "text-slate-400")} />
                      </div>
                      <div>
                        <p className="font-medium text-slate-900">{promo.name}</p>
                        <p className="text-sm text-slate-500">
                          <span className="font-mono bg-slate-200 px-1.5 py-0.5 rounded text-xs">{promo.code}</span>
                          <span className="mx-2">•</span>
                          <span className="text-emerald-600 font-medium">{promo.discount}% {locale === "th" ? "ส่วนลด" : "off"}</span>
                          <span className="mx-2">•</span>
                          <span>{locale === "th" ? "หมดอายุ" : "Expires"}: {promo.expiryDate}</span>
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => handleTogglePromotionStatus(promo.id)}
                        className={cn(
                          "px-3 py-1 rounded-full text-xs font-medium transition-colors",
                          promo.status === "active"
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-slate-200 text-slate-600"
                        )}
                      >
                        {promo.status === "active" ? (locale === "th" ? "ใช้งาน" : "Active") : (locale === "th" ? "ปิด" : "Inactive")}
                      </button>
                      <button
                        onClick={() => handleDeletePromotion(promo.id)}
                        className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* History Tab */}
          {activeTab === "history" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  {locale === "th" ? "ประวัติการปรับราคา" : "Price Change History"}
                </h2>
                <p className="text-sm text-slate-500 mt-1">
                  {locale === "th"
                    ? "ติดตามการเปลี่ยนแปลงราคาและการตั้งค่าต่างๆ"
                    : "Track price changes and settings modifications"}
                </p>
              </div>

              <div className="space-y-3">
                {priceHistory.map((history) => (
                  <div key={history.id} className="p-4 bg-slate-50 rounded-lg">
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-3">
                        <div className="p-2 bg-white rounded-lg mt-0.5">
                          <History className="h-4 w-4 text-slate-500" />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="px-2 py-0.5 bg-blue-100 text-blue-700 rounded text-xs font-medium">
                              {history.changeType}
                            </span>
                            <span className="text-sm text-slate-400">•</span>
                            <span className="text-sm text-slate-500">{history.admin}</span>
                          </div>
                          <p className="text-sm mt-1">
                            <span className="text-slate-500">{history.oldValue}</span>
                            <span className="mx-2">→</span>
                            <span className="text-emerald-600 font-medium">{history.newValue}</span>
                          </p>
                        </div>
                      </div>
                      <span className="text-xs text-slate-400">{history.date}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Delete Confirmation Modal */}
      {pendingDeleteId && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl">
            <div className="p-5 border-b border-slate-200">
              <h2 className="text-lg font-bold text-slate-900">
                {locale === "th" ? "ยืนยันการลบ" : "Confirm deletion"}
              </h2>
            </div>
            <div className="p-5 space-y-3">
              <p className="text-sm text-slate-700">
                {locale === "th" ? "คุณกำลังจะลบบริการ" : "You are about to delete the service"}{" "}
                <span className="font-semibold text-slate-900">
                  &ldquo;{pendingDeleteName}&rdquo;
                </span>
                . {locale === "th" ? "การกระทำนี้ไม่สามารถย้อนกลับได้จากหน้านี้" : "This cannot be undone from here."}
              </p>
              {actionError && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                  {actionError}
                </div>
              )}
            </div>
            <div className="p-4 border-t border-slate-200 flex justify-end gap-3">
              <button
                onClick={cancelDeleteService}
                className="px-5 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={confirmDeleteService}
                className="px-5 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-lg transition-colors"
              >
                {locale === "th" ? "ลบ" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Service Modal */}
      {addServiceModalOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl">
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <h2 className="text-lg font-bold text-slate-900">
                {locale === "th" ? "เพิ่มบริการใหม่" : "Add New Service"}
              </h2>
              <button
                onClick={() => setAddServiceModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "ชื่อประเภทบริการ" : "Service Type Name"}
                </label>
                <input
                  type="text"
                  value={newService.name}
                  onChange={(e) => setNewService({ ...newService, name: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-slate-700 mb-2 block">
                    {locale === "th" ? "ค่าบริการพื้นฐาน (฿)" : "Base Fee (฿)"}
                  </label>
                  <input
                    type="number"
                    value={newService.baseFee}
                    onChange={(e) => setNewService({ ...newService, baseFee: parseInt(e.target.value) || 0 })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-700 mb-2 block">
                    {locale === "th" ? "ชั่วโมงขั้นต่ำ" : "Min Hours"}
                  </label>
                  <input
                    type="number"
                    value={newService.minHours}
                    onChange={(e) => setNewService({ ...newService, minHours: parseInt(e.target.value) || 6 })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "หมายเหตุ" : "Notes"}
                </label>
                <input
                  type="text"
                  value={newService.notes}
                  onChange={(e) => setNewService({ ...newService, notes: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
            </div>
            {addServiceError && (
              <div className="px-5 pt-2">
                <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-3 py-2">
                  {addServiceError}
                </div>
              </div>
            )}
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => {
                  setAddServiceError(null);
                  setAddServiceModalOpen(false);
                }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleAddService}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-emerald-600 transition-colors"
              >
                {locale === "th" ? "เพิ่มบริการ" : "Add Service"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Service Modal */}
      {editServiceModalOpen && editingService && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl animate-in zoom-in-95">
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <h2 className="text-lg font-bold text-slate-900">
                {locale === "th" ? "แก้ไขอัตราค่าบริการ" : "Edit Service Rate"}
              </h2>
              <button
                onClick={() => { setEditServiceModalOpen(false); setEditingService(null); }}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "ชื่อประเภทบริการ" : "Service Type Name"}
                </label>
                <input
                  type="text"
                  value={editingService.name}
                  onChange={(e) => setEditingService({ ...editingService, name: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-slate-700 mb-2 block">
                    {locale === "th" ? "ค่าบริการพื้นฐาน (฿)" : "Base Fee (฿)"}
                  </label>
                  <input
                    type="number"
                    value={editingService.baseFee}
                    onChange={(e) => setEditingService({ ...editingService, baseFee: parseInt(e.target.value) || 0 })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-700 mb-2 block">
                    {locale === "th" ? "ชั่วโมงขั้นต่ำ" : "Min Hours"}
                  </label>
                  <input
                    type="number"
                    value={editingService.minHours}
                    onChange={(e) => setEditingService({ ...editingService, minHours: parseInt(e.target.value) || 6 })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "หมายเหตุ" : "Notes"}
                </label>
                <input
                  type="text"
                  value={editingService.notes}
                  onChange={(e) => setEditingService({ ...editingService, notes: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
            </div>
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => { setEditServiceModalOpen(false); setEditingService(null); }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleUpdateService}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-emerald-600 transition-colors flex items-center justify-center gap-2"
              >
                <Save className="h-4 w-4" />
                {locale === "th" ? "บันทึก" : "Save"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Promotion Modal */}
      {addPromotionModalOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl">
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <h2 className="text-lg font-bold text-slate-900">
                {locale === "th" ? "สร้างโปรโมชันใหม่" : "Create New Promotion"}
              </h2>
              <button
                onClick={() => setAddPromotionModalOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "ชื่อโปรโมชัน" : "Promotion Name"}
                </label>
                <input
                  type="text"
                  value={newPromotion.name}
                  onChange={(e) => setNewPromotion({ ...newPromotion, name: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-slate-700 mb-2 block">
                    {locale === "th" ? "รหัสส่วนลด" : "Discount Code"}
                  </label>
                  <input
                    type="text"
                    value={newPromotion.code}
                    onChange={(e) => setNewPromotion({ ...newPromotion, code: e.target.value.toUpperCase() })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm font-mono focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-700 mb-2 block">
                    {locale === "th" ? "ส่วนลด (%)" : "Discount (%)"}
                  </label>
                  <input
                    type="number"
                    value={newPromotion.discount}
                    onChange={(e) => setNewPromotion({ ...newPromotion, discount: parseInt(e.target.value) || 0 })}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "วันหมดอายุ" : "Expiry Date"}
                </label>
                <input
                  type="date"
                  value={newPromotion.expiryDate}
                  onChange={(e) => setNewPromotion({ ...newPromotion, expiryDate: e.target.value })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
            </div>
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => setAddPromotionModalOpen(false)}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleAddPromotion}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-emerald-600 transition-colors"
              >
                {locale === "th" ? "สร้างโปรโมชัน" : "Create Promotion"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Area Modal */}
      {editAreaModalOpen && selectedArea && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl">
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <h2 className="text-lg font-bold text-slate-900">
                {locale === "th" ? "แก้ไขอัตราค่าบริการ" : "Edit Service Rate"}
              </h2>
              <button
                onClick={() => { setEditAreaModalOpen(false); setSelectedArea(null); }}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div className="p-4 bg-slate-50 rounded-lg">
                <p className="text-sm text-slate-500">{locale === "th" ? "พื้นที่:" : "Area:"}</p>
                <p className="font-bold text-slate-900">{selectedArea.province} - {selectedArea.area}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700 mb-2 block">
                  {locale === "th" ? "อัตราค่าบริการต่อชั่วโมง (฿)" : "Rate Per Hour (฿)"}
                </label>
                <input
                  type="number"
                  value={selectedArea.rate}
                  onChange={(e) => setSelectedArea({ ...selectedArea, rate: parseInt(e.target.value) || 0 })}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2.5 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary focus:bg-white transition-all outline-none"
                />
              </div>
            </div>
            <div className="flex gap-3 p-5 border-t border-slate-200">
              <button
                onClick={() => { setEditAreaModalOpen(false); setSelectedArea(null); }}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors"
              >
                {locale === "th" ? "ยกเลิก" : "Cancel"}
              </button>
              <button
                onClick={handleSaveArea}
                className="flex-1 px-4 py-2.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-emerald-600 transition-colors flex items-center justify-center gap-2"
              >
                <Save className="h-4 w-4" />
                {locale === "th" ? "บันทึก" : "Save"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
