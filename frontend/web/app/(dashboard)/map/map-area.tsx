"use client";

import { useEffect, useRef, useState, type MutableRefObject } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { type DisplayGuard } from "./types";

// ─── Props ──────────────────────────────────────────────────────────────────

interface MapAreaProps {
  guards: DisplayGuard[];
  selectedGuard: string | null;
  onSelectGuard: (id: string) => void;
  legendLabel: string;
  activeLabel: string;
  idleLabel: string;
  alertLabel: string;
  offlineLabel: string;
  flyToRef: MutableRefObject<((lat: number, lng: number) => void) | null>;
  invalidateSizeRef?: MutableRefObject<(() => void) | null>;
  height?: string;
  /** Unique key to prevent Leaflet container reuse across fullscreen/normal modes */
  mapKey?: string;
}

// ─── Status colors ──────────────────────────────────────────────────────────

const statusHex: Record<string, string> = {
  active: "#10b981",
  idle: "#f59e0b",
  alert: "#94a3b8",
  offline: "#ef4444",
};

// ─── Custom SVG marker icon ─────────────────────────────────────────────────

// Pre-create all 6 icon variants (3 statuses × 2 selected states)
const iconCache = new Map<string, L.DivIcon>();

function getIcon(status: string, isSelected: boolean): L.DivIcon {
  const key = `${status}-${isSelected}`;
  let icon = iconCache.get(key);
  if (!icon) {
    const color = statusHex[status] ?? "#10b981";
    const size = isSelected ? 20 : 14;
    const outerSize = size + 12;

    icon = L.divIcon({
      className: "",
      iconSize: [outerSize, outerSize],
      iconAnchor: [outerSize / 2, outerSize / 2],
      html: `
        <div style="
          width: ${outerSize}px;
          height: ${outerSize}px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 50%;
          background: ${color}33;
          ${isSelected ? "transform: scale(1.25);" : ""}
          transition: transform 0.2s;
        ">
          <div style="
            width: ${size}px;
            height: ${size}px;
            border-radius: 50%;
            background: ${color};
            border: 2px solid white;
            box-shadow: 0 2px 6px ${color}66;
          "></div>
        </div>
      `,
    });
    iconCache.set(key, icon);
  }
  return icon;
}

// ─── Inner component to expose flyTo via ref ────────────────────────────────

function MapController({
  flyToRef,
  invalidateSizeRef,
}: {
  flyToRef: MutableRefObject<((lat: number, lng: number) => void) | null>;
  invalidateSizeRef?: MutableRefObject<(() => void) | null>;
}) {
  const map = useMap();

  useEffect(() => {
    flyToRef.current = (lat: number, lng: number) => {
      map.flyTo([lat, lng], 14, { duration: 0.8 });
    };
    if (invalidateSizeRef) {
      invalidateSizeRef.current = () => {
        map.invalidateSize();
      };
    }
    return () => {
      flyToRef.current = null;
      if (invalidateSizeRef) {
        invalidateSizeRef.current = null;
      }
    };
  }, [map, flyToRef, invalidateSizeRef]);

  return null;
}

// ─── Single marker with conditional popup ───────────────────────────────────

function GuardMarker({
  guard,
  isSelected,
  icon,
  onSelect,
}: {
  guard: DisplayGuard;
  isSelected: boolean;
  icon: L.DivIcon;
  onSelect: () => void;
}) {
  const markerRef = useRef<L.Marker>(null);

  useEffect(() => {
    if (isSelected && markerRef.current) {
      markerRef.current.openPopup();
    }
  }, [isSelected]);

  return (
    <Marker
      ref={markerRef}
      position={[guard.lat, guard.lng]}
      icon={icon}
      eventHandlers={{ click: onSelect }}
    >
      {isSelected && (
        <Popup closeButton={false} offset={[0, -8]}>
          <div className="min-w-[180px]">
            <p className="font-semibold text-slate-900 text-sm">
              {guard.name}
            </p>
            <p className="text-xs text-slate-500 mt-0.5">
              {guard.location}
            </p>
            <div className="flex items-center gap-2 mt-2">
              <span
                className="w-2 h-2 rounded-full inline-block"
                style={{ background: statusHex[guard.status] }}
              />
              <span className="text-xs text-slate-600 capitalize">
                {guard.status}
              </span>
              <span className="text-xs text-slate-400">
                - {guard.lastUpdate}
              </span>
            </div>
          </div>
        </Popup>
      )}
    </Marker>
  );
}

// ─── Legend overlay ─────────────────────────────────────────────────────────

function LegendItem({ color, label }: { color: string; label: string }) {
  return (
    <div className="flex items-center gap-2">
      <div
        className="w-3 h-3 rounded-full"
        style={{ background: color }}
      />
      <span className="text-xs text-slate-600">{label}</span>
    </div>
  );
}

// ─── Main component ─────────────────────────────────────────────────────────

export default function MapArea({
  guards,
  selectedGuard,
  onSelectGuard,
  legendLabel,
  activeLabel,
  idleLabel,
  alertLabel,
  offlineLabel,
  flyToRef,
  invalidateSizeRef,
  height,
  mapKey,
}: MapAreaProps) {
  // Defer MapContainer render until DOM is ready.
  // React 19 + Turbopack can remount before Leaflet's internal panes exist,
  // causing "Cannot read properties of undefined (reading 'appendChild')".
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    const id = requestAnimationFrame(() => setMounted(true));
    return () => {
      cancelAnimationFrame(id);
      setMounted(false);
    };
  }, [mapKey]);

  const h = height ?? "500px";

  if (!mounted) {
    return <div className="relative" style={{ height: h }} />;
  }

  return (
    <div className="relative" style={{ height: h }}>
      <MapContainer
        key={mapKey ?? "map"}
        center={[13.7363, 100.5318]}
        zoom={12}
        scrollWheelZoom={true}
        className="h-full w-full z-0"
        zoomControl={false}
      >
        {/* TODO: Replace with commercial tile provider (Mapbox/Maptiler) for production.
            OSM tile.openstreetmap.org usage policy prohibits heavy/commercial use. */}
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        <MapController flyToRef={flyToRef} invalidateSizeRef={invalidateSizeRef} />

        {guards.map((guard) => (
          <GuardMarker
            key={guard.id}
            guard={guard}
            isSelected={selectedGuard === guard.id}
            icon={getIcon(guard.status, selectedGuard === guard.id)}
            onSelect={() => onSelectGuard(guard.id)}
          />
        ))}
      </MapContainer>

      {/* Legend overlay */}
      <div className="absolute bottom-4 left-4 bg-white/90 backdrop-blur-sm rounded-lg p-3 shadow-sm border border-slate-200 z-[1000]">
        <p className="text-xs font-semibold text-slate-700 mb-2">
          {legendLabel}
        </p>
        <div className="space-y-1.5">
          <LegendItem color="#10b981" label={activeLabel} />
          <LegendItem color="#f59e0b" label={idleLabel} />
          <LegendItem color="#94a3b8" label={alertLabel} />
          <LegendItem color="#ef4444" label={offlineLabel} />
        </div>
      </div>
    </div>
  );
}
