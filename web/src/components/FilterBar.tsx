import type { Format, Grade, Owner } from "../lib/types";

export interface FilterValues {
  search: string;
  genre: string;
  format: Format | "";
  owner: Owner | "";
  disc_condition: Grade | "";
  sleeve_condition: Grade | "";
}

interface FilterBarProps {
  values: FilterValues;
  onChange: (values: FilterValues) => void;
}

const FORMAT_OPTIONS: Format[] = ['12" LP', '10" LP', '12" single', '7" single', 'Other'];
const GRADE_OPTIONS: Grade[] = ["M", "NM", "VG+", "VG", "G+", "G", "F", "P"];
const OWNER_OPTIONS: Owner[] = ["me", "dad", "shared"];

export default function FilterBar({ values, onChange }: FilterBarProps) {
  const set = <K extends keyof FilterValues>(key: K, val: FilterValues[K]) => {
    onChange({ ...values, [key]: val });
  };

  const hasFilters =
    values.genre !== "" ||
    values.format !== "" ||
    values.owner !== "" ||
    values.disc_condition !== "" ||
    values.sleeve_condition !== "";

  const clearFilters = () => {
    onChange({
      search: values.search,
      genre: "",
      format: "",
      owner: "",
      disc_condition: "",
      sleeve_condition: "",
    });
  };

  return (
    <div className="filter-bar">
      <div className="filter-search">
        <input
          type="search"
          placeholder="Search records, artists…"
          value={values.search}
          onChange={(e) => set("search", e.target.value)}
          aria-label="Search"
        />
      </div>
      <div className="filter-row">
        <div className="filter-field">
          <label htmlFor="filter-genre">Genre</label>
          <input
            id="filter-genre"
            type="text"
            placeholder="Any"
            value={values.genre}
            onChange={(e) => set("genre", e.target.value)}
          />
        </div>

        <div className="filter-field">
          <label htmlFor="filter-format">Format</label>
          <select
            id="filter-format"
            value={values.format}
            onChange={(e) => set("format", e.target.value as Format | "")}
          >
            <option value="">Any</option>
            {FORMAT_OPTIONS.map((f) => (
              <option key={f} value={f}>
                {f}
              </option>
            ))}
          </select>
        </div>

        <div className="filter-field">
          <label htmlFor="filter-owner">Owner</label>
          <select
            id="filter-owner"
            value={values.owner}
            onChange={(e) => set("owner", e.target.value as Owner | "")}
          >
            <option value="">Any</option>
            {OWNER_OPTIONS.map((o) => (
              <option key={o} value={o}>
                {o}
              </option>
            ))}
          </select>
        </div>

        <div className="filter-field">
          <label htmlFor="filter-disc">Disc Condition</label>
          <select
            id="filter-disc"
            value={values.disc_condition}
            onChange={(e) =>
              set("disc_condition", e.target.value as Grade | "")
            }
          >
            <option value="">Any</option>
            {GRADE_OPTIONS.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </select>
        </div>

        <div className="filter-field">
          <label htmlFor="filter-sleeve">Sleeve Condition</label>
          <select
            id="filter-sleeve"
            value={values.sleeve_condition}
            onChange={(e) =>
              set("sleeve_condition", e.target.value as Grade | "")
            }
          >
            <option value="">Any</option>
            {GRADE_OPTIONS.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </select>
        </div>

        {hasFilters && (
          <button
            type="button"
            className="btn btn-ghost btn-sm filter-clear"
            onClick={clearFilters}
          >
            Clear filters
          </button>
        )}
      </div>
    </div>
  );
}
