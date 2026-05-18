import { useState, useEffect } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { useRequireAuth } from "../lib/auth";
import type { VinylRecord } from "../lib/types";
import PhotoGallery from "../components/PhotoGallery";

function OwnerBadge({ owner }: { owner: string }) {
  const cls =
    owner === "me"
      ? "badge-owner-me"
      : owner === "dad"
      ? "badge-owner-dad"
      : "badge-owner-shared";
  return <span className={`badge ${cls}`}>{owner}</span>;
}

function ConfirmDialog({
  title,
  message,
  onConfirm,
  onCancel,
  loading,
}: {
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
  loading: boolean;
}) {
  return (
    <div className="dialog-overlay" onClick={onCancel}>
      <div className="dialog" onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        <p>{message}</p>
        <div className="dialog-actions">
          <button
            className="btn btn-ghost"
            onClick={onCancel}
            disabled={loading}
          >
            Cancel
          </button>
          <button
            className="btn btn-danger"
            onClick={onConfirm}
            disabled={loading}
          >
            {loading ? <span className="spinner-sm" /> : "Delete"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function RecordDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { api } = useRequireAuth();

  const [record, setRecord] = useState<VinylRecord | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    setError(null);
    api
      .getRecord(id)
      .then(setRecord)
      .catch((err) => {
        setError(
          err instanceof Error ? err.message : "Failed to load record."
        );
      })
      .finally(() => setLoading(false));
  }, [api, id]);

  const handleDelete = async () => {
    if (!id) return;
    setDeleting(true);
    try {
      await api.deleteRecord(id);
      navigate("/", { replace: true });
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to delete record."
      );
      setDeleting(false);
      setShowDeleteDialog(false);
    }
  };

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="page">
        <div className="error-message">{error}</div>
        <button
          className="btn btn-ghost"
          style={{ marginTop: "1rem" }}
          onClick={() => navigate("/")}
        >
          Back to collection
        </button>
      </div>
    );
  }

  if (!record) return null;

  const rows: { label: string; value: React.ReactNode }[] = [
    { label: "Label", value: record.label ?? "—" },
    { label: "Genre", value: record.genre ?? "—" },
    { label: "Duration", value: record.duration ?? "—" },
    { label: "Discs", value: record.disc_count ?? 1 },
    {
      label: "Speed",
      value: record.speed ? (
        <span className="badge badge-speed">{record.speed} RPM</span>
      ) : (
        "—"
      ),
    },
    {
      label: "Owner",
      value: <OwnerBadge owner={record.owner} />,
    },
    {
      label: "Disc Condition",
      value: record.disc_condition ? (
        <span className="badge badge-grade">{record.disc_condition}</span>
      ) : (
        "—"
      ),
    },
    {
      label: "Sleeve Condition",
      value: record.sleeve_condition ? (
        <span className="badge badge-grade">{record.sleeve_condition}</span>
      ) : (
        "—"
      ),
    },
    { label: "Notes", value: record.notes ?? "—" },
    {
      label: "Added",
      value: new Date(record.created_at).toLocaleDateString(undefined, {
        year: "numeric",
        month: "long",
        day: "numeric",
      }),
    },
  ];

  return (
    <div className="page">
      {/* Back + actions */}
      <div className="page-header">
        <div className="page-header-left">
          <button className="back-btn" onClick={() => navigate(-1)}>
            ← Back
          </button>
        </div>
        <div className="detail-actions">
          <Link
            to={`/records/${record.id}/edit`}
            className="btn btn-ghost btn-sm"
          >
            Edit
          </Link>
          <button
            className="btn btn-danger btn-sm"
            onClick={() => setShowDeleteDialog(true)}
          >
            Delete
          </button>
        </div>
      </div>

      {/* Header */}
      <div className="record-detail-header">
        <div className="record-title-block">
          <div className="record-artist">{record.artist}</div>
          <div style={{ display: "flex", alignItems: "baseline", gap: "0.5rem" }}>
            <h1 className="record-title">{record.title}</h1>
            {record.year && (
              <span className="record-year">({record.year})</span>
            )}
          </div>
        </div>
        <div className="detail-badges">
          {record.format && (
            <span className="badge badge-format">{record.format}</span>
          )}
          {record.speed && (
            <span className="badge badge-speed">{record.speed} RPM</span>
          )}
          <OwnerBadge owner={record.owner} />
        </div>
      </div>

      {/* Metadata */}
      <div className="detail-section">
        <div className="detail-section-title">Details</div>
        <table className="metadata-table">
          <tbody>
            {rows.map((row) => (
              <tr key={row.label}>
                <th scope="row">{row.label}</th>
                <td>{row.value}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Photos */}
      <div className="detail-section">
        <div className="detail-section-title">Photos</div>
        <PhotoGallery
          photos={record.photos}
          api={api}
          recordId={record.id}
        />
      </div>

      {/* Delete confirmation */}
      {showDeleteDialog && (
        <ConfirmDialog
          title="Delete record?"
          message={`Are you sure you want to delete "${record.artist} — ${record.title}"? This cannot be undone.`}
          onConfirm={handleDelete}
          onCancel={() => setShowDeleteDialog(false)}
          loading={deleting}
        />
      )}
    </div>
  );
}
