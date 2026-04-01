export interface DisplayGuard {
  id: string;
  name: string;
  status: "active" | "idle" | "alert" | "offline";
  location: string;
  lat: number;
  lng: number;
  lastUpdate: string;
}
