// =============================================================================
// API Client — Guard Dispatch Admin Portal
// Connects to Rust backend services via Nginx gateway
//
// SECURITY: Auth tokens are stored in httpOnly Secure cookies (set by backend).
// The frontend never reads/writes JWT tokens directly.
// =============================================================================

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH || "";

// ---------------------------------------------------------------------------
// Types matching the Rust backend responses
// ---------------------------------------------------------------------------

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: { code: string; message: string };
}

// Auth types
export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

export interface UserResponse {
  id: string;
  email: string;
  phone: string;
  full_name: string;
  role: "admin" | "customer" | "guard" | null;
  avatar_url: string | null;
  is_active: boolean;
  approval_status: "pending" | "approved" | "rejected";
  created_at: string;
}

export interface PaginatedUsers {
  users: UserResponse[];
  total: number;
}

// Guard profile submitted during mobile registration
export interface GuardProfile {
  user_id: string;
  gender: string | null;
  date_of_birth: string | null;
  years_of_experience: number | null;
  previous_workplace: string | null;
  id_card_url: string | null;
  security_license_url: string | null;
  training_cert_url: string | null;
  criminal_check_url: string | null;
  driver_license_url: string | null;
  bank_name: string | null;
  account_number: string | null;
  account_name: string | null;
  passbook_photo_url: string | null;
}

// Customer profile submitted during mobile registration
export interface CustomerProfile {
  user_id: string;
  full_name: string;
  contact_phone: string | null;
  email: string | null;
  company_name: string | null;
  address: string;
  approval_status: "pending" | "approved" | "rejected";
  created_at: string;
}

// Booking types
export interface GuardRequest {
  id: string;
  customer_id: string;
  title: string;
  description: string;
  location_lat: number;
  location_lng: number;
  location_address: string;
  urgency: "low" | "medium" | "high" | "critical";
  status: "pending" | "assigned" | "in_progress" | "completed" | "cancelled";
  scheduled_start: string;
  scheduled_end: string | null;
  created_at: string;
  updated_at: string;
}

export interface Assignment {
  id: string;
  request_id: string;
  guard_id: string;
  status: "assigned" | "en_route" | "arrived" | "completed" | "cancelled";
  assigned_at: string;
  started_at: string | null;
  completed_at: string | null;
  notes: string | null;
}

// Pricing types
export interface ServiceRateResponse {
  id: string;
  name: string;
  description: string | null;
  min_price: number;
  max_price: number;
  base_fee: number;
  min_hours: number;
  notes: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// Tracking types
export interface GuardLocation {
  guard_id: string;
  lat: number;
  lng: number;
  accuracy: number | null;
  heading: number | null;
  speed: number | null;
  recorded_at: string;
}

export interface LocationHistory {
  id: string;
  guard_id: string;
  lat: number;
  lng: number;
  accuracy: number | null;
  heading: number | null;
  speed: number | null;
  recorded_at: string;
}

export interface GuardLocationWithName {
  guard_id: string;
  full_name: string | null;
  lat: number;
  lng: number;
  accuracy: number | null;
  heading: number | null;
  speed: number | null;
  recorded_at: string;
}

// Notification types
export interface NotificationLog {
  id: string;
  user_id: string;
  title: string;
  body: string;
  notification_type: string;
  payload: Record<string, unknown> | null;
  is_read: boolean;
  sent_at: string;
  read_at: string | null;
}

// Chat types
export interface Conversation {
  id: string;
  request_id: string | null;
  created_at: string;
}

export interface ChatMessage {
  id: string;
  conversation_id: string;
  sender_id: string;
  message_type: "text" | "image" | "system";
  content: string;
  created_at: string;
}

// ---------------------------------------------------------------------------
// Auth state helpers
// ---------------------------------------------------------------------------
// Tokens are httpOnly cookies — JS cannot read them directly.
// The backend sets a non-httpOnly "logged_in=1" marker cookie so the
// frontend can check auth state without exposing the actual token.
// ---------------------------------------------------------------------------

/** Check if the user likely has an active session (cookie-based). */
export function getAccessToken(): string | null {
  if (typeof window === "undefined") return null;
  if (
    document.cookie
      .split(";")
      .some((c) => c.trim().startsWith("logged_in="))
  ) {
    return "cookie-auth";
  }
  return null;
}

export function getRefreshToken(): string | null {
  // Refresh token is in an httpOnly cookie — not accessible from JS
  return null;
}

export function setTokens(
  _accessToken: string,
  _refreshToken: string
): void {
  // No-op: tokens are set via Set-Cookie headers from the backend
}

export function clearTokens(): void {
  // No-op: tokens are cleared via Set-Cookie headers from the backend logout
}

// ---------------------------------------------------------------------------
// Core fetch wrapper
// ---------------------------------------------------------------------------

class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function apiFetch<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };

  const url = `${BASE_PATH}/api${path}`;
  const response = await fetch(url, {
    ...options,
    headers,
    credentials: "same-origin", // Send cookies automatically
  });

  // Handle 401 — try cookie-based token refresh
  if (response.status === 401) {
    const refreshed = await tryRefreshToken();
    if (refreshed) {
      const retryResponse = await fetch(url, {
        ...options,
        headers,
        credentials: "same-origin",
      });
      if (retryResponse.ok) {
        const data: ApiResponse<T> = await retryResponse.json();
        if (data.success && data.data !== undefined) return data.data;
        throw new ApiError(
          retryResponse.status,
          data.error?.code || "unknown",
          data.error?.message || "Unknown error"
        );
      }
    }
    // Refresh failed — redirect to login (skip if already on login page)
    if (typeof window !== "undefined" && !window.location.pathname.endsWith("/login")) {
      window.location.href = `${BASE_PATH}/login`;
    }
    throw new ApiError(401, "unauthorized", "Session expired");
  }

  if (!response.ok) {
    let errorData: ApiResponse<never>;
    try {
      errorData = await response.json();
    } catch {
      throw new ApiError(response.status, "unknown", response.statusText);
    }
    throw new ApiError(
      response.status,
      errorData.error?.code || "unknown",
      errorData.error?.message || "Unknown error"
    );
  }

  const data: ApiResponse<T> = await response.json();
  if (data.success && data.data !== undefined) {
    return data.data;
  }

  throw new ApiError(
    200,
    data.error?.code || "unknown",
    data.error?.message || "Unexpected response"
  );
}

async function tryRefreshToken(): Promise<boolean> {
  try {
    // The refresh_token cookie is sent automatically
    const response = await fetch(`${BASE_PATH}/api/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: "" }), // Backend reads from cookie
      credentials: "same-origin",
    });

    if (!response.ok) return false;

    const data: ApiResponse<AuthResponse> = await response.json();
    return data.success && !!data.data;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Auth API
// ---------------------------------------------------------------------------

export const authApi = {
  login: async (email: string, password: string): Promise<AuthResponse> => {
    const response = await fetch(`${BASE_PATH}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      credentials: "same-origin", // Receive Set-Cookie from backend
    });
    const data: ApiResponse<AuthResponse> = await response.json();
    if (data.success && data.data) {
      // Tokens are now in httpOnly cookies — no localStorage needed
      return data.data;
    }
    throw new ApiError(
      response.status,
      data.error?.code || "login_failed",
      data.error?.message || "Login failed"
    );
  },

  register: async (params: {
    email: string;
    phone: string;
    password: string;
    full_name: string;
    role?: string;
  }): Promise<UserResponse> => {
    const response = await fetch(`${BASE_PATH}/api/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(params),
      credentials: "same-origin",
    });
    const data: ApiResponse<UserResponse> = await response.json();
    if (data.success && data.data) return data.data;
    throw new ApiError(
      response.status,
      data.error?.code || "register_failed",
      data.error?.message || "Registration failed"
    );
  },

  getProfile: () => apiFetch<UserResponse>("/auth/me"),

  updateProfile: (params: {
    full_name?: string;
    phone?: string;
    avatar_url?: string;
  }) =>
    apiFetch<UserResponse>("/auth/me", {
      method: "PUT",
      body: JSON.stringify(params),
    }),

  logout: async (): Promise<void> => {
    try {
      await apiFetch<null>("/auth/logout", { method: "POST" });
    } catch {
      // Even if API call fails, cookies are cleared by the backend
    }
  },

  listUsers: (params?: {
    role?: string;
    approval_status?: string;
    search?: string;
    limit?: number;
    offset?: number;
  }) => {
    const query = new URLSearchParams();
    if (params?.role) query.set("role", params.role);
    if (params?.approval_status) query.set("approval_status", params.approval_status);
    if (params?.search) query.set("search", params.search);
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.offset) query.set("offset", String(params.offset));
    const qs = query.toString();
    return apiFetch<PaginatedUsers>(`/auth/users${qs ? `?${qs}` : ""}`);
  },

  updateApprovalStatus: (userId: string, approvalStatus: "pending" | "approved" | "rejected") =>
    apiFetch<UserResponse>(`/auth/users/${userId}/approval`, {
      method: "PATCH",
      body: JSON.stringify({ approval_status: approvalStatus }),
    }),

  /** Fetch a guard applicant's profile (experience, documents, bank info). Admin only. */
  getGuardProfile: (userId: string): Promise<GuardProfile> =>
    apiFetch<GuardProfile>(`/auth/admin/guard-profile/${userId}`),

  /** Fetch a customer's profile (company, address). Admin only. */
  getCustomerProfile: (userId: string): Promise<CustomerProfile> =>
    apiFetch<CustomerProfile>(`/auth/admin/customer-profile/${userId}`),

  /** List customer applicants (users with customer_profiles). Admin only. */
  listCustomerApplicants: (params?: {
    approval_status?: string;
    search?: string;
    limit?: number;
    offset?: number;
  }) => {
    const query = new URLSearchParams();
    if (params?.approval_status) query.set("approval_status", params.approval_status);
    if (params?.search) query.set("search", params.search);
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.offset) query.set("offset", String(params.offset));
    const qs = query.toString();
    return apiFetch<PaginatedUsers>(`/auth/admin/customer-applicants${qs ? `?${qs}` : ""}`);
  },

  /** Update a customer profile's approval status. Admin only. */
  updateCustomerApproval: (userId: string, approvalStatus: "pending" | "approved" | "rejected") =>
    apiFetch<null>(`/auth/admin/customer-profile/${userId}/approval`, {
      method: "PATCH",
      body: JSON.stringify({ approval_status: approvalStatus }),
    }),
};

// ---------------------------------------------------------------------------
// Booking API
// ---------------------------------------------------------------------------

export const bookingApi = {
  listRequests: (params?: {
    status?: string;
    limit?: number;
    offset?: number;
  }) => {
    const query = new URLSearchParams();
    if (params?.status) query.set("status", params.status);
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.offset) query.set("offset", String(params.offset));
    const qs = query.toString();
    return apiFetch<GuardRequest[]>(
      `/booking/requests${qs ? `?${qs}` : ""}`
    );
  },

  getRequest: (id: string) =>
    apiFetch<GuardRequest>(`/booking/requests/${id}`),

  createRequest: (params: {
    title: string;
    description: string;
    location_lat: number;
    location_lng: number;
    location_address: string;
    urgency: string;
    scheduled_start: string;
    scheduled_end?: string;
  }) =>
    apiFetch<GuardRequest>("/booking/requests", {
      method: "POST",
      body: JSON.stringify(params),
    }),

  cancelRequest: (id: string) =>
    apiFetch<GuardRequest>(`/booking/requests/${id}/cancel`, {
      method: "POST",
    }),

  listAssignments: (requestId: string) =>
    apiFetch<Assignment[]>(`/booking/requests/${requestId}/assignments`),

  assignGuard: (requestId: string, guardId: string) =>
    apiFetch<Assignment>(`/booking/requests/${requestId}/assign`, {
      method: "POST",
      body: JSON.stringify({ guard_id: guardId }),
    }),

  updateAssignmentStatus: (assignmentId: string, status: string) =>
    apiFetch<Assignment>(`/booking/assignments/${assignmentId}/status`, {
      method: "PUT",
      body: JSON.stringify({ status }),
    }),
};

// ---------------------------------------------------------------------------
// Pricing API
// ---------------------------------------------------------------------------

export const pricingApi = {
  listServiceRates: () =>
    apiFetch<ServiceRateResponse[]>("/booking/pricing/services"),

  createServiceRate: (data: {
    name: string;
    description?: string;
    min_price: number;
    max_price: number;
    base_fee: number;
    min_hours?: number;
    notes?: string;
  }) =>
    apiFetch<ServiceRateResponse>("/booking/pricing/services", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  updateServiceRate: (
    id: string,
    data: {
      name?: string;
      description?: string;
      min_price?: number;
      max_price?: number;
      base_fee?: number;
      min_hours?: number;
      notes?: string;
      is_active?: boolean;
    }
  ) =>
    apiFetch<ServiceRateResponse>(`/booking/pricing/services/${id}`, {
      method: "PUT",
      body: JSON.stringify(data),
    }),

  deleteServiceRate: (id: string) =>
    apiFetch<null>(`/booking/pricing/services/${id}`, {
      method: "DELETE",
    }),
};

// ---------------------------------------------------------------------------
// Reverse Geocoding (OpenStreetMap Nominatim)
// ---------------------------------------------------------------------------

const GEOCODE_CACHE_MAX = 500;
const geocodeCache = new Map<string, string>();

/** Reverse geocode lat/lng to a human-readable area name (Thai locale).
 *  Results are cached by ~500m grid to reduce API calls. Capped at 500 entries. */
export async function reverseGeocode(
  lat: number,
  lng: number
): Promise<string> {
  const key = `${lat.toFixed(3)},${lng.toFixed(3)}`;
  const cached = geocodeCache.get(key);
  if (cached) return cached;

  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json&zoom=14&accept-language=th`,
      { headers: { "User-Agent": "GuardDispatch/1.0" } }
    );
    if (!res.ok) throw new Error("geocode failed");
    const data = await res.json();
    const addr = data.address ?? {};
    const name =
      addr.suburb ??
      addr.city_district ??
      addr.subdistrict ??
      addr.town ??
      addr.city ??
      data.display_name?.split(",")[0] ??
      `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
    // Evict oldest entries when cache exceeds max size
    if (geocodeCache.size >= GEOCODE_CACHE_MAX) {
      const oldest = geocodeCache.keys().next().value;
      if (oldest !== undefined) geocodeCache.delete(oldest);
    }
    geocodeCache.set(key, name);
    return name;
  } catch {
    const fallback = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
    if (geocodeCache.size >= GEOCODE_CACHE_MAX) {
      const oldest = geocodeCache.keys().next().value;
      if (oldest !== undefined) geocodeCache.delete(oldest);
    }
    geocodeCache.set(key, fallback);
    return fallback;
  }
}

/** Batch reverse geocode multiple coordinates with rate-limit delay. */
export async function batchReverseGeocode(
  coords: { lat: number; lng: number }[]
): Promise<Map<string, string>> {
  const results = new Map<string, string>();
  const unique = new Map<string, { lat: number; lng: number }>();

  for (const c of coords) {
    const key = `${c.lat.toFixed(3)},${c.lng.toFixed(3)}`;
    if (!geocodeCache.has(key) && !unique.has(key)) {
      unique.set(key, c);
    }
  }

  // Geocode unique coords with 200ms delay between requests (Nominatim rate limit)
  for (const [, coord] of unique) {
    await reverseGeocode(coord.lat, coord.lng);
    if (unique.size > 1) {
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  for (const c of coords) {
    const key = `${c.lat.toFixed(3)},${c.lng.toFixed(3)}`;
    results.set(`${c.lat},${c.lng}`, geocodeCache.get(key) ?? `${c.lat.toFixed(4)}, ${c.lng.toFixed(4)}`);
  }

  return results;
}

// ---------------------------------------------------------------------------
// Tracking API
// ---------------------------------------------------------------------------

export const trackingApi = {
  getAllLocations: () =>
    apiFetch<GuardLocationWithName[]>(`/tracking/locations`),

  getLatestLocation: (guardId: string) =>
    apiFetch<GuardLocation>(`/tracking/locations/${guardId}`),

  getLocationHistory: (
    guardId: string,
    params?: {
      from?: string;
      to?: string;
      limit?: number;
    }
  ) => {
    const query = new URLSearchParams();
    if (params?.from) query.set("from", params.from);
    if (params?.to) query.set("to", params.to);
    if (params?.limit) query.set("limit", String(params.limit));
    const qs = query.toString();
    return apiFetch<LocationHistory[]>(
      `/tracking/locations/${guardId}/history${qs ? `?${qs}` : ""}`
    );
  },

  // WebSocket for real-time GPS — cookies are sent automatically on WS upgrade
  connectGpsWebSocket: (): WebSocket => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    return new WebSocket(
      `${protocol}//${window.location.host}/ws/track`
    );
  },
};

// ---------------------------------------------------------------------------
// Notification API
// ---------------------------------------------------------------------------

export const notificationApi = {
  list: (params?: {
    limit?: number;
    offset?: number;
    unread_only?: boolean;
  }) => {
    const query = new URLSearchParams();
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.offset) query.set("offset", String(params.offset));
    if (params?.unread_only) query.set("unread_only", "true");
    const qs = query.toString();
    return apiFetch<NotificationLog[]>(
      `/notification/notifications${qs ? `?${qs}` : ""}`
    );
  },

  markAsRead: (id: string) =>
    apiFetch<NotificationLog>(`/notification/notifications/${id}/read`, {
      method: "POST",
    }),

  registerFcmToken: (token: string, deviceType: string) =>
    apiFetch<null>("/notification/tokens", {
      method: "POST",
      body: JSON.stringify({ token, device_type: deviceType }),
    }),
};

// ---------------------------------------------------------------------------
// Chat API
// ---------------------------------------------------------------------------

export const chatApi = {
  listConversations: () =>
    apiFetch<Conversation[]>("/chat/conversations"),

  getMessages: (
    conversationId: string,
    params?: { limit?: number; before?: string }
  ) => {
    const query = new URLSearchParams();
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.before) query.set("before", params.before);
    const qs = query.toString();
    return apiFetch<ChatMessage[]>(
      `/chat/conversations/${conversationId}/messages${qs ? `?${qs}` : ""}`
    );
  },

  // WebSocket for real-time chat — cookies sent automatically on WS upgrade.
  // conversation_id is sent as the first message after connection (not in URL query params)
  // to avoid leaking it in server logs and proxy access logs.
  connectChatWebSocket: (conversationId: string): WebSocket => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const ws = new WebSocket(
      `${protocol}//${window.location.host}/ws/chat`
    );
    ws.addEventListener("open", () => {
      ws.send(JSON.stringify({ type: "join", conversation_id: conversationId }));
    });
    return ws;
  },

  uploadAttachment: async (conversationId: string, file: File) => {
    const formData = new FormData();
    formData.append("file", file);

    const response = await fetch(
      `${BASE_PATH}/api/chat/conversations/${conversationId}/attachments`,
      {
        method: "POST",
        body: formData,
        credentials: "same-origin", // Send cookies for auth
      }
    );

    const data = await response.json();
    if (data.success && data.data) return data.data;
    throw new ApiError(
      response.status,
      data.error?.code || "upload_failed",
      data.error?.message || "Upload failed"
    );
  },
};

export { ApiError };
