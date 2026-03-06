"use client";

import { useState, useEffect, useCallback, useMemo, useRef } from "react";
import dynamic from "next/dynamic";
import {
  MapPin,
  Users,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Maximize2,
  Minimize2,
  Layers,
  Navigation,
  RefreshCw,
  Search,
  ShieldX,
  Loader2,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import { useAuth } from "@/components/AuthProvider";
import { trackingApi, batchReverseGeocode, type GuardLocationWithName } from "@/lib/api";
import { type DisplayGuard } from "./types";

// Lazy-load the map component (Leaflet requires window/DOM)
const MapArea = dynamic(() => import("./map-area"), { ssr: false });

const statusConfig = {
  active: {
    label: "Active",
    color: "bg-emerald-500",
    ring: "ring-emerald-200",
    hex: "#10b981",
  },
  idle: {
    label: "Idle",
    color: "bg-amber-500",
    ring: "ring-amber-200",
    hex: "#f59e0b",
  },
  alert: {
    label: "Alert",
    color: "bg-red-500",
    ring: "ring-red-200",
    hex: "#ef4444",
  },
};

function getGuardStatus(recordedAt: string): "active" | "idle" | "alert" {
  const minutesAgo =
    (Date.now() - new Date(recordedAt).getTime()) / 60000;
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

function toDisplayGuard(loc: GuardLocationWithName): DisplayGuard {
  return {
    id: loc.guard_id,
    name: loc.full_name ?? "Guard",
    status: getGuardStatus(loc.recorded_at),
    location: `${loc.lat.toFixed(4)}, ${loc.lng.toFixed(4)}`,
    lat: loc.lat,
    lng: loc.lng,
    lastUpdate: formatTimeAgo(loc.recorded_at),
  };
}

export default function MapPage() {
  const { t } = useLanguage();
  const { user, isLoading: authLoading } = useAuth();
  const [guards, setGuards] = useState<DisplayGuard[]>([]);
  const [selectedGuard, setSelectedGuard] = useState<string | null>(null);
  const [filterStatus, setFilterStatus] = useState<
    "all" | "active" | "idle" | "alert"
  >("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [isFullscreen, setIsFullscreen] = useState(false);
  const flyToRef = useRef<((lat: number, lng: number) => void) | null>(null);
  const invalidateSizeRef = useRef<(() => void) | null>(null);

  // Debounce search input (300ms)
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchQuery), 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  const toggleFullscreen = useCallback(() => {
    setIsFullscreen((prev) => !prev);
    // Leaflet needs to recalculate tile layout after container resize
    setTimeout(() => invalidateSizeRef.current?.(), 50);
  }, []);

  const fetchLocations = useCallback(async () => {
    try {
      const locations = await trackingApi.getAllLocations();
      // Show immediately with coordinate strings
      setGuards(locations.map(toDisplayGuard));

      // Resolve area names in background
      if (locations.length > 0) {
        const nameMap = await batchReverseGeocode(
          locations.map((l) => ({ lat: l.lat, lng: l.lng }))
        );
        setGuards(
          locations.map((loc) => ({
            ...toDisplayGuard(loc),
            location: nameMap.get(`${loc.lat},${loc.lng}`) ?? `${loc.lat.toFixed(4)}, ${loc.lng.toFixed(4)}`,
          }))
        );
      }
    } catch {
      // API not available — show empty map
    }
  }, []);

  useEffect(() => {
    void fetchLocations();
    // Auto-refresh every 30 seconds
    const interval = setInterval(() => void fetchLocations(), 30_000);
    return () => clearInterval(interval);
  }, [fetchLocations]);

  const displayGuards = useMemo(() => guards, [guards]);

  const filteredGuards = useMemo(() => {
    const query = debouncedSearch.toLowerCase().trim();
    return displayGuards.filter((g) => {
      const matchesStatus = filterStatus === "all" || g.status === filterStatus;
      const matchesSearch =
        query === "" ||
        g.name.toLowerCase().includes(query) ||
        g.id.toLowerCase().includes(query) ||
        g.location.toLowerCase().includes(query);
      return matchesStatus && matchesSearch;
    });
  }, [displayGuards, filterStatus, debouncedSearch]);

  const stats = useMemo(() => {
    let active = 0,
      idle = 0,
      alerts = 0;
    for (const g of displayGuards) {
      if (g.status === "active") active++;
      else if (g.status === "idle") idle++;
      else alerts++;
    }
    return { total: displayGuards.length, active, idle, alerts };
  }, [displayGuards]);

  const handleGuardSelect = useCallback(
    (guardId: string) => {
      const next = selectedGuard === guardId ? null : guardId;
      setSelectedGuard(next);
      if (next) {
        const guard = displayGuards.find((g) => g.id === next);
        if (guard && flyToRef.current) {
          flyToRef.current(guard.lat, guard.lng);
        }
      }
    },
    [selectedGuard, displayGuards]
  );

  const filterLabels: Record<string, string> = {
    all: t.map.allFilter,
    active: t.map.active,
    idle: t.map.idle,
    alert: t.map.alerts,
  };

  // ── Auth gate: admin and customer only ──────────────────────────────────────
  // Guards should only see their own location, not the admin overview map.
  // Server-side: tracking API enforces role-based filtering.
  if (authLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!user || user.role === "guard") {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3">
        <ShieldX className="h-12 w-12 text-slate-300" />
        <p className="text-slate-500 text-sm">{t.map.unauthorized}</p>
      </div>
    );
  }

  // ── Fullscreen overlay ────────────────────────────────────────────────────
  if (isFullscreen) {
    return (
      <div className="fixed inset-0 z-50 bg-white flex flex-col">
        {/* Fullscreen header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-200 bg-white">
          <div className="flex items-center gap-4">
            <h2 className="font-semibold text-slate-900">{t.map.bangkokArea}</h2>
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
                  {filterLabels[status]}
                </button>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder={t.map.searchPlaceholder}
                className="pl-9 pr-8 py-1.5 w-64 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery("")}
                  className="absolute right-2 top-1/2 -translate-y-1/2 p-0.5 hover:bg-slate-100 rounded"
                >
                  <X className="h-3.5 w-3.5 text-slate-400" />
                </button>
              )}
            </div>
            <button
              onClick={toggleFullscreen}
              className="inline-flex items-center gap-2 px-3 py-2 bg-white border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors"
            >
              <Minimize2 className="h-4 w-4" />
              {t.map.exitFullscreen}
            </button>
          </div>
        </div>
        {/* Fullscreen map fills remaining space */}
        <div className="flex-1 relative">
          <MapArea
            mapKey="fullscreen"
            guards={filteredGuards}
            selectedGuard={selectedGuard}
            onSelectGuard={handleGuardSelect}
            legendLabel={t.map.legend}
            activeLabel={t.map.active}
            idleLabel={t.map.idle}
            alertLabel={t.map.alerts}
            flyToRef={flyToRef}
            invalidateSizeRef={invalidateSizeRef}
            height="100%"
          />
        </div>
      </div>
    );
  }

  // ── Normal layout ──────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{t.map.title}</h1>
          <p className="text-slate-500 mt-1">{t.map.subtitle}</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={fetchLocations}
            className="inline-flex items-center px-3 py-2 bg-white border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors"
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            {t.map.refresh}
          </button>
          <button
            onClick={toggleFullscreen}
            className="inline-flex items-center px-3 py-2 bg-white border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors"
          >
            <Maximize2 className="h-4 w-4 mr-2" />
            {t.map.fullscreen}
          </button>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-slate-900">
                {stats.total}
              </p>
              <p className="text-sm text-slate-500">{t.map.totalOnMap}</p>
            </div>
            <div className="p-2 bg-slate-100 rounded-lg">
              <Users className="h-5 w-5 text-slate-600" />
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-2xl font-bold text-emerald-600">
                {stats.active}
              </p>
              <p className="text-sm text-slate-500">{t.map.active}</p>
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
              <p className="text-sm text-slate-500">{t.map.idle}</p>
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
              <p className="text-sm text-slate-500">{t.map.alerts}</p>
            </div>
            <div className="p-2 bg-red-50 rounded-lg">
              <AlertTriangle className="h-5 w-5 text-red-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Search bar */}
      <div className="bg-white rounded-xl border border-slate-200 p-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t.map.searchPlaceholder}
            className="w-full pl-10 pr-10 py-2.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 p-0.5 hover:bg-slate-100 rounded"
            >
              <X className="h-4 w-4 text-slate-400" />
            </button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Map Area */}
        <div className="lg:col-span-3 bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-4 border-b border-slate-200 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <h2 className="font-semibold text-slate-900">
                {t.map.bangkokArea}
              </h2>
              <div className="flex items-center gap-2">
                {(["all", "active", "idle", "alert"] as const).map(
                  (status) => (
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
                      {filterLabels[status]}
                    </button>
                  )
                )}
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

          {/* Real Map via react-leaflet */}
          <MapArea
            mapKey="normal"
            guards={filteredGuards}
            selectedGuard={selectedGuard}
            onSelectGuard={handleGuardSelect}
            legendLabel={t.map.legend}
            activeLabel={t.map.active}
            idleLabel={t.map.idle}
            alertLabel={t.map.alerts}
            flyToRef={flyToRef}
            invalidateSizeRef={invalidateSizeRef}
          />
        </div>

        {/* Guard List Sidebar */}
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-4 border-b border-slate-200">
            <h2 className="font-semibold text-slate-900">
              {t.map.activePersonnel}
            </h2>
            <p className="text-sm text-slate-500 mt-0.5">
              {filteredGuards.length} {t.map.guardsOnMap}
            </p>
          </div>
          <div className="divide-y divide-slate-100 max-h-[460px] overflow-y-auto">
            {filteredGuards.length === 0 && (
              <div className="p-8 text-center">
                <Search className="h-8 w-8 text-slate-300 mx-auto mb-2" />
                <p className="text-sm text-slate-500">{t.map.noResults}</p>
              </div>
            )}
            {filteredGuards.map((guard) => {
              const status = statusConfig[guard.status];
              return (
                <button
                  key={guard.id}
                  onClick={() => handleGuardSelect(guard.id)}
                  className={cn(
                    "w-full p-4 text-left hover:bg-slate-50 transition-colors",
                    selectedGuard === guard.id && "bg-emerald-50"
                  )}
                >
                  <div className="flex items-start gap-3">
                    <div
                      className={cn(
                        "mt-1 p-1 rounded-full ring-2",
                        status.ring
                      )}
                    >
                      <div
                        className={cn("w-2 h-2 rounded-full", status.color)}
                      />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-slate-900 text-sm">
                        {guard.name}
                      </p>
                      <p className="text-xs text-slate-500 mt-0.5 truncate">
                        {guard.location}
                      </p>
                      <p className="text-xs text-slate-400 mt-1">
                        {guard.lastUpdate}
                      </p>
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
