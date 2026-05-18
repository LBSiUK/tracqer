import { useState, FormEvent } from "react";
import { useAuth } from "../lib/auth";

export default function Login() {
  const { login } = useAuth();
  const [serverUrl, setServerUrl] = useState("http://localhost:8000");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [phase, setPhase] = useState<"idle" | "pinging" | "deriving" | "verifying">("idle");

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!serverUrl.trim()) {
      setError("Please enter a server URL.");
      return;
    }
    if (!password) {
      setError("Please enter a password.");
      return;
    }

    setLoading(true);

    try {
      setPhase("pinging");
      // ping is handled inside login(), but we show the phase for UX
      setPhase("deriving");
      // Small yield so React can re-render the spinner before PBKDF2 locks CPU
      await new Promise((r) => setTimeout(r, 10));
      setPhase("verifying");
      await login(serverUrl.trim(), password);
      // Navigation happens automatically via App.tsx redirect
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed. Please try again.");
    } finally {
      setLoading(false);
      setPhase("idle");
    }
  };

  const phaseLabel: Record<typeof phase, string> = {
    idle: "Sign in",
    pinging: "Contacting server…",
    deriving: "Deriving key…",
    verifying: "Verifying…",
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-header">
          <div className="login-logo">
            <svg
              width="48"
              height="48"
              viewBox="0 0 48 48"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              aria-hidden="true"
            >
              <circle cx="24" cy="24" r="22" stroke="#f59e0b" strokeWidth="2" />
              <circle cx="24" cy="24" r="16" stroke="#f59e0b" strokeWidth="1.5" opacity="0.6" />
              <circle cx="24" cy="24" r="10" stroke="#f59e0b" strokeWidth="1.5" opacity="0.4" />
              <circle cx="24" cy="24" r="5" fill="#f59e0b" opacity="0.8" />
              <circle cx="24" cy="24" r="2" fill="#111114" />
            </svg>
          </div>
          <div className="login-title">Vinyl Collection</div>
          <div className="login-subtitle">Sign in to your collection</div>
        </div>

        <form className="login-form" onSubmit={handleSubmit} noValidate>
          <div className="form-group">
            <label htmlFor="server-url">Server URL</label>
            <input
              id="server-url"
              type="url"
              value={serverUrl}
              onChange={(e) => setServerUrl(e.target.value)}
              placeholder="http://localhost:8000"
              disabled={loading}
              autoComplete="url"
              spellCheck={false}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter your password"
              disabled={loading}
              autoComplete="current-password"
            />
          </div>

          {error && <div className="error-message">{error}</div>}

          <button
            type="submit"
            className="btn btn-primary login-submit"
            disabled={loading}
          >
            {loading ? (
              <>
                <span className="spinner-sm" />
                {phaseLabel[phase]}
              </>
            ) : (
              "Sign in"
            )}
          </button>
        </form>
      </div>
    </div>
  );
}
