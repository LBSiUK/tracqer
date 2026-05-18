import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useRequireAuth } from "../lib/auth";
import type {
  VinylRecord,
  RecordInput,
  Grade,
  Format,
  Speed,
  Owner,
  PhotoType,
} from "../lib/types";
import PhotoSlot from "../components/PhotoSlot";

// ─── Enum constants ───────────────────────────────────────────────────────────
const GRADES: Grade[] = ["M", "NM", "VG+", "VG", "G+", "G", "F", "P"];
const FORMATS: Format[] = ['12" LP', '10" LP', '12" single', '7" single', 'Other'];
const SPEEDS: Speed[] = ["33", "45", "78"];
const OWNERS: Owner[] = ["me", "dad", "shared"];
const ALL_SLEEVE_TYPES: { type: PhotoType; label: string; wide?: boolean; innerOnly?: boolean }[] = [
  { type: "sleeve_front",       label: "Front" },
  { type: "sleeve_back",        label: "Back" },
  { type: "sleeve_inner",       label: "Gatefold", wide: true },
  { type: "inner_sleeve_front", label: "Inner Sleeve (Front)", innerOnly: true },
  { type: "inner_sleeve_back",  label: "Inner Sleeve (Back)",  innerOnly: true },
];

// ─── Types ────────────────────────────────────────────────────────────────────
type PhotoAction =
  | { kind: "upload"; file: File }
  | { kind: "delete" }
  | { kind: "keep" };

interface PhotoSlotState {
  action: PhotoAction;
}

// Map from slot key -> state. Sleeve keys: "sleeve_front" etc.
// Disc keys: "disc_front_1", "disc_back_1", "disc_front_2" etc.
type PhotoStates = Record<string, PhotoSlotState>;

function slotKey(type: PhotoType, discNumber?: number): string {
  if (discNumber !== undefined) return `${type}_${discNumber}`;
  return type;
}

function parseSlotKey(key: string): { type: PhotoType; discNumber?: number } {
  const discMatch = key.match(/^(disc_front|disc_back)_(\d+)$/);
  if (discMatch) {
    return {
      type: discMatch[1] as PhotoType,
      discNumber: parseInt(discMatch[2], 10),
    };
  }
  return { type: key as PhotoType };
}

// ─── Component ────────────────────────────────────────────────────────────────
export default function AddEditRecord() {
  const { id } = useParams<{ id: string }>();
  const isEdit = Boolean(id);
  const navigate = useNavigate();
  const { api } = useRequireAuth();

  // Form fields
  const [title, setTitle] = useState("");
  const [artist, setArtist] = useState("");
  const [year, setYear] = useState("");
  const [duration, setDuration] = useState("");
  const [label, setLabel] = useState("");
  const [format, setFormat] = useState<Format | "">("");
  const [speed, setSpeed] = useState<Speed | "">("");
  const [genre, setGenre] = useState("");
  const [notes, setNotes] = useState("");
  const [owner, setOwner] = useState<Owner>("me");
  const [discCount, setDiscCount] = useState(1);
  const [outerSleeveOnly, setOuterSleeveOnly] = useState(false);
  const [discCondition, setDiscCondition] = useState<Grade | "">("");
  const [sleeveCondition, setSleeveCondition] = useState<Grade | "">("");

  // Photo state
  const [photoStates, setPhotoStates] = useState<PhotoStates>({});
  const [existingRecord, setExistingRecord] = useState<VinylRecord | null>(
    null
  );

  const [loadingRecord, setLoadingRecord] = useState(isEdit);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // ─── Load existing record for edit mode ───────────────────────────────────
  useEffect(() => {
    if (!isEdit || !id) return;
    setLoadingRecord(true);
    api
      .getRecord(id)
      .then((rec) => {
        setExistingRecord(rec);
        setTitle(rec.title);
        setArtist(rec.artist);
        setYear(rec.year !== null ? String(rec.year) : "");
        setDuration(rec.duration ?? "");
        setLabel(rec.label ?? "");
        setFormat(rec.format ?? "");
        setSpeed(rec.speed ?? "");
        setGenre(rec.genre ?? "");
        setNotes(rec.notes ?? "");
        setOwner(rec.owner);
        setDiscCount(rec.disc_count ?? 1);
        setOuterSleeveOnly(rec.outer_sleeve_only ?? false);
        setDiscCondition(rec.disc_condition ?? "");
        setSleeveCondition(rec.sleeve_condition ?? "");
      })
      .catch((err) => {
        setError(
          err instanceof Error ? err.message : "Failed to load record."
        );
      })
      .finally(() => setLoadingRecord(false));
  }, [api, id, isEdit]);

  // ─── Photo slot helpers ───────────────────────────────────────────────────
  const getSlotState = useCallback(
    (key: string): PhotoSlotState => {
      return photoStates[key] ?? { action: { kind: "keep" } };
    },
    [photoStates]
  );

  const setSlotFile = useCallback(
    (key: string, file: File | null) => {
      setPhotoStates((prev) => ({
        ...prev,
        [key]: {
          action:
            file === null ? { kind: "delete" } : { kind: "upload", file },
        },
      }));
    },
    []
  );

  const getExistingUrl = useCallback(
    (key: string): string | undefined => {
      if (!existingRecord) return undefined;
      const { type, discNumber } = parseSlotKey(key);
      const photo = existingRecord.photos.find(
        (p) =>
          p.photo_type === type &&
          (discNumber === undefined
            ? p.disc_number === null
            : p.disc_number === discNumber)
      );
      if (!photo) return undefined;
      return discNumber !== undefined
        ? api.photoUrl(existingRecord.id, type, discNumber)
        : api.photoUrl(existingRecord.id, type);
    },
    [existingRecord, api]
  );

  const hasExistingPhoto = useCallback(
    (key: string): boolean => {
      return getExistingUrl(key) !== undefined;
    },
    [getExistingUrl]
  );

  const discNumbers = Array.from({ length: discCount }, (_, i) => i + 1);

  const sleeveTypes = outerSleeveOnly
    ? ALL_SLEEVE_TYPES.filter((s) => !s.innerOnly)
    : ALL_SLEEVE_TYPES;

  // ─── Build RecordInput ────────────────────────────────────────────────────
  const buildMetadata = (): RecordInput => ({
    title: title.trim(),
    artist: artist.trim(),
    year: year ? parseInt(year, 10) : null,
    duration: duration.trim() || null,
    label: label.trim() || null,
    format: format || null,
    speed: speed || null,
    genre: genre.trim() || null,
    notes: notes.trim() || null,
    owner,
    disc_count: discCount,
    outer_sleeve_only: outerSleeveOnly,
    disc_condition: discCondition || null,
    sleeve_condition: sleeveCondition || null,
  });

  // ─── Submit ───────────────────────────────────────────────────────────────
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!title.trim()) {
      setError("Title is required.");
      return;
    }
    if (!artist.trim()) {
      setError("Artist is required.");
      return;
    }

    setSubmitting(true);
    try {
      const metadata = buildMetadata();

      if (!isEdit) {
        // ── Create: POST multipart with all photos ──────────────────────────
        const photos: Record<string, File> = {};
        for (const [key, state] of Object.entries(photoStates)) {
          if (state.action.kind === "upload") {
            const { type, discNumber } = parseSlotKey(key);
            const fieldName =
              discNumber !== undefined ? `${type}_${discNumber}` : type;
            photos[fieldName] = state.action.file;
          }
        }
        const record = await api.createRecord(metadata, photos);
        navigate(`/records/${record.id}`, { replace: true });
      } else if (id) {
        // ── Edit: PATCH metadata then handle photo mutations ─────────────────
        await api.updateRecord(id, metadata);

        // Process each photo slot
        const photoOps: Promise<void>[] = [];

        // Sleeve photos (only the currently visible slots)
        for (const { type } of sleeveTypes) {
          const key = slotKey(type);
          const state = getSlotState(key);
          if (state.action.kind === "upload") {
            photoOps.push(api.uploadPhoto(id, type, state.action.file));
          } else if (state.action.kind === "delete" && hasExistingPhoto(key)) {
            photoOps.push(api.deletePhoto(id, type));
          }
        }

        // If outer_sleeve_only was just enabled, delete any existing inner sleeve photos
        if (outerSleeveOnly) {
          for (const innerType of ["inner_sleeve_front", "inner_sleeve_back"] as PhotoType[]) {
            if (hasExistingPhoto(slotKey(innerType))) {
              photoOps.push(api.deletePhoto(id, innerType));
            }
          }
        }

        // Disc photos — existing discs beyond new disc_count get deleted
        const existingDiscNums = Array.from(
          new Set(
            existingRecord?.photos
              .filter((p) => p.photo_type === "disc_front" || p.photo_type === "disc_back")
              .map((p) => p.disc_number ?? 1) ?? []
          )
        );
        const allDiscNums = Array.from(new Set([...discNumbers, ...existingDiscNums]));

        for (const discNum of allDiscNums) {
          for (const discType of ["disc_front", "disc_back"] as PhotoType[]) {
            const key = slotKey(discType, discNum);
            const state = getSlotState(key);
            const isRemoved = !discNumbers.includes(discNum);

            if (isRemoved && hasExistingPhoto(key)) {
              photoOps.push(api.deletePhoto(id, discType, discNum));
            } else if (state.action.kind === "upload") {
              photoOps.push(api.uploadPhoto(id, discType, state.action.file, discNum));
            } else if (state.action.kind === "delete" && hasExistingPhoto(key)) {
              photoOps.push(api.deletePhoto(id, discType, discNum));
            }
          }
        }

        await Promise.all(photoOps);
        navigate(`/records/${id}`, { replace: true });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save record.");
    } finally {
      setSubmitting(false);
    }
  };

  // ─── Render ───────────────────────────────────────────────────────────────
  if (loadingRecord) {
    return (
      <div className="loading-screen">
        <div className="spinner" />
      </div>
    );
  }

  return (
    <div className="page">
      <div className="page-header">
        <div className="page-header-left">
          <button className="back-btn" onClick={() => navigate(-1)}>
            ← Back
          </button>
          <h1>{isEdit ? "Edit Record" : "Add Record"}</h1>
        </div>
      </div>

      <form onSubmit={handleSubmit} noValidate>
        <div className="add-edit-form">
          {/* ── Basic info ── */}
          <div className="form-section">
            <div className="form-section-title">Basic Info</div>
            <div className="form-row" style={{ marginBottom: "1rem" }}>
              <div className="form-group">
                <label htmlFor="field-artist">Artist *</label>
                <input
                  id="field-artist"
                  type="text"
                  value={artist}
                  onChange={(e) => setArtist(e.target.value)}
                  placeholder="Artist name"
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="field-title">Title *</label>
                <input
                  id="field-title"
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Album / record title"
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="field-year">Year</label>
                <input
                  id="field-year"
                  type="number"
                  value={year}
                  onChange={(e) => setYear(e.target.value)}
                  placeholder="e.g. 1973"
                  min="1900"
                  max="2099"
                />
              </div>
            </div>
            <div className="form-row" style={{ marginBottom: "1rem" }}>
              <div className="form-group">
                <label htmlFor="field-label">Label</label>
                <input
                  id="field-label"
                  type="text"
                  value={label}
                  onChange={(e) => setLabel(e.target.value)}
                  placeholder="Record label"
                />
              </div>
              <div className="form-group">
                <label htmlFor="field-genre">Genre</label>
                <input
                  id="field-genre"
                  type="text"
                  value={genre}
                  onChange={(e) => setGenre(e.target.value)}
                  placeholder="e.g. Rock"
                />
              </div>
              <div className="form-group">
                <label htmlFor="field-duration">Duration</label>
                <input
                  id="field-duration"
                  type="text"
                  value={duration}
                  onChange={(e) => setDuration(e.target.value)}
                  placeholder="e.g. 42:30"
                />
              </div>
            </div>
          </div>

          {/* ── Format & condition ── */}
          <div className="form-section">
            <div className="form-section-title">Format & Condition</div>
            <div className="form-row" style={{ marginBottom: "1rem" }}>
              <div className="form-group">
                <label htmlFor="field-format">Format</label>
                <select
                  id="field-format"
                  value={format}
                  onChange={(e) => setFormat(e.target.value as Format | "")}
                >
                  <option value="">Select…</option>
                  {FORMATS.map((f) => (
                    <option key={f} value={f}>
                      {f}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="field-speed">Speed (RPM)</label>
                <select
                  id="field-speed"
                  value={speed}
                  onChange={(e) => setSpeed(e.target.value as Speed | "")}
                >
                  <option value="">Select…</option>
                  {SPEEDS.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="field-disc-cond">Disc Condition</label>
                <select
                  id="field-disc-cond"
                  value={discCondition}
                  onChange={(e) =>
                    setDiscCondition(e.target.value as Grade | "")
                  }
                >
                  <option value="">Select…</option>
                  {GRADES.map((g) => (
                    <option key={g} value={g}>
                      {g}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="field-sleeve-cond">Sleeve Condition</label>
                <select
                  id="field-sleeve-cond"
                  value={sleeveCondition}
                  onChange={(e) =>
                    setSleeveCondition(e.target.value as Grade | "")
                  }
                >
                  <option value="">Select…</option>
                  {GRADES.map((g) => (
                    <option key={g} value={g}>
                      {g}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          {/* ── Ownership ── */}
          <div className="form-section">
            <div className="form-section-title">Ownership</div>
            <div className="form-row" style={{ marginBottom: "1rem" }}>
              <div className="form-group">
                <label htmlFor="field-owner">Owner</label>
                <select
                  id="field-owner"
                  value={owner}
                  onChange={(e) => setOwner(e.target.value as Owner)}
                >
                  {OWNERS.map((o) => (
                    <option key={o} value={o}>
                      {o}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="field-disc-count">Number of Discs</label>
                <select
                  id="field-disc-count"
                  value={discCount}
                  onChange={(e) => setDiscCount(parseInt(e.target.value, 10))}
                >
                  {[1, 2, 3, 4].map((n) => (
                    <option key={n} value={n}>{n}</option>
                  ))}
                </select>
              </div>
              <div className="form-group" style={{ justifyContent: "flex-end" }}>
                <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", paddingTop: "1.5rem" }}>
                  <label className="checkbox-group">
                    <input
                      type="checkbox"
                      checked={outerSleeveOnly}
                      onChange={(e) => setOuterSleeveOnly(e.target.checked)}
                    />
                    Outer sleeve only
                  </label>
                </div>
              </div>
            </div>
          </div>

          {/* ── Notes ── */}
          <div className="form-section">
            <div className="form-section-title">Notes</div>
            <div className="form-group">
              <textarea
                id="field-notes"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Any additional notes…"
                rows={3}
              />
            </div>
          </div>

          {/* ── Photos ── */}
          <div className="form-section">
            <div className="form-section-title">Photos</div>

            {/* Sleeve slots */}
            <div style={{ marginBottom: "1rem" }}>
              <div className="disc-slots-title" style={{ marginBottom: "0.5rem" }}>
                Sleeve
              </div>
              <div className="photo-slots-grid">
                {sleeveTypes.map(({ type, label: slotLabel, wide }) => {
                  const key = slotKey(type);
                  return (
                    <PhotoSlot
                      key={key}
                      label={slotLabel}
                      existingUrl={getExistingUrl(key)}
                      hasExisting={hasExistingPhoto(key)}
                      onFile={(file) => setSlotFile(key, file)}
                      wide={wide}
                    />
                  );
                })}
              </div>
            </div>

            {/* Disc slots */}
            <div>
              {discNumbers.map((discNum) => (
                <div key={discNum} className="disc-slots-group">
                  <div className="disc-slots-header">
                    <span className="disc-slots-title">
                      {discNumbers.length > 1 ? `Disc ${discNum}` : "Disc"}
                    </span>
                  </div>
                  <div className="photo-slots-grid">
                    {(["disc_front", "disc_back"] as PhotoType[]).map((discType) => {
                      const key = slotKey(discType, discNum);
                      const label = discType === "disc_front" ? "Side A" : "Side B";
                      return (
                        <PhotoSlot
                          key={key}
                          label={label}
                          existingUrl={getExistingUrl(key)}
                          hasExisting={hasExistingPhoto(key)}
                          onFile={(file) => setSlotFile(key, file)}
                        />
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {error && <div className="error-message">{error}</div>}

          <div className="form-actions">
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => navigate(-1)}
              disabled={submitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={submitting}
            >
              {submitting ? (
                <>
                  <span className="spinner-sm" />
                  Saving…
                </>
              ) : isEdit ? (
                "Save Changes"
              ) : (
                "Add Record"
              )}
            </button>
          </div>
        </div>
      </form>
    </div>
  );
}
