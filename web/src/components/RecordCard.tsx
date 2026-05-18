import { Link } from "react-router-dom";
import type { VinylRecord } from "../lib/types";
import { VinylAPI } from "../lib/api";

interface RecordCardProps {
  record: VinylRecord;
  api: VinylAPI;
}

function VinylPlaceholderSVG() {
  return (
    <div className="vinyl-placeholder">
      <svg
        width="80"
        height="80"
        viewBox="0 0 80 80"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <circle cx="40" cy="40" r="38" stroke="#3a3a3f" strokeWidth="2" />
        <circle cx="40" cy="40" r="30" stroke="#3a3a3f" strokeWidth="1.5" />
        <circle cx="40" cy="40" r="22" stroke="#3a3a3f" strokeWidth="1.5" />
        <circle cx="40" cy="40" r="14" stroke="#3a3a3f" strokeWidth="1.5" />
        <circle cx="40" cy="40" r="7" fill="#3a3a3f" />
        <circle cx="40" cy="40" r="3" fill="#1c1c20" />
        {/* Grooves highlight */}
        <path
          d="M 40 2 A 38 38 0 0 1 78 40"
          stroke="#4a4a50"
          strokeWidth="1"
          fill="none"
        />
        <path
          d="M 40 10 A 30 30 0 0 1 70 40"
          stroke="#4a4a50"
          strokeWidth="0.8"
          fill="none"
        />
      </svg>
    </div>
  );
}

function OwnerBadge({ owner }: { owner: string }) {
  const cls =
    owner === "me"
      ? "badge-owner-me"
      : owner === "dad"
      ? "badge-owner-dad"
      : "badge-owner-shared";
  return <span className={`badge ${cls}`}>{owner}</span>;
}

export default function RecordCard({ record, api }: RecordCardProps) {
  const sleeveFront = record.photos.find((p) => p.photo_type === "sleeve_front");

  return (
    <Link to={`/records/${record.id}`} className="card">
      <div className="card-image">
        {sleeveFront ? (
          <img
            src={api.photoUrl(record.id, "sleeve_front")}
            alt={`${record.artist} - ${record.title}`}
            loading="lazy"
          />
        ) : (
          <VinylPlaceholderSVG />
        )}
      </div>
      <div className="card-body">
        <div className="card-artist">{record.artist}</div>
        <div className="card-title">{record.title}</div>
        {record.year && <div className="card-year">{record.year}</div>}
        <div className="card-badges">
          {record.format && (
            <span className="badge badge-format">{record.format}</span>
          )}
          {record.disc_condition && (
            <span className="badge badge-grade">{record.disc_condition}</span>
          )}
          <OwnerBadge owner={record.owner} />
        </div>
      </div>
    </Link>
  );
}
