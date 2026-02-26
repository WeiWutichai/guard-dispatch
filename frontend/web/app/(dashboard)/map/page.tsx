"use client";

import { useState, useEffect, useCallback } from "react";
import {
  MapPin,
  Users,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Maximize2,
  Layers,
  Navigation,
  RefreshCw,
  Loader2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { trackingApi, type GuardLocation } from "@/lib/api";

interface DisplayGuard {
  id: string;
  name: string;
  status: "active" | "idle" | "alert";
  location: string;
  lat: number;
  lng: number;
  lastUpdate: string;
}

const statusConfig = {
  active: { label: "Active", color: "bg-emerald-500", ring: "ring-emerald-200" },
  idle: { label: "Idle", color: "bg-amber-500", ring: "ring-amber-200" },
  alert: { label: "Alert", color: "bg-red-500", ring: "ring-red-200" },
};

// Mock guard names for display — in production this would come from a user service
const guardNames: Record<string, string> = {};

function getGuardStatus(location: GuardLocation): "active" | "idle" | "alert" {
  const minutesAgo = (Date.now() - new Date(location.recorded_at).getTime()) / 60000;
  if (minutesAgo > 30) return "alert";
  if (minutesAgo > 10) return "idle";
  return "active";
}

function formatTimeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes} min ago`;
  return `${Math.floor(minutes / 60)}h ago`;
}

export default function MapPage() {
  const { locale } = useLanguage();
  const [guards, setGuards] = useState<DisplayGuard[]>([]);
  const [selectedGuard, setSelectedGuard] = useState<string | null>(null);
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "idle" | "alert">("all");
  const [isLoading, setIsLoading] = useState(true);

  // For now use a static list of guard IDs — in production this would come from the booking/auth service
  const fetchLocations = useCallback(async () => {
    try {
      // This would be replaced with a bulk location fetch endpoint
      // For now, we'll try to fetch individual guard locations
      // In production, add a GET /tracking/locations endpoint that returns all active guards
      setIsLoading(false);
    } catch {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial data fetch from tracking API
    void fetchLocations();
  }, [fetchLocations]);

  // Use demo data if no real data available
  const displayGuards: DisplayGuard[] = guards.length > 0 ? guards : [
    { id: "G001", name: "Somchai Prasert", status: "active", location: "Central Plaza - Main Entrance", lat: 13.7563, lng: 100.5018, lastUpdate: "2 min ago" },
    { id: "G002", name: "Niran Thongchai", status: "active", location: "Siam Paragon - Parking B2", lat: 13.7466, lng: 100.5347, lastUpdate: "1 min ago" },
    { id: "G003", name: "Kittisak Srisawat", status: "idle", location: "Terminal 21 - Floor 3", lat: 13.7378, lng: 100.5604, lastUpdate: "8 min ago" },
    { id: "G004", name: "Wichai Kaewsai", status: "alert", location: "ICONSIAM - Waterfront", lat: 13.7268, lng: 100.5100, lastUpdate: "Just now" },
    { id: "G005", name: "Thanakorn Mee", status: "active", location: "Mega Bangna - East Wing", lat: 13.6614, lng: 100.6840, lastUpdate: "3 min ago" },
  ];

  const filteredGuards = displayGuards.filter(
    (g) => filterStatus === "all" || g.status === filterStatus
  );

  const stats = {
    total: displayGuards.length,
    active: displayGuards.filter((g) => g.status === "active").length,
    idle: displayGuards.filter((g) => g.status === "idle").length,
    alerts: displayGuards.filter((g) => g.status === "alert").length,
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">
            {locale === "th" ? "แผนที่ติดตามสด" : "Live Map Tracking"}
          </h1>
          <p className="text-slate-500 mt-1">
            {locale === "th" ? "ติดตามตำแหน่งเจ้าหน้าที่แบบเรียลไทม์" : "Real-time location monitoring of all field personnel"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={fetchLocations}
            className="inline-flex items-center px-3 py-2 bg-white border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors"
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            {locale === "th" ? "รีเฟรช" : "Refresh"}
          </button>
          <button className="inline-flex items-center px-3 py-2 bg-white border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors">
            <Maximize2 className="h-4 w-4 mr-2" />
            {locale === "th" ? "เต็มจอ" : "Fullscreen"}
          </button>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.total}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "ทั้งหมดบนแผนที่" : "Total On Map"}</p>
            </div>
            <div className="p-2 bg-slate-100 rounded-lg">
              <Users className="h-5 w-5 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-emerald-600">{stats.active}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "ปฏิบัติงาน" : "Active"}</p>
            </div>
            <div className="p-2 bg-emerald-50 rounded-lg">
              <CheckCircle2 className="h-5 w-5 text-emerald-600" />
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-amber-600">{stats.idle}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "ว่าง" : "Idle"}</p>
            </div>
            <div className="p-2 bg-amber-50 rounded-lg">
              <Clock className="h-5 w-5 text-amber-600" />
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-red-600">{stats.alerts}</p>
              <p className="text-sm text-slate-500">{locale === "th" ? "แจ้งเตือน" : "Alerts"}</p>
            </div>
            <div className="p-2 bg-red-50 rounded-lg">
              <AlertTriangle className="h-5 w-5 text-red-600" />
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Map Area */}
        <div className="lg:col-span-3 bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-4 border-b border-slate-200 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <h2 className="font-semibold text-slate-900">
                {locale === "th" ? "พื้นที่กรุงเทพมหานคร" : "Bangkok Metropolitan Area"}
              </h2>
              <div className="flex items-center gap-2">
                {(["all", "active", "idle", "alert"] as const).map((status) => (
                  <button
                    key={status}
                    onClick={() => setFilterStatus(status)}
                    className={cn(
                      "px-2 py-1 rounded text-xs font-medium transition-colors",
                      filterStatus === status
                        ? "bg-primary text-white"
                        : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                    )}
                  >
                    {status.charAt(0).toUpperCase() + status.slice(1)}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button className="p-2 hover:bg-slate-100 rounded-lg transition-colors">
                <Layers className="h-4 w-4 text-slate-500" />
              </button>
              <button className="p-2 hover:bg-slate-100 rounded-lg transition-colors">
                <Navigation className="h-4 w-4 text-slate-500" />
              </button>
            </div>
          </div>

          {/* Simulated Map */}
          <div className="h-[500px] bg-slate-100 relative overflow-hidden">
            <div className="absolute inset-0 opacity-30">
              <div className="w-full h-full bg-[radial-gradient(#94a3b8_1px,transparent_1px)] [background-size:24px_24px]" />
            </div>

            <svg className="absolute inset-0 w-full h-full" viewBox="0 0 800 500">
              <path d="M0 250 L800 250" stroke="#cbd5e1" strokeWidth="3" fill="none" />
              <path d="M400 0 L400 500" stroke="#cbd5e1" strokeWidth="3" fill="none" />
              <path d="M100 100 L700 400" stroke="#cbd5e1" strokeWidth="2" fill="none" />
              <path d="M100 400 L700 100" stroke="#cbd5e1" strokeWidth="2" fill="none" />
              <circle cx="400" cy="250" r="80" stroke="#e2e8f0" strokeWidth="2" fill="none" />
            </svg>

            {filteredGuards.map((guard, index) => {
              const status = statusConfig[guard.status];
              const positions = [
                { x: 20, y: 30 },
                { x: 45, y: 45 },
                { x: 70, y: 25 },
                { x: 35, y: 60 },
                { x: 80, y: 70 },
              ];
              const pos = positions[index % positions.length];

              return (
                <button
                  key={guard.id}
                  onClick={() => setSelectedGuard(selectedGuard === guard.id ? null : guard.id)}
                  className={cn(
                    "absolute transform -translate-x-1/2 -translate-y-1/2 transition-all",
                    selectedGuard === guard.id ? "z-20 scale-125" : "z-10 hover:scale-110"
                  )}
                  style={{ left: `${pos.x}%`, top: `${pos.y}%` }}
                >
                  <div className={cn("relative p-1 rounded-full ring-4", status.ring)}>
                    <div className={cn("w-4 h-4 rounded-full", status.color)} />
                    {guard.status === "alert" && (
                      <span className="absolute -top-1 -right-1 flex h-3 w-3">
                        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75" />
                        <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500" />
                      </span>
                    )}
                  </div>
                  {selectedGuard === guard.id && (
                    <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 bg-white rounded-lg shadow-lg border border-slate-200 p-3 min-w-[200px] text-left">
                      <p className="font-semibold text-slate-900 text-sm">{guard.name}</p>
                      <p className="text-xs text-slate-500 mt-0.5">{guard.location}</p>
                      <div className="flex items-center gap-2 mt-2">
                        <span className={cn("w-2 h-2 rounded-full", status.color)} />
                        <span className="text-xs text-slate-600">{status.label}</span>
                        <span className="text-xs text-slate-400">- {guard.lastUpdate}</span>
                      </div>
                    </div>
                  )}
                </button>
              );
            })}

            {/* Map Legend */}
            <div className="absolute bottom-4 left-4 bg-white/90 backdrop-blur-sm rounded-lg p-3 shadow-sm border border-slate-200">
              <p className="text-xs font-semibold text-slate-700 mb-2">Legend</p>
              <div className="space-y-1.5">
                <div className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full bg-emerald-500" />
                  <span className="text-xs text-slate-600">Active</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full bg-amber-500" />
                  <span className="text-xs text-slate-600">Idle</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full bg-red-500" />
                  <span className="text-xs text-slate-600">Alert</span>
                </div>
              </div>
            </div>

            <div className="absolute bottom-4 right-4 bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
              <button className="p-2 hover:bg-slate-50 border-b border-slate-100 block">
                <span className="text-lg font-medium text-slate-600">+</span>
              </button>
              <button className="p-2 hover:bg-slate-50 block">
                <span className="text-lg font-medium text-slate-600">-</span>
              </button>
            </div>
          </div>
        </div>

        {/* Guard List Sidebar */}
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-4 border-b border-slate-200">
            <h2 className="font-semibold text-slate-900">
              {locale === "th" ? "เจ้าหน้าที่ปฏิบัติงาน" : "Active Personnel"}
            </h2>
            <p className="text-sm text-slate-500 mt-0.5">
              {filteredGuards.length} {locale === "th" ? "คนบนแผนที่" : "guards on map"}
            </p>
          </div>
          <div className="divide-y divide-slate-100 max-h-[460px] overflow-y-auto">
            {filteredGuards.map((guard) => {
              const status = statusConfig[guard.status];
              return (
                <button
                  key={guard.id}
                  onClick={() => setSelectedGuard(selectedGuard === guard.id ? null : guard.id)}
                  className={cn(
                    "w-full p-4 text-left hover:bg-slate-50 transition-colors",
                    selectedGuard === guard.id && "bg-emerald-50"
                  )}
                >
                  <div className="flex items-start gap-3">
                    <div className={cn("mt-1 p-1 rounded-full ring-2", status.ring)}>
                      <div className={cn("w-2 h-2 rounded-full", status.color)} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-slate-900 text-sm">{guard.name}</p>
                      <p className="text-xs text-slate-500 mt-0.5 truncate">{guard.location}</p>
                      <p className="text-xs text-slate-400 mt-1">{guard.lastUpdate}</p>
                    </div>
                    <MapPin className="h-4 w-4 text-slate-300 flex-shrink-0" />
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
