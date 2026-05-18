from __future__ import annotations

import json
import uuid
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from ..crypto import decrypt, encrypt, get_key
from ..database import get_db
from ..dependencies import decrypt_body, require_auth
from ..models import FormatEnum, GradeEnum, OwnerEnum, PhotoTypeEnum, Record, SpeedEnum
from ..routers.photos import _photo_url, attach_photo
from ..schemas import PhotoResponse, RecordCreate, RecordResponse, RecordUpdate

router = APIRouter(prefix="/records", tags=["records"])

_SORT_COLUMNS = {
    "artist":     Record.artist,
    "title":      Record.title,
    "year":       Record.year,
    "created_at": Record.created_at,
}

MAX_LIMIT = 200


def _serialize(record: Record) -> dict:
    resp = RecordResponse.model_validate(record)
    resp.photos = [
        PhotoResponse.model_validate(p) for p in record.photos
    ]
    data = resp.model_dump(mode="json")
    # Inject URL into each photo
    for i, photo in enumerate(record.photos):
        data["photos"][i]["url"] = _photo_url(record.id, photo)
    return data


# ---------------------
# List
# ---------------------

@router.get("")
async def list_records(
    search:           str | None               = Query(default=None),
    artist:           str | None               = Query(default=None),
    genre:            str | None               = Query(default=None),
    owner:            OwnerEnum | None         = Query(default=None),
    format:           FormatEnum | None        = Query(default=None),
    disc_condition:   GradeEnum | None         = Query(default=None),
    sleeve_condition: GradeEnum | None         = Query(default=None),
    wishlist:         bool | None              = Query(default=None),
    page:             int                      = Query(default=1, ge=1),
    limit:            int                      = Query(default=50, ge=1, le=MAX_LIMIT),
    sort:             str                      = Query(default="artist"),
    order:            Literal["asc", "desc"]   = Query(default="asc"),
    key: bytes        = Depends(require_auth),
    db:  AsyncSession = Depends(get_db),
) -> JSONResponse:
    if sort not in _SORT_COLUMNS:
        raise HTTPException(status_code=400, detail=f"Invalid sort. Choose from: {list(_SORT_COLUMNS)}")

    sort_col  = _SORT_COLUMNS[sort]
    sort_expr = sort_col.asc() if order == "asc" else sort_col.desc()

    stmt = select(Record)

    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(
            or_(
                Record.title.ilike(pattern),
                Record.artist.ilike(pattern),
                Record.label.ilike(pattern),
                Record.genre.ilike(pattern),
                Record.notes.ilike(pattern),
            )
        ).order_by(sort_expr)
    else:
        stmt = stmt.order_by(sort_expr)

    if artist:
        stmt = stmt.where(func.lower(Record.artist) == artist.lower())
    if genre:
        stmt = stmt.where(func.lower(Record.genre) == genre.lower())
    if owner is not None:
        stmt = stmt.where(Record.owner == owner)
    if format is not None:
        stmt = stmt.where(Record.format == format)
    if disc_condition is not None:
        stmt = stmt.where(Record.disc_condition == disc_condition)
    if sleeve_condition is not None:
        stmt = stmt.where(Record.sleeve_condition == sleeve_condition)
    if wishlist is not None:
        stmt = stmt.where(Record.wishlist == wishlist)

    total   = await db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows    = await db.scalars(stmt.offset((page - 1) * limit).limit(limit))
    records = rows.all()

    data = {
        "records": [_serialize(r) for r in records],
        "total":   total,
        "page":    page,
        "limit":   limit,
    }
    return JSONResponse(content=encrypt(key, data))


# ---------------------
# Combined create + photo upload  (multipart/form-data)
# ---------------------
#
# Form fields:
#   metadata       — required — JSON string of the encrypted envelope (same format as POST /records body)
#   sleeve_front        — optional image file
#   sleeve_back         — optional image file
#   sleeve_inner        — optional image file (gatefold, 2:1)
#   inner_sleeve_front  — optional image file (paper inner sleeve front)
#   inner_sleeve_back   — optional image file (paper inner sleeve back)
#   disc_front_1        — optional image file (disc 1 label side)
#   disc_back_1    — optional image file (disc 1 play side)
#   disc_front_2 … disc_back_4  — discs 2–4
#
# Declared before /{record_id} so FastAPI doesn't try to parse "upload" as a UUID.

@router.post("/upload", status_code=201)
async def upload_record(
    metadata:     str                = Form(..., description="Encrypted JSON envelope of the record fields"),
    sleeve_front:        UploadFile | None  = File(default=None),
    sleeve_back:         UploadFile | None  = File(default=None),
    sleeve_inner:        UploadFile | None  = File(default=None),
    inner_sleeve_front:  UploadFile | None  = File(default=None),
    inner_sleeve_back:   UploadFile | None  = File(default=None),
    disc_front_1:        UploadFile | None  = File(default=None),
    disc_back_1:  UploadFile | None  = File(default=None),
    disc_front_2: UploadFile | None  = File(default=None),
    disc_back_2:  UploadFile | None  = File(default=None),
    disc_front_3: UploadFile | None  = File(default=None),
    disc_back_3:  UploadFile | None  = File(default=None),
    disc_front_4: UploadFile | None  = File(default=None),
    disc_back_4:  UploadFile | None  = File(default=None),
    key: bytes        = Depends(require_auth),
    db:  AsyncSession = Depends(get_db),
) -> JSONResponse:
    # Decrypt the metadata envelope (same AES-256-CBC format as all other endpoints)
    try:
        body = decrypt(key, json.loads(metadata))
    except Exception:
        raise HTTPException(status_code=400, detail="Failed to decrypt metadata")

    data   = RecordCreate.model_validate(body)
    record = Record(**data.model_dump())
    db.add(record)
    await db.flush()  # populate record.id before attaching photos

    # Map form fields → (PhotoTypeEnum, disc_number)
    photo_slots: list[tuple[UploadFile | None, PhotoTypeEnum, int | None]] = [
        (sleeve_front,       PhotoTypeEnum.sleeve_front,       None),
        (sleeve_back,        PhotoTypeEnum.sleeve_back,        None),
        (sleeve_inner,       PhotoTypeEnum.sleeve_inner,       None),
        (inner_sleeve_front, PhotoTypeEnum.inner_sleeve_front, None),
        (inner_sleeve_back,  PhotoTypeEnum.inner_sleeve_back,  None),
        (disc_front_1,       PhotoTypeEnum.disc_front,         1),
        (disc_back_1,  PhotoTypeEnum.disc_back,    1),
        (disc_front_2, PhotoTypeEnum.disc_front,   2),
        (disc_back_2,  PhotoTypeEnum.disc_back,    2),
        (disc_front_3, PhotoTypeEnum.disc_front,   3),
        (disc_back_3,  PhotoTypeEnum.disc_back,    3),
        (disc_front_4, PhotoTypeEnum.disc_front,   4),
        (disc_back_4,  PhotoTypeEnum.disc_back,    4),
    ]

    for file, photo_type, disc_number in photo_slots:
        if file is not None:
            await attach_photo(db, record.id, photo_type, disc_number, file)

    await db.commit()
    await db.refresh(record)
    return JSONResponse(content=encrypt(key, _serialize(record)), status_code=201)


# ---------------------
# Get one
# ---------------------

@router.get("/{record_id}")
async def get_record(
    record_id: uuid.UUID,
    key: bytes        = Depends(require_auth),
    db:  AsyncSession = Depends(get_db),
) -> JSONResponse:
    record = await db.get(Record, record_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Record not found")
    return JSONResponse(content=encrypt(key, _serialize(record)))


# ---------------------
# Create
# ---------------------

@router.post("", status_code=201)
async def create_record(
    body: dict        = Depends(decrypt_body),
    key:  bytes       = Depends(require_auth),
    db:   AsyncSession = Depends(get_db),
) -> JSONResponse:
    data   = RecordCreate.model_validate(body)
    record = Record(**data.model_dump())
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return JSONResponse(content=encrypt(key, _serialize(record)), status_code=201)


# ---------------------
# Replace (PUT)
# ---------------------

@router.put("/{record_id}")
async def replace_record(
    record_id: uuid.UUID,
    body: dict        = Depends(decrypt_body),
    key:  bytes       = Depends(require_auth),
    db:   AsyncSession = Depends(get_db),
) -> JSONResponse:
    record = await db.get(Record, record_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Record not found")
    data = RecordCreate.model_validate(body)
    for field, value in data.model_dump().items():
        setattr(record, field, value)
    await db.commit()
    await db.refresh(record)
    return JSONResponse(content=encrypt(key, _serialize(record)))


# ---------------------
# Partial update (PATCH)
# ---------------------

@router.patch("/{record_id}")
async def update_record(
    record_id: uuid.UUID,
    body: dict        = Depends(decrypt_body),
    key:  bytes       = Depends(require_auth),
    db:   AsyncSession = Depends(get_db),
) -> JSONResponse:
    record = await db.get(Record, record_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Record not found")
    data = RecordUpdate.model_validate(body)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(record, field, value)
    await db.commit()
    await db.refresh(record)
    return JSONResponse(content=encrypt(key, _serialize(record)))


# ---------------------
# Delete
# ---------------------

@router.delete("/{record_id}", status_code=204)
async def delete_record(
    record_id: uuid.UUID,
    key: bytes        = Depends(require_auth),
    db:  AsyncSession = Depends(get_db),
) -> None:
    record = await db.get(Record, record_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Record not found")
    await db.delete(record)
    await db.commit()
