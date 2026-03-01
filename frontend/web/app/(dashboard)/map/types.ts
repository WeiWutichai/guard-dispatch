export interface DisplayGuard {
  id: string;
  name: string;
  status: "active" | "idle" | "alert";
  location: string;
  lat: number;
  lng: number;
  lastUpdate: string;
}
