import { useState, useEffect, useCallback, useRef } from "react";
import { Link } from "react-router-dom";
import { useAuth, useRequireAuth } from "../lib/auth";
import type { VinylRecord, RecordFilters } from "../lib/types";
import RecordCard from "../components/RecordCard";
import FilterBar, { type FilterValues } from "../components/FilterBar";

const PAGE_SIZE = 50;

const defaultFilters: FilterValues = {
  search: "",
  genre: "",
  format: "",
  owner: "",
  disc_condition: "",
  sleeve_condition: "",
};

export default function Collection() {
  const { api } = useRequireAuth();
  const { logout } = useAuth();

  const [filters, setFilters] = useState<FilterValues>(defaultFilters);
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [records, setRecords] = useState<VinylRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Debounce search
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    searchTimer.current = setTimeout(() => {
      setDebouncedSearch(filters.search);
      setPage(1);
    }, 400);
    return () => {
      if (searchTimer.current) clearTimeout(searchTimer.current);
    };
  }, [filters.search]);

  const handleFiltersChange = useCallback(
    (newFilters: FilterValues) => {
      setFilters(newFilters);
      // Reset page when anything except the (debounced) search changes
      if (
        newFilters.genre !== filters.genre ||
        newFilters.format !== filters.format ||
        newFilters.owner !== filters.owner ||
        newFilters.disc_condition !== filters.disc_condition ||
        newFilters.sleeve_condition !== filters.sleeve_condition
      ) {
        setPage(1);
      }
    },
    [filters]
  );

  const fetchRecords = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const apiFilters: RecordFilters = { page, limit: PAGE_SIZE };
      if (debouncedSearch) apiFilters.search = debouncedSearch;
      if (filters.genre) apiFilters.genre = filters.genre;
      if (filters.format) apiFilters.format = filters.format;
      if (filters.owner) apiFilters.owner = filters.owner;
      if (filters.disc_condition)
        apiFilters.disc_condition = filters.disc_condition;
      if (filters.sleeve_condition)
        apiFilters.sleeve_condition = filters.sleeve_condition;

      const result = await api.listRecords(apiFilters);
      setRecords(result.records);
      setTotal(result.total);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to load records."
      );
    } finally {
      setLoading(false);
    }
  }, [api, page, debouncedSearch, filters]);

  useEffect(() => {
    fetchRecords();
  }, [fetchRecords]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="page">
      <div className="collection-topbar">
        <div className="collection-title-area">
          <h1>Collection</h1>
          {!loading && (
            <span className="collection-count">
              {total} record{total !== 1 ? "s" : ""}
            </span>
          )}
        </div>
        <div style={{ display: "flex", gap: "0.75rem", alignItems: "center" }}>
          <button className="btn btn-ghost btn-sm" onClick={logout}>
            Sign out
          </button>
          <Link to="/records/new" className="btn btn-primary">
            + Add Record
          </Link>
        </div>
      </div>

      <FilterBar values={filters} onChange={handleFiltersChange} />

      {error && (
        <div className="error-message" style={{ marginBottom: "1rem" }}>
          {error}{" "}
          <button
            className="btn btn-ghost btn-sm"
            onClick={fetchRecords}
            style={{ marginLeft: "0.5rem" }}
          >
            Retry
          </button>
        </div>
      )}

      {loading ? (
        <div
          style={{
            display: "flex",
            justifyContent: "center",
            padding: "3rem 0",
          }}
        >
          <div className="spinner" />
        </div>
      ) : records.length === 0 ? (
        <div className="empty-state">
          <svg
            width="64"
            height="64"
            viewBox="0 0 48 48"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
            aria-hidden="true"
          >
            <circle cx="24" cy="24" r="20" />
            <circle cx="24" cy="24" r="12" />
            <circle cx="24" cy="24" r="5" />
          </svg>
          <p>No records found.</p>
          {(debouncedSearch ||
            filters.genre ||
            filters.format ||
            filters.owner) && (
            <button
              className="btn btn-ghost btn-sm"
              onClick={() => {
                setFilters(defaultFilters);
                setPage(1);
              }}
            >
              Clear filters
            </button>
          )}
        </div>
      ) : (
        <>
          <div className="card-grid">
            {records.map((record) => (
              <RecordCard key={record.id} record={record} api={api} />
            ))}
          </div>

          {totalPages > 1 && (
            <div className="pagination">
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
              >
                Previous
              </button>
              <span className="pagination-info">
                Page {page} of {totalPages}
              </span>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={page >= totalPages}
              >
                Next
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
