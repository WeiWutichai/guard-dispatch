// =============================================================================
// API Client — Guard Dispatch Admin Portal
// Connects to Rust backend services via Nginx gateway
// =============================================================================

const BASE_PATH = "/pguard-app";

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
  role: "admin" | "customer" | "guard";
  avatar_url: string | null;
  is_active: boolean;
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
// Token management
// ---------------------------------------------------------------------------

const TOKEN_KEY = "guard_dispatch_access_token";
const REFRESH_TOKEN_KEY = "guard_dispatch_refresh_token";

export function getAccessToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getRefreshToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(REFRESH_TOKEN_KEY);
}

export function setTokens(accessToken: string, refreshToken: string): void {
  localStorage.setItem(TOKEN_KEY, accessToken);
  localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
}

export function clearTokens(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
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
  const token = getAccessToken();

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const url = `${BASE_PATH}/api${path}`;
  const response = await fetch(url, {
    ...options,
    headers,
  });

  // Handle 401 — try token refresh
  if (response.status === 401 && token) {
    const refreshed = await tryRefreshToken();
    if (refreshed) {
      headers["Authorization"] = `Bearer ${getAccessToken()}`;
      const retryResponse = await fetch(url, { ...options, headers });
      if (retryResponse.ok) {
        const data: ApiResponse<T> = await retryResponse.json();
        if (data.success && data.data !== undefined) return data.data;
        throw new ApiError(retryResponse.status, data.error?.code || "unknown", data.error?.message || "Unknown error");
      }
    }
    // Refresh failed — redirect to login
    clearTokens();
    if (typeof window !== "undefined") {
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

  throw new ApiError(200, data.error?.code || "unknown", data.error?.message || "Unexpected response");
}

async function tryRefreshToken(): Promise<boolean> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return false;

  try {
    const response = await fetch(`${BASE_PATH}/api/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });

    if (!response.ok) return false;

    const data: ApiResponse<AuthResponse> = await response.json();
    if (data.success && data.data) {
      setTokens(data.data.access_token, data.data.refresh_token);
      return true;
    }
    return false;
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
    });
    const data: ApiResponse<AuthResponse> = await response.json();
    if (data.success && data.data) {
      setTokens(data.data.access_token, data.data.refresh_token);
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
    } finally {
      clearTokens();
    }
  },
};

// ---------------------------------------------------------------------------
// Booking API
// ---------------------------------------------------------------------------

export const bookingApi = {
  listRequests: (params?: { status?: string; limit?: number; offset?: number }) => {
    const query = new URLSearchParams();
    if (params?.status) query.set("status", params.status);
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.offset) query.set("offset", String(params.offset));
    const qs = query.toString();
    return apiFetch<GuardRequest[]>(`/booking/requests${qs ? `?${qs}` : ""}`);
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
// Tracking API
// ---------------------------------------------------------------------------

export const trackingApi = {
  getLatestLocation: (guardId: string) =>
    apiFetch<GuardLocation>(`/tracking/locations/${guardId}`),

  getLocationHistory: (guardId: string, params?: {
    from?: string;
    to?: string;
    limit?: number;
  }) => {
    const query = new URLSearchParams();
    if (params?.from) query.set("from", params.from);
    if (params?.to) query.set("to", params.to);
    if (params?.limit) query.set("limit", String(params.limit));
    const qs = query.toString();
    return apiFetch<LocationHistory[]>(
      `/tracking/locations/${guardId}/history${qs ? `?${qs}` : ""}`
    );
  },

  // WebSocket connection for real-time GPS
  connectGpsWebSocket: (): WebSocket => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const token = getAccessToken();
    return new WebSocket(
      `${protocol}//${window.location.host}/ws/track?token=${token}`
    );
  },
};

// ---------------------------------------------------------------------------
// Notification API
// ---------------------------------------------------------------------------

export const notificationApi = {
  list: (params?: { limit?: number; offset?: number; unread_only?: boolean }) => {
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

  getMessages: (conversationId: string, params?: { limit?: number; before?: string }) => {
    const query = new URLSearchParams();
    if (params?.limit) query.set("limit", String(params.limit));
    if (params?.before) query.set("before", params.before);
    const qs = query.toString();
    return apiFetch<ChatMessage[]>(
      `/chat/conversations/${conversationId}/messages${qs ? `?${qs}` : ""}`
    );
  },

  // WebSocket connection for real-time chat
  connectChatWebSocket: (conversationId: string): WebSocket => {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    const token = getAccessToken();
    return new WebSocket(
      `${protocol}//${window.location.host}/ws/chat?token=${token}&conversation_id=${conversationId}`
    );
  },

  uploadAttachment: async (conversationId: string, file: File) => {
    const token = getAccessToken();
    const formData = new FormData();
    formData.append("file", file);

    const response = await fetch(
      `${BASE_PATH}/api/chat/conversations/${conversationId}/attachments`,
      {
        method: "POST",
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: formData,
      }
    );

    const data = await response.json();
    if (data.success && data.data) return data.data;
    throw new ApiError(response.status, data.error?.code || "upload_failed", data.error?.message || "Upload failed");
  },
};

export { ApiError };
