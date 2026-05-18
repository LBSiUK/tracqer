from __future__ import annotations

import io
import uuid
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from PIL import Image, ImageOps
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..crypto import encrypt, verify_token
from ..database import get_db
from ..dependencies import require_auth
from ..models import Photo, PhotoTypeEnum, Record
from ..schemas import PhotoResponse

router = APIRouter(prefix="/records", tags=["photos"])

_MAX_PHOTO_BYTES = 20 * 1024 * 1024  # 20 MB

_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp", "image/gif"}

_SLEEVE_TYPES = {
    PhotoTypeEnum.sleeve_front,
    PhotoTypeEnum.sleeve_back,
    PhotoTypeEnum.sleeve_inner,
    PhotoTypeEnum.inner_sleeve_front,
    PhotoTypeEnum.inner_sleeve_back,
}
_DISC_TYPES = {PhotoTypeEnum.disc_front, PhotoTypeEnum.disc_back}

_THUMB_SIZES = (240, 320, 640, 1280)

SizeParam = Literal["original", "240", "320", "640", "1280"]


def _photo_dir(photo_id: uuid.UUID) -> Path:
    return Path(settings.photos_dir) / str(photo_id)


def _original_path(photo_id: uuid.UUID) -> Path:
    return _photo_dir(photo_id) / "original"


def _thumb_path(photo_id: uuid.UUID, size: int) -> Path:
    return _photo_dir(photo_id) / f"{size}.jpg"


def _generate_thumbnails(photo_id: uuid.UUID, contents: bytes) -> None:
    """Write original bytes and JPEG thumbnails at 240, 320, 640, 1280px."""
    d = _photo_dir(photo_id)
    d.mkdir(parents=True, exist_ok=True)

    # Save full-resolution original
    _original_path(photo_id).write_bytes(contents)

    # Generate thumbnails
    img = Image.open(io.BytesIO(contents))
    img = ImageOps.exif_transpose(img)  # correct EXIF rotation
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")

    for size in _THUMB_SIZES:
        thumb = img.copy()
        thumb.thumbnail((size, size), Image.LANCZOS)
        buf = io.BytesIO()
        thumb.save(buf, format="JPEG", quality=85, optimize=True)
        _thumb_path(photo_id, size).write_bytes(buf.getvalue())


def _delete_photo_files(photo_id: uuid.UUID) -> None:
    d = _photo_dir(photo_id)
    if d.exists():
        for f in d.iterdir():
            f.unlink(missing_ok=True)
        d.rmdir()


async def attach_photo(
    db:          AsyncSession,
    record_id:   uuid.UUID,
    photo_type:  PhotoTypeEnum,
    disc_number: int | None,
    file:        UploadFile,
) -> Photo:
    """
    Validate, write to disk (original + thumbnails), and insert a Photo row.
    Replaces any existing photo in the same slot.
    Used by both the dedicated photo endpoints and the combined record-upload endpoint.
    """
    if file.content_type not in _ALLOWED_MIME:
        raise HTTPException(status_code=415, detail=f"Unsupported type for {photo_type.value}: {file.content_type}")

    contents = await file.read()
    if len(contents) > _MAX_PHOTO_BYTES:
        raise HTTPException(status_code=413, detail=f"{photo_type.value} exceeds 20 MB")

    # Replace any existing photo in this slot
    existing = (await db.execute(
        select(Photo).where(
            Photo.record_id   == record_id,
            Photo.photo_type  == photo_type,
            Photo.disc_number == disc_number,
        )
    )).scalar_one_or_none()
    if existing is not None:
        _delete_photo_files(existing.id)
        await db.delete(existing)

    photo = Photo(
        record_id=record_id,
        photo_type=photo_type,
        disc_number=disc_number,
        mime_type=file.content_type,
        file_size=len(contents),
    )
    db.add(photo)
    await db.flush()  # populate photo.id before writing files
    _generate_thumbnails(photo.id, contents)
    return photo


def _resolve_size_path(photo_id: uuid.UUID, size: SizeParam) -> Path:
    if size == "original":
        return _original_path(photo_id)
    return _thumb_path(photo_id, int(size))


def _photo_url(record_id: uuid.UUID, photo: Photo) -> str:
    if photo.photo_type in _DISC_TYPES:
        return f"/api/v1/records/{record_id}/photos/{photo.photo_type.value}/{photo.disc_number}"
    return f"/api/v1/records/{record_id}/photos/{photo.photo_type.value}"


def _serialize_photo(record_id: uuid.UUID, photo: Photo) -> dict:
    resp = PhotoResponse.model_validate(photo)
    resp.url = _photo_url(record_id, photo)
    return resp.model_dump(mode="json")


async def _get_record_or_404(db: AsyncSession, record_id: uuid.UUID) -> Record:
    record = await db.get(Record, record_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Record not found")
    return record


async def _get_photo_or_404(
    db:          AsyncSession,
    record_id:   uuid.UUID,
    photo_type:  PhotoTypeEnum,
    disc_number: int | None,
) -> Photo:
    stmt = select(Photo).where(
        Photo.record_id   == record_id,
        Photo.photo_type  == photo_type,
        Photo.disc_number == disc_number,
    )
    result = await db.execute(stmt)
    photo = result.scalar_one_or_none()
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")
    return photo


async def _save_photo(
    file:        UploadFile,
    record_id:   uuid.UUID,
    photo_type:  PhotoTypeEnum,
    disc_number: int | None,
    key:         bytes,
    db:          AsyncSession,
) -> JSONResponse:
    await _get_record_or_404(db, record_id)
    photo = await attach_photo(db, record_id, photo_type, disc_number, file)
    await db.commit()
    await db.refresh(photo)
    return JSONResponse(
        content=encrypt(key, _serialize_photo(record_id, photo)),
        status_code=201,
    )


# ---------------------
# List all photos for a record
# ---------------------

@router.get("/{record_id}/photos")
async def list_photos(
    record_id: uuid.UUID,
    key: bytes        = Depends(require_auth),
    db:  AsyncSession = Depends(get_db),
) -> JSONResponse:
    await _get_record_or_404(db, record_id)
    result = await db.execute(select(Photo).where(Photo.record_id == record_id))
    photos = result.scalars().all()
    payload = [_serialize_photo(record_id, p) for p in photos]
    return JSONResponse(content=encrypt(key, {"photos": payload}))


# ---------------------
# Sleeve photos  (sleeve_front | sleeve_back | sleeve_inner | inner_sleeve_*)
# ---------------------

@router.get("/{record_id}/photos/{photo_type}")
async def get_sleeve_photo(
    record_id:  uuid.UUID,
    photo_type: PhotoTypeEnum,
    token:      str           = Query(...),
    size:       SizeParam     = Query("640"),
    db:         AsyncSession  = Depends(get_db),
) -> FileResponse:
    if photo_type not in _SLEEVE_TYPES:
        raise HTTPException(status_code=400, detail="Use /photos/{type}/{disc_number} for disc photos")
    if not verify_token(token):
        raise HTTPException(status_code=401, detail="Invalid token")

    photo = await _get_photo_or_404(db, record_id, photo_type, None)
    path = _resolve_size_path(photo.id, size)
    if not path.exists():
        # Fall back to original if requested size doesn't exist yet
        path = _original_path(photo.id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Photo file missing")
    media_type = "image/jpeg" if size != "original" else photo.mime_type
    return FileResponse(path, media_type=media_type)


@router.post("/{record_id}/photos/{photo_type}", status_code=201)
async def upload_sleeve_photo(
    record_id:  uuid.UUID,
    photo_type: PhotoTypeEnum,
    file:       UploadFile,
    key:        bytes         = Depends(require_auth),
    db:         AsyncSession  = Depends(get_db),
) -> JSONResponse:
    if photo_type not in _SLEEVE_TYPES:
        raise HTTPException(status_code=400, detail="Use /photos/{type}/{disc_number} for disc photos")
    return await _save_photo(file, record_id, photo_type, None, key, db)


@router.delete("/{record_id}/photos/{photo_type}", status_code=204)
async def delete_sleeve_photo(
    record_id:  uuid.UUID,
    photo_type: PhotoTypeEnum,
    key:        bytes         = Depends(require_auth),
    db:         AsyncSession  = Depends(get_db),
) -> None:
    if photo_type not in _SLEEVE_TYPES:
        raise HTTPException(status_code=400, detail="Use /photos/{type}/{disc_number} for disc photos")
    photo = await _get_photo_or_404(db, record_id, photo_type, None)
    _delete_photo_files(photo.id)
    await db.delete(photo)
    await db.commit()


# ---------------------
# Disc photos  (disc_front | disc_back) + disc_number
# ---------------------

@router.get("/{record_id}/photos/{photo_type}/{disc_number}")
async def get_disc_photo(
    record_id:   uuid.UUID,
    photo_type:  PhotoTypeEnum,
    disc_number: int,
    token:       str          = Query(...),
    size:        SizeParam    = Query("640"),
    db:          AsyncSession = Depends(get_db),
) -> FileResponse:
    if photo_type not in _DISC_TYPES:
        raise HTTPException(status_code=400, detail="Use /photos/{type} for sleeve photos")
    if disc_number < 1:
        raise HTTPException(status_code=400, detail="disc_number must be >= 1")
    if not verify_token(token):
        raise HTTPException(status_code=401, detail="Invalid token")

    photo = await _get_photo_or_404(db, record_id, photo_type, disc_number)
    path = _resolve_size_path(photo.id, size)
    if not path.exists():
        path = _original_path(photo.id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Photo file missing")
    media_type = "image/jpeg" if size != "original" else photo.mime_type
    return FileResponse(path, media_type=media_type)


@router.post("/{record_id}/photos/{photo_type}/{disc_number}", status_code=201)
async def upload_disc_photo(
    record_id:   uuid.UUID,
    photo_type:  PhotoTypeEnum,
    disc_number: int,
    file:        UploadFile,
    key:         bytes        = Depends(require_auth),
    db:          AsyncSession = Depends(get_db),
) -> JSONResponse:
    if photo_type not in _DISC_TYPES:
        raise HTTPException(status_code=400, detail="Use /photos/{type} for sleeve photos")
    if disc_number < 1:
        raise HTTPException(status_code=400, detail="disc_number must be >= 1")
    return await _save_photo(file, record_id, photo_type, disc_number, key, db)


@router.delete("/{record_id}/photos/{photo_type}/{disc_number}", status_code=204)
async def delete_disc_photo(
    record_id:   uuid.UUID,
    photo_type:  PhotoTypeEnum,
    disc_number: int,
    key:         bytes        = Depends(require_auth),
    db:          AsyncSession = Depends(get_db),
) -> None:
    if photo_type not in _DISC_TYPES:
        raise HTTPException(status_code=400, detail="Use /photos/{type} for sleeve photos")
    if disc_number < 1:
        raise HTTPException(status_code=400, detail="disc_number must be >= 1")
    photo = await _get_photo_or_404(db, record_id, photo_type, disc_number)
    _delete_photo_files(photo.id)
    await db.delete(photo)
    await db.commit()
