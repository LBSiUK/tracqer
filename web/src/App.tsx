import { Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./lib/auth";
import Login from "./pages/Login";
import Collection from "./pages/Collection";
import RecordDetail from "./pages/RecordDetail";
import AddEditRecord from "./pages/AddEditRecord";

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { auth, loading } = useAuth();

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner" />
      </div>
    );
  }

  if (!auth) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

export default function App() {
  const { auth, loading } = useAuth();

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner" />
      </div>
    );
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={auth ? <Navigate to="/" replace /> : <Login />}
      />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Collection />
          </ProtectedRoute>
        }
      />
      <Route
        path="/records/new"
        element={
          <ProtectedRoute>
            <AddEditRecord />
          </ProtectedRoute>
        }
      />
      <Route
        path="/records/:id"
        element={
          <ProtectedRoute>
            <RecordDetail />
          </ProtectedRoute>
        }
      />
      <Route
        path="/records/:id/edit"
        element={
          <ProtectedRoute>
            <AddEditRecord />
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
