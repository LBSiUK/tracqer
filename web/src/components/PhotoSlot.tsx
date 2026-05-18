import { useRef, useState, useEffect } from "react";

interface PhotoSlotProps {
  label: string;
  existingUrl?: string;
  onFile: (file: File | null) => void;
  /** Whether the slot currently has an existing photo that can be deleted */
  hasExisting?: boolean;
  /** 2:1 wide slot for gatefold inner spread */
  wide?: boolean;
}

const ACCEPTED = "image/jpeg,image/png,image/webp,image/gif";

export default function PhotoSlot({
  label,
  existingUrl,
  onFile,
  hasExisting = false,
  wide = false,
}: PhotoSlotProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [removed, setRemoved] = useState(false);

  // When existingUrl changes (e.g., parent resets), sync state
  useEffect(() => {
    setPreview(null);
    setRemoved(false);
  }, [existingUrl]);

  const handleClick = () => {
    inputRef.current?.click();
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    if (!file) return;

    const objectUrl = URL.createObjectURL(file);
    setPreview(objectUrl);
    setRemoved(false);
    onFile(file);

    // Reset input so same file can be re-selected
    e.target.value = "";
  };

  const handleRemove = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (preview) {
      URL.revokeObjectURL(preview);
    }
    setPreview(null);
    setRemoved(true);
    onFile(null);
  };

  const displayUrl = preview ?? (removed ? null : existingUrl ?? null);
  const showRemove = displayUrl !== null || (hasExisting && !removed);

  return (
    <div className={wide ? "photo-slot photo-slot--wide" : "photo-slot"}>
      <div
        className={wide ? "photo-slot-inner photo-slot-inner--wide" : "photo-slot-inner"}
        onClick={handleClick}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") handleClick();
        }}
        aria-label={`Upload ${label}`}
        title={displayUrl ? `Replace ${label}` : `Upload ${label}`}
      >
        {displayUrl ? (
          <img src={displayUrl} alt={label} />
        ) : (
          <div className="photo-slot-placeholder">
            <svg
              width="28"
              height="28"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              aria-hidden="true"
            >
              <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
              <circle cx="8.5" cy="8.5" r="1.5" />
              <polyline points="21 15 16 10 5 21" />
            </svg>
            <span>{label}</span>
          </div>
        )}

        {showRemove && (
          <button
            className="photo-slot-remove"
            onClick={handleRemove}
            type="button"
            aria-label={`Remove ${label}`}
            title={`Remove ${label}`}
          >
            ✕
          </button>
        )}
      </div>
      <div className="photo-slot-label">{label}</div>

      <input
        ref={inputRef}
        type="file"
        accept={ACCEPTED}
        onChange={handleChange}
        style={{ display: "none" }}
        aria-hidden="true"
      />
    </div>
  );
}
