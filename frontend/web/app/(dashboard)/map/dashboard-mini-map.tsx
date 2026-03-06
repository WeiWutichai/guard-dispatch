"use client";

import { useState, useEffect } from "react";
import { MapContainer, TileLayer, Marker } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { trackingApi, type GuardLocationWithName } from "@/lib/api";

const statusHex: Record<string, string> = {
  active: "#10b981",
  idle: "#f59e0b",
  alert: "#ef4444",
};

function createDotIcon(status: string): L.DivIcon {
  const color = statusHex[status] ?? "#10b981";
  return L.divIcon({
    className: "",
    iconSize: [22, 22],
    iconAnchor: [11, 11],
    html: `
      <div style="
        width: 22px; height: 22px;
        display: flex; align-items: center; justify-content: center;
        border-radius: 50%;
        background: ${color}33;
      ">
        <div style="
          width: 12px; height: 12px;
          border-radius: 50%;
          background: ${color};
          border: 2px solid white;
          box-shadow: 0 1px 4px ${color}66;
        "></div>
      </div>
    `,
  });
}

// Pre-create icons (only 3 variants)
const icons: Record<string, L.DivIcon> = {
  active: createDotIcon("active"),
  idle: createDotIcon("idle"),
  alert: createDotIcon("alert"),
};

function getStatus(recordedAt: string): string {
  const minutesAgo =
    (Date.now() - new Date(recordedAt).getTime()) / 60000;
  if (minutesAgo > 30) return "alert";
  if (minutesAgo > 10) return "idle";
  return "active";
}

// ─── Component ───────────────────────────────────────────────────────────────

export default function DashboardMiniMap() {
  const [guards, setGuards] = useState<
    { id: string; lat: number; lng: number; status: string }[]
  >([]);

  useEffect(() => {
    trackingApi
      .getAllLocations()
      .then((locations: GuardLocationWithName[]) => {
        setGuards(
          locations.map((loc) => ({
            id: loc.guard_id,
            lat: loc.lat,
            lng: loc.lng,
            status: getStatus(loc.recorded_at),
          }))
        );
      })
      .catch(() => {
        // API not available — show empty map
      });
  }, []);

  return (
    <MapContainer
      center={[13.7363, 100.5318]}
      zoom={11}
      scrollWheelZoom={false}
      dragging={false}
      zoomControl={false}
      doubleClickZoom={false}
      attributionControl={false}
      className="h-full w-full"
    >
      {/* TODO: Replace with commercial tile provider (Mapbox/Maptiler) for production */}
      <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
      {guards.map((g) => (
        <Marker
          key={g.id}
          position={[g.lat, g.lng]}
          icon={icons[g.status]}
          interactive={false}
        />
      ))}
    </MapContainer>
  );
}
