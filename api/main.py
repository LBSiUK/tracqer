import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select

from .config import settings
from .crypto import derive_token, init_key
from .database import AsyncSessionLocal, engine
from .models import Auth
from .routers import auth, photos, records

logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(name)s  %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Derive AES key from password and cache it in memory
    key = init_key(settings.password)
    token = derive_token(key)

    # Ensure photos directory exists
    Path(settings.photos_dir).mkdir(parents=True, exist_ok=True)

    # Upsert the derived token into the auth table
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Auth).where(Auth.id == 1))
        auth_row = result.scalar_one_or_none()
        if auth_row is None:
            session.add(Auth(id=1, token=token))
        else:
            auth_row.token = token
        await session.commit()

    logger.info("Vinyl Collection API is ready")
    yield

    await engine.dispose()


app = FastAPI(
    title="Vinyl Collection API",
    version="1.0.0",
    lifespan=lifespan,
    # Disable docs in production if desired
    # docs_url=None, redoc_url=None,
)

# Allow all origins — this runs on a private home network.
# Cannot use allow_credentials=True with allow_origins=["*"];
# the Bearer token in the Authorization header is our auth mechanism anyway.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,    prefix="/api/v1")
app.include_router(records.router, prefix="/api/v1")
app.include_router(photos.router,  prefix="/api/v1")


@app.get("/ping", tags=["health"])
async def ping():
    """Unencrypted health check — safe to call before the client has a key."""
    return {"status": "ok"}


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception on %s %s", request.method, request.url)
    return JSONResponse(status_code=500, content={"error": "internal_server_error"})


# Serve the built web app as static files.
# The dist/ directory is produced by `npm run build` inside web/.
# All unmatched routes return index.html so React Router handles them client-side.
_dist = Path(__file__).parent.parent / "web" / "dist"
if _dist.exists():
    app.mount("/assets", StaticFiles(directory=_dist / "assets"), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    async def serve_spa(_: Request, full_path: str) -> FileResponse:
        return FileResponse(_dist / "index.html")
