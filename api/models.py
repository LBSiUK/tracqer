import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, Enum as SAEnum, ForeignKey, Integer, SmallInteger, Text
from sqlalchemy import func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


# ---------------------
# Python enums (values must match the PostgreSQL enum literals exactly)
# ---------------------

class GradeEnum(str, enum.Enum):
    """Goldmine/Discogs standard grading scale."""
    MINT      = "M"
    NEAR_MINT = "NM"
    VG_PLUS   = "VG+"
    VG        = "VG"
    G_PLUS    = "G+"
    GOOD      = "G"
    FAIR      = "F"
    POOR      = "P"


class SpeedEnum(str, enum.Enum):
    rpm_33 = "33"
    rpm_45 = "45"
    rpm_78 = "78"


class FormatEnum(str, enum.Enum):
    lp_12     = '12" LP'
    lp_10     = '10" LP'
    single_12 = '12" single'
    single_7  = '7" single'
    other     = 'Other'


class OwnerEnum(str, enum.Enum):
    me     = "me"
    dad    = "dad"
    shared = "shared"


class PhotoTypeEnum(str, enum.Enum):
    sleeve_front        = "sleeve_front"
    sleeve_back         = "sleeve_back"
    sleeve_inner        = "sleeve_inner"         # gatefold inner spread (2:1)
    inner_sleeve_front  = "inner_sleeve_front"   # paper inner sleeve front
    inner_sleeve_back   = "inner_sleeve_back"    # paper inner sleeve back
    disc_front          = "disc_front"           # label side
    disc_back           = "disc_back"            # play side

    @property
    def requires_disc_number(self) -> bool:
        return self in (PhotoTypeEnum.disc_front, PhotoTypeEnum.disc_back)


# ---------------------
# ORM models
# ---------------------

class Photo(Base):
    __tablename__ = "photos"

    id:          Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    record_id:   Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), ForeignKey("records.id", ondelete="CASCADE"), nullable=False)
    photo_type:  Mapped[PhotoTypeEnum]    = mapped_column(
        SAEnum(PhotoTypeEnum, name="photo_type", create_type=False, values_callable=lambda e: [x.value for x in e]), nullable=False
    )
    disc_number: Mapped[int | None]       = mapped_column(SmallInteger, nullable=True)
    mime_type:   Mapped[str]              = mapped_column(Text, nullable=False)
    file_size:   Mapped[int]              = mapped_column(Integer, nullable=False)
    created_at:  Mapped[datetime]         = mapped_column(nullable=False, server_default=func.now())

    record: Mapped["Record"] = relationship(back_populates="photos")


class Record(Base):
    __tablename__ = "records"

    id:               Mapped[uuid.UUID]          = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title:            Mapped[str]                = mapped_column(Text, nullable=False)
    artist:           Mapped[str]                = mapped_column(Text, nullable=False)
    year:             Mapped[int | None]          = mapped_column(SmallInteger, nullable=True)
    duration:         Mapped[str | None]          = mapped_column(Text, nullable=True)
    label:            Mapped[str | None]          = mapped_column(Text, nullable=True)
    format:           Mapped[FormatEnum | None]   = mapped_column(
        SAEnum(FormatEnum, name="record_format", create_type=False, values_callable=lambda e: [x.value for x in e]), nullable=True
    )
    speed:            Mapped[SpeedEnum | None]    = mapped_column(
        SAEnum(SpeedEnum, name="record_speed", create_type=False, values_callable=lambda e: [x.value for x in e]), nullable=True
    )
    genre:            Mapped[str | None]          = mapped_column(Text, nullable=True)
    notes:            Mapped[str | None]          = mapped_column(Text, nullable=True)
    owner:            Mapped[OwnerEnum]           = mapped_column(
        SAEnum(OwnerEnum, name="record_owner", create_type=False, values_callable=lambda e: [x.value for x in e]),
        nullable=False,
        server_default="shared",
    )
    disc_count:        Mapped[int]                 = mapped_column(SmallInteger, nullable=False, default=1, server_default="1")
    outer_sleeve_only: Mapped[bool]                = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    disc_condition:   Mapped[GradeEnum | None]    = mapped_column(
        SAEnum(GradeEnum, name="record_grade", create_type=False, values_callable=lambda e: [x.value for x in e]), nullable=True
    )
    sleeve_condition: Mapped[GradeEnum | None]    = mapped_column(
        SAEnum(GradeEnum, name="record_grade", create_type=False, values_callable=lambda e: [x.value for x in e]), nullable=True
    )

    # search_vector is GENERATED ALWAYS — never written by the ORM
    created_at: Mapped[datetime] = mapped_column(nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(nullable=False, server_default=func.now())

    photos: Mapped[list[Photo]] = relationship(
        back_populates="record",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class Auth(Base):
    __tablename__ = "auth"

    id:         Mapped[int]      = mapped_column(SmallInteger, primary_key=True, default=1)
    token:      Mapped[str]      = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(nullable=False, server_default=func.now())
