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
  id_card_expiry: string | null;
  security_license_expiry: string | null;
  training_cert_expiry: string | null;
  criminal_check_expiry: string | null;
  driver_license_expiry: string | null;
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

// Progress reports submitted hourly by guards during an active assignment.
// Admin uses these to resolve disputes ("did the guard actually show up?").
export interface ProgressReportMediaItem {
  id: string;
  url: string;
  mime_type: string;
  file_size: number;
  sort_order: number;
}

export interface ProgressReportItem {
  id: string;
  assignment_id: string;
  guard_id: string;
  hour_number: number;
  message: string | null;
  photo_url: string | null; // legacy single-photo field
  media: ProgressReportMediaItem[];
  created_at: string;
}

// Pricing types
export interface ServiceRateResponse {
  id: string;
  name: string;
  description: string | null;
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
  is_online: boolean;
  has_active_job: boolean;
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

/** True when the non-httpOnly `logged_in=1` marker cookie is present. */
export function hasLoggedInCookie(): boolean {
  if (typeof window === "undefined") return false;
  return document.cookie
    .split(";")
    .some((c) => c.trim().startsWith("logged_in="));
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
    "X-Requested-With": "XMLHttpRequest", // CSRF protection — required for cookie-based auth
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

// Singleton promise so concurrent 401s share a single refresh call.
// Without this, N parallel requests would each fire `POST /auth/refresh`,
// rotating the refresh token N times and racing the session-limit cap (5).
// Mirrors the mobile Dio interceptor's `_isReactiveRefreshing` flag.
let refreshInFlight: Promise<boolean> | null = null;

async function tryRefreshToken(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = (async () => {
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
    } finally {
      refreshInFlight = null;
    }
  })();
  return refreshInFlight;
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

  /** Admin: update guard profile fields. */
  updateGuardProfile: (userId: string, data: Record<string, unknown>): Promise<void> =>
    apiFetch<void>(`/auth/admin/guard-profile/${userId}`, { method: "PUT", body: JSON.stringify(data) }),

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

  /** Progress reports for an assignment (hourly guard check-ins with optional photos).
   *  Backend grants admin blanket access; non-admin must be the guard or customer. */
  listProgressReports: (assignmentId: string) =>
    apiFetch<ProgressReportItem[]>(
      `/booking/assignments/${assignmentId}/progress-reports`
    ),
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
// Admin Reviews API
// ---------------------------------------------------------------------------

export interface AdminReviewItem {
  id: string;
  assignment_id: string;
  request_id: string;
  customer_id: string;
  customer_name: string | null;
  guard_id: string;
  guard_name: string | null;
  overall_rating: number;
  punctuality: number | null;
  professionalism: number | null;
  communication: number | null;
  appearance: number | null;
  review_text: string | null;
  address: string | null;
  is_visible: boolean;
  created_at: string;
}

export interface AdminReviewStats {
  total: number;
  visible: number;
  avg_rating: number;
}

export interface PaginatedAdminReviews {
  data: AdminReviewItem[];
  total: number;
  limit: number;
  offset: number;
  stats: AdminReviewStats;
}

export const reviewsApi = {
  list: (params?: {
    guard_id?: string;
    rating?: number;
    is_visible?: boolean;
    search?: string;
    limit?: number;
    offset?: number;
  }) => {
    const query = new URLSearchParams();
    if (params?.guard_id) query.set("guard_id", params.guard_id);
    if (params?.rating !== undefined) query.set("rating", String(params.rating));
    if (params?.is_visible !== undefined)
      query.set("is_visible", String(params.is_visible));
    if (params?.search) query.set("search", params.search);
    if (params?.limit !== undefined) query.set("limit", String(params.limit));
    if (params?.offset !== undefined) query.set("offset", String(params.offset));
    const qs = query.toString();
    return apiFetch<PaginatedAdminReviews>(
      `/booking/admin/reviews${qs ? `?${qs}` : ""}`
    );
  },

  setVisibility: (id: string, is_visible: boolean) =>
    apiFetch<null>(`/booking/admin/reviews/${id}/visibility`, {
      method: "PUT",
      body: JSON.stringify({ is_visible }),
    }),
};

// ---------------------------------------------------------------------------
// Admin Wallet / Payments / Refunds (migration 042)
// ---------------------------------------------------------------------------

export interface AdminPaymentItem {
  payment_id: string;
  request_id: string;
  assignment_id: string | null;
  customer_id: string;
  customer_name: string | null;
  guard_id: string | null;
  guard_name: string | null;
  service_address: string;
  booked_hours: number | null;
  actual_hours_worked: number | null;
  original_amount: number;
  final_amount: number | null;
  refund_amount: number | null;
  tip_amount: number;
  payment_method: string;
  payment_status: string;
  refund_status: "pending" | "processed" | "skipped" | null;
  refund_processed_at: string | null;
  refund_reference: string | null;
  refund_processed_by: string | null;
  refund_processed_by_name: string | null;
  paid_at: string | null;
  completed_at: string | null;
}

export interface AdminPaymentsPage {
  data: AdminPaymentItem[];
  total: number;
}

export interface WalletSummaryResponse {
  monthly_revenue: number;
  pending_refunds_count: number;
  pending_refunds_total: number;
  processed_refunds_count: number;
  processed_refunds_total: number;
}

// ---------------------------------------------------------------------------
// Admin Audit Log (reads audit.audit_logs)
// ---------------------------------------------------------------------------

export interface AuditLogItem {
  id: string;
  user_id: string | null;
  user_name: string | null;
  user_role: string | null;
  action: string;
  entity_type: string;
  entity_id: string | null;
  ip_address: string | null;
  created_at: string;
}

export interface AuditLogsPage {
  data: AuditLogItem[];
  total: number;
}

// Document expiry dashboard — GET /auth/admin/guard-profiles/expiring
export interface ExpiringDocsItem {
  user_id: string;
  full_name: string;
  phone: string;
  avatar_url: string | null;
  /** ISO date (YYYY-MM-DD) — earliest expiry across the 5 docs. */
  earliest_expiry: string;
  /** Negative = already expired. */
  days_until_expiry: number;
  id_card_expiry: string | null;
  security_license_expiry: string | null;
  training_cert_expiry: string | null;
  criminal_check_expiry: string | null;
  driver_license_expiry: string | null;
}

export interface ExpiringDocsPage {
  data: ExpiringDocsItem[];
  total: number;
  /** Across all guards, not limited by the query window. */
  expired_count: number;
  /** Guards with at least one doc expiring in the next 30 days. */
  expiring_soon_count: number;
}

export const auditApi = {
  list: (params?: {
    search?: string;
    entity_type?: string;
    user_id?: string;
    from?: string;
    to?: string;
    limit?: number;
    offset?: number;
  }) => {
    const q = new URLSearchParams();
    if (params?.search) q.set("search", params.search);
    if (params?.entity_type) q.set("entity_type", params.entity_type);
    if (params?.user_id) q.set("user_id", params.user_id);
    if (params?.from) q.set("from", params.from);
    if (params?.to) q.set("to", params.to);
    if (params?.limit !== undefined) q.set("limit", String(params.limit));
    if (params?.offset !== undefined) q.set("offset", String(params.offset));
    const qs = q.toString();
    return apiFetch<AuditLogsPage>(
      `/auth/admin/audit-logs${qs ? `?${qs}` : ""}`
    );
  },
};

export const expiringDocsApi = {
  list: (params?: { within_days?: number; limit?: number; offset?: number }) => {
    const q = new URLSearchParams();
    if (params?.within_days !== undefined)
      q.set("within_days", String(params.within_days));
    if (params?.limit !== undefined) q.set("limit", String(params.limit));
    if (params?.offset !== undefined) q.set("offset", String(params.offset));
    const qs = q.toString();
    return apiFetch<ExpiringDocsPage>(
      `/auth/admin/guard-profiles/expiring${qs ? `?${qs}` : ""}`
    );
  },
};

export const walletApi = {
  summary: () =>
    apiFetch<WalletSummaryResponse>("/booking/admin/wallet/summary"),

  listPayments: (params?: {
    status?: string;
    method?: string;
    limit?: number;
    offset?: number;
  }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.method) q.set("method", params.method);
    if (params?.limit !== undefined) q.set("limit", String(params.limit));
    if (params?.offset !== undefined) q.set("offset", String(params.offset));
    const qs = q.toString();
    return apiFetch<AdminPaymentsPage>(
      `/booking/admin/payments${qs ? `?${qs}` : ""}`
    );
  },

  getPayment: (id: string) =>
    apiFetch<AdminPaymentItem>(`/booking/admin/payments/${id}`),

  listRefunds: (params?: {
    status?: "pending" | "processed" | "skipped";
    limit?: number;
    offset?: number;
  }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set("status", params.status);
    if (params?.limit !== undefined) q.set("limit", String(params.limit));
    if (params?.offset !== undefined) q.set("offset", String(params.offset));
    const qs = q.toString();
    return apiFetch<AdminPaymentsPage>(
      `/booking/admin/refunds${qs ? `?${qs}` : ""}`
    );
  },

  /** Mark a refund processed (bank transfer done) or skipped (customer waived). */
  processRefund: (
    paymentId: string,
    body: { action: "process" | "skip"; reference?: string; note?: string }
  ) =>
    apiFetch<AdminPaymentItem>(
      `/booking/admin/refunds/${paymentId}/process`,
      { method: "PUT", body: JSON.stringify(body) }
    ),
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
      method: "PUT",
    }),

  markAllAsRead: () =>
    apiFetch<{ count: number }>("/notification/notifications/read-all", {
      method: "PUT",
    }),

  unreadCount: () =>
    apiFetch<{ count: number }>("/notification/notifications/unread-count"),

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
    formData.append("conversation_id", conversationId);
    formData.append("file", file);

    // Backend route is POST /chat/attachments (flat, not nested under conversations).
    // conversation_id travels in the multipart body — matches the mobile client.
    const response = await fetch(`${BASE_PATH}/api/chat/attachments`, {
      method: "POST",
      body: formData,
      credentials: "same-origin", // Send cookies for auth
    });

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
