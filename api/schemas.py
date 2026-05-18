from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from .models import FormatEnum, GradeEnum, OwnerEnum, PhotoTypeEnum, SpeedEnum


# ---------------------
# Photo schemas
# ---------------------

class PhotoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:          uuid.UUID
    photo_type:  PhotoTypeEnum
    disc_number: int | None
    mime_type:   str
    file_size:   int
    url:         str = ""  # injected by the router
    created_at:  datetime


# ---------------------
# Record schemas
# ---------------------

class RecordCreate(BaseModel):
    title:            str
    artist:           str
    year:             int | None             = None
    duration:         str | None             = None
    label:            str | None             = None
    format:           FormatEnum | None      = None
    speed:            SpeedEnum | None       = None
    genre:            str | None             = None
    notes:            str | None             = None
    owner:             OwnerEnum              = OwnerEnum.shared
    disc_count:        int                    = 1
    outer_sleeve_only: bool                   = False
    disc_condition:    GradeEnum | None       = None
    sleeve_condition:  GradeEnum | None       = None


class RecordUpdate(BaseModel):
    """All fields optional — only provided fields are written (PATCH semantics)."""
    title:            str | None        = Field(default=None)
    artist:           str | None        = Field(default=None)
    year:             int | None        = Field(default=None)
    duration:         str | None        = Field(default=None)
    label:            str | None        = Field(default=None)
    format:           FormatEnum | None = Field(default=None)
    speed:            SpeedEnum | None  = Field(default=None)
    genre:            str | None        = Field(default=None)
    notes:            str | None        = Field(default=None)
    owner:             OwnerEnum | None  = Field(default=None)
    disc_count:        int | None        = Field(default=None)
    outer_sleeve_only: bool | None       = Field(default=None)
    disc_condition:    GradeEnum | None  = Field(default=None)
    sleeve_condition:  GradeEnum | None  = Field(default=None)


class RecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:               uuid.UUID
    title:            str
    artist:           str
    year:             int | None
    duration:         str | None
    label:            str | None
    format:           FormatEnum | None
    speed:            SpeedEnum | None
    genre:            str | None
    notes:            str | None
    owner:             OwnerEnum
    disc_count:        int
    outer_sleeve_only: bool
    disc_condition:    GradeEnum | None
    sleeve_condition:  GradeEnum | None
    photos:            list[PhotoResponse] = []
    created_at:       datetime
    updated_at:       datetime


# ---------------------
# List response
# ---------------------

class RecordListResponse(BaseModel):
    records: list[RecordResponse]
    total:   int
    page:    int
    limit:   int
