# Tracqer

Personal record-tracking system across multiple clients.

## Layout

- `api/`     — FastAPI backend (Python). All responses encrypted at the app
               layer with AES-256-CBC envelopes. See `api/crypto.py`.
- `db/`      — PostgreSQL schema and migrations.
- `web/`     — TypeScript/React dashboard (Vite). `cd web && npm install && npm run dev`.
- `ios/`     — SwiftUI client targeting iOS 15+ (modern Tracqer build). See `ios/SETUP.md`.
- `ios-6/`   — Objective-C client for jailbroken iOS 6.1.3 devices (iPod touch, iPad 4).
               Built in Xcode 5.1.1 with sideloaded iOS 6.1 SDK on a Mountain Lion VM.
               v1.0 supports browsing, photo viewing (read-only, with pinch-to-zoom),
               and swipe-to-delete. **Photo upload is not yet implemented and may be
               added in a future release.** Add/Edit forms are also pending.
- `photos/`  — Runtime photo storage (gitignored). Created by the API on first run.

## Quickstart

1. Copy `.env.example` to `.env` and edit `DATABASE_URL` + `PASSWORD`.
2. `python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`
3. Run migrations (see `db/`), then `uvicorn api.main:app --host 0.0.0.0 --port 8000`.
4. Pick a client (`web/`, `ios/`, or `ios-6/`) and follow its README/SETUP.

## Releases

- `api-v1.0`    — backend
- `ios-26-v1.0` — SwiftUI client
- `ios-6-v1.0`  — iOS 6.1.3 client (browse + view photos + delete)
