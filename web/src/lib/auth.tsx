import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
} from "react";
import { deriveKey, keyToToken } from "./crypto";
import { VinylAPI } from "./api";

interface AuthState {
  api: VinylAPI;
  serverUrl: string;
}

interface AuthContextValue {
  auth: AuthState | null;
  loading: boolean;
  login: (serverUrl: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const STORAGE_KEY = "vinyl_session";

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [auth, setAuth] = useState<AuthState | null>(null);
  const [loading, setLoading] = useState(true);

  // On mount, attempt to restore session from localStorage
  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      try {
        const data = JSON.parse(stored) as {
          baseUrl: string;
          keyB64: string;
          token: string;
        };
        VinylAPI.deserialize(data)
          .then((api) => {
            setAuth({ api, serverUrl: data.baseUrl });
          })
          .catch(() => {
            localStorage.removeItem(STORAGE_KEY);
          })
          .finally(() => {
            setLoading(false);
          });
      } catch {
        localStorage.removeItem(STORAGE_KEY);
        setLoading(false);
      }
    } else {
      setLoading(false);
    }
  }, []);

  const login = useCallback(
    async (serverUrl: string, password: string): Promise<void> => {
      // Normalise URL — strip trailing slash
      serverUrl = serverUrl.replace(/\/+$/, "");

      // Ping server
      const alive = await VinylAPI.ping(serverUrl);
      if (!alive) {
        throw new Error("Cannot reach server. Check the URL and try again.");
      }

      // Derive key (PBKDF2 — takes ~200ms)
      const key = await deriveKey(password);
      const token = await keyToToken(key);

      // Verify credentials
      const valid = await VinylAPI.verify(serverUrl, key, token);
      if (!valid) {
        throw new Error("Invalid password. Please try again.");
      }

      const api = new VinylAPI(serverUrl, key, token);

      // Persist session
      const serialized = await api.serialize();
      localStorage.setItem(STORAGE_KEY, JSON.stringify(serialized));

      setAuth({ api, serverUrl });
    },
    []
  );

  const logout = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY);
    setAuth(null);
  }, []);

  return (
    <AuthContext.Provider value={{ auth, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return ctx;
}

export function useRequireAuth(): AuthState {
  const { auth } = useAuth();
  if (!auth) {
    throw new Error("useRequireAuth: not authenticated");
  }
  return auth;
}
