export interface DisplayGuard {
  id: string;
  name: string;
  status: "active" | "idle" | "offline";
  location: string;
  lat: number;
  lng: number;
  lastUpdate: string;
}
