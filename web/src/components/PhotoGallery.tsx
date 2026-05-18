import type { Photo } from "../lib/types";
import { VinylAPI } from "../lib/api";

interface PhotoGalleryProps {
  photos: Photo[];
  api: VinylAPI;
  recordId: string;
}

function PhotoItem({
  photo,
  api,
  recordId,
  label,
  wide = false,
}: {
  photo: Photo;
  api: VinylAPI;
  recordId: string;
  label: string;
  wide?: boolean;
}) {
  const url =
    photo.disc_number !== null
      ? api.photoUrl(recordId, photo.photo_type, photo.disc_number)
      : api.photoUrl(recordId, photo.photo_type);

  const fullUrl =
    photo.disc_number !== null
      ? api.photoUrl(recordId, photo.photo_type, photo.disc_number, "original")
      : api.photoUrl(recordId, photo.photo_type, undefined, "original");

  const handleClick = () => {
    window.open(fullUrl, "_blank", "noopener,noreferrer");
  };

  return (
    <div className={wide ? "photo-item photo-item--wide" : "photo-item"}>
      <img
        src={url}
        alt={label}
        className={wide ? "photo-thumb photo-thumb--wide" : "photo-thumb"}
        onClick={handleClick}
        title={`Click to open full size: ${label}`}
        loading="lazy"
      />
      <div className="photo-label">{label}</div>
    </div>
  );
}

function sleeveLabel(type: string): string {
  switch (type) {
    case "sleeve_front":       return "Front";
    case "sleeve_back":        return "Back";
    case "sleeve_inner":       return "Gatefold";
    case "inner_sleeve_front": return "Inner Sleeve (Front)";
    case "inner_sleeve_back":  return "Inner Sleeve (Back)";
    default:                   return type;
  }
}

function discLabel(type: string): string {
  return type === "disc_front" ? "Side A" : "Side B";
}

export default function PhotoGallery({
  photos,
  api,
  recordId,
}: PhotoGalleryProps) {
  const sleevePhotos = photos.filter((p) =>
    ["sleeve_front", "sleeve_back", "sleeve_inner", "inner_sleeve_front", "inner_sleeve_back"].includes(p.photo_type)
  );

  const discPhotos = photos.filter((p) =>
    ["disc_front", "disc_back"].includes(p.photo_type)
  );

  // Group disc photos by disc number
  const discNumbers = Array.from(
    new Set(discPhotos.map((p) => p.disc_number ?? 1))
  ).sort((a, b) => a - b);

  const hasAny = photos.length > 0;

  if (!hasAny) {
    return (
      <p style={{ color: "var(--text-muted)", fontSize: "0.875rem" }}>
        No photos yet.
      </p>
    );
  }

  return (
    <div>
      {sleevePhotos.length > 0 && (
        <div style={{ marginBottom: "1.25rem" }}>
          <div className="detail-section-title">Sleeve</div>
          <div className="photo-row">
            {sleevePhotos.map((photo) => (
              <PhotoItem
                key={photo.id}
                photo={photo}
                api={api}
                recordId={recordId}
                label={sleeveLabel(photo.photo_type)}
                wide={photo.photo_type === "sleeve_inner"}
              />
            ))}
          </div>
        </div>
      )}

      {discNumbers.map((discNum) => {
        const front = discPhotos.find(
          (p) => p.photo_type === "disc_front" && p.disc_number === discNum
        );
        const back = discPhotos.find(
          (p) => p.photo_type === "disc_back" && p.disc_number === discNum
        );

        return (
          <div key={discNum} className="disc-group">
            <div className="disc-group-title">
              {discNumbers.length > 1 ? `Disc ${discNum}` : "Disc"}
            </div>
            <div className="photo-row">
              {front && (
                <PhotoItem
                  photo={front}
                  api={api}
                  recordId={recordId}
                  label={discLabel("disc_front")}
                />
              )}
              {back && (
                <PhotoItem
                  photo={back}
                  api={api}
                  recordId={recordId}
                  label={discLabel("disc_back")}
                />
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
