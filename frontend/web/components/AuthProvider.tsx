"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useRef,
  type ReactNode,
} from "react";
import { useRouter, usePathname } from "next/navigation";
import {
  authApi,
  type UserResponse,
} from "@/lib/api";

interface AuthContextType {
  user: UserResponse | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

// 15 minutes of inactivity → auto logout. Also enforced on page load
// so closing the browser for >15 minutes logs the user out on return.
const IDLE_TIMEOUT_MS = 15 * 60 * 1000;
const ACTIVITY_STORAGE_KEY = "admin_last_activity_ts";

export function AuthProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<UserResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const isAuthenticated = !!user;

  // Load user profile once on mount — cookies are sent automatically
  // Skip on login page to avoid 401 → redirect → reload loop
  useEffect(() => {
    if (pathname === "/login") {
      setIsLoading(false);
      return;
    }
    authApi
      .getProfile()
      .then((profile) => {
        setUser(profile);
      })
      .catch(() => {
        setUser(null);
      })
      .finally(() => setIsLoading(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally run once on mount only; redirect effect handles subsequent navigation
  }, []);

  // Redirect to login if not authenticated (except on login page)
  useEffect(() => {
    if (!isLoading && !isAuthenticated && pathname !== "/login") {
      router.push("/login");
    }
  }, [isLoading, isAuthenticated, pathname, router]);

  const login = useCallback(
    async (email: string, password: string) => {
      await authApi.login(email, password);
      const profile = await authApi.getProfile();
      setUser(profile);
      router.push("/");
    },
    [router]
  );

  const logout = useCallback(async () => {
    try {
      await authApi.logout();
    } catch {
      // Even if API call fails, cookies are cleared by backend
    }
    if (typeof window !== "undefined") {
      localStorage.removeItem(ACTIVITY_STORAGE_KEY);
    }
    setUser(null);
    router.push("/login");
  }, [router]);

  const idleTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Idle logout: 15 min no activity → logout. Activity timestamp stored
  // in localStorage so a page reload / browser close also enforces the rule,
  // and so other open tabs don't drop the user when only one tab is idle.
  useEffect(() => {
    if (!isAuthenticated || typeof window === "undefined") return;

    // The setTimeout callback re-reads the shared `last_activity_ts` so a
    // tab that's been quiet doesn't hang up the session when another tab
    // has been bumping the timestamp the whole time. If activity is fresh,
    // we just reschedule for the remaining slack instead of logging out.
    const scheduleIdleLogout = (delay = IDLE_TIMEOUT_MS) => {
      if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
      idleTimerRef.current = setTimeout(() => {
        const lastTs = Number(localStorage.getItem(ACTIVITY_STORAGE_KEY) || 0);
        const idleFor = Date.now() - lastTs;
        if (lastTs > 0 && idleFor < IDLE_TIMEOUT_MS) {
          // Another tab (or this tab via storage event) updated the
          // timestamp while we were waiting — reschedule for the remaining
          // window rather than logging out.
          scheduleIdleLogout(IDLE_TIMEOUT_MS - idleFor);
          return;
        }
        void logout();
      }, delay);
    };

    const onActivity = () => {
      localStorage.setItem(ACTIVITY_STORAGE_KEY, String(Date.now()));
      scheduleIdleLogout();
    };

    // Cross-tab sync — when another tab fires `setItem`, this tab gets a
    // `storage` event. Refresh our timer without writing again (avoids the
    // ping-pong that would happen if every tab wrote on every tab's read).
    const onStorage = (e: StorageEvent) => {
      if (e.key === ACTIVITY_STORAGE_KEY) {
        scheduleIdleLogout();
      }
    };

    const storedTs = Number(localStorage.getItem(ACTIVITY_STORAGE_KEY) || 0);
    if (storedTs > 0 && Date.now() - storedTs > IDLE_TIMEOUT_MS) {
      void logout();
      return;
    }

    onActivity();

    // `mousemove` and `pointerdown` cover users who scan tables / drawers
    // without clicking; without them we logged people out mid-read.
    // `passive: true` keeps the listeners from blocking scroll/touch.
    const events: (keyof WindowEventMap)[] = [
      "mousedown",
      "mousemove",
      "pointerdown",
      "keydown",
      "scroll",
      "touchstart",
    ];
    for (const ev of events) window.addEventListener(ev, onActivity, { passive: true });
    window.addEventListener("storage", onStorage);

    return () => {
      if (idleTimerRef.current) clearTimeout(idleTimerRef.current);
      for (const ev of events) window.removeEventListener(ev, onActivity);
      window.removeEventListener("storage", onStorage);
    };
  }, [isAuthenticated, logout]);

  const refreshUser = useCallback(async () => {
    try {
      const profile = await authApi.getProfile();
      setUser(profile);
    } catch {
      // Ignore
    }
  }, []);

  return (
    <AuthContext.Provider
      value={{ user, isLoading, isAuthenticated, login, logout, refreshUser }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
