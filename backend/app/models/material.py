import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.common import utcnow
from app.models.enums import MaterialCondition, MaterialStatus, MaterialType

ZERO = Decimal("0.000")


class Material(Base):
    __tablename__ = "materials"
    __table_args__ = (
        CheckConstraint("total_kg >= 0", name="total_nonneg"),
        CheckConstraint("available_kg >= 0", name="available_nonneg"),
        CheckConstraint("held_kg >= 0", name="held_nonneg"),
        CheckConstraint("transferred_kg >= 0", name="transferred_nonneg"),
        CheckConstraint("internally_used_kg >= 0", name="used_nonneg"),
        CheckConstraint(
            "total_kg = available_kg + held_kg + transferred_kg + internally_used_kg",
            name="balance",
        ),
        CheckConstraint("price_per_kg IS NULL OR price_per_kg >= 0", name="price_nonneg"),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint(
            "status IN ('draft', 'archived') OR total_kg > 0", name="published_mass_positive"
        ),
        Index("ix_materials_org_status", "organization_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    organization_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("organizations.id"))
    name: Mapped[str] = mapped_column(String(200))
    material_type: Mapped[MaterialType | None] = mapped_column(
        Enum(
            MaterialType, native_enum=False, create_constraint=True, length=32, name="material_type"
        )
    )
    description: Mapped[str | None] = mapped_column(String(1000))
    composition: Mapped[str | None] = mapped_column(String(200))
    scrap_size: Mapped[str | None] = mapped_column(String(100))
    condition: Mapped[MaterialCondition | None] = mapped_column(
        Enum(
            MaterialCondition,
            native_enum=False,
            create_constraint=True,
            length=32,
            name="material_condition",
        )
    )
    price_per_kg: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    city: Mapped[str | None] = mapped_column(String(100))
    status: Mapped[MaterialStatus] = mapped_column(
        Enum(
            MaterialStatus,
            native_enum=False,
            create_constraint=True,
            length=32,
            name="material_status",
        ),
        default=MaterialStatus.draft,
    )
    total_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=ZERO)
    available_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=ZERO)
    held_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=ZERO)
    transferred_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=ZERO)
    internally_used_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=ZERO)
    version: Mapped[int] = mapped_column(Integer, default=1)
    # Set by POST /confirm, cleared when input characteristics change (api.md section 4).
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    confirmed_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    images: Mapped[list["MaterialImage"]] = relationship(
        order_by="(MaterialImage.sort_order, MaterialImage.created_at)",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class MaterialImage(Base):
    __tablename__ = "material_images"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    material_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("materials.id", ondelete="CASCADE"), index=True
    )
    # Object key only, never a URL (CLAUDE.md section 11).
    storage_key: Mapped[str] = mapped_column(String(255), unique=True)
    mime_type: Mapped[str] = mapped_column(String(32))
    size_bytes: Mapped[int] = mapped_column(Integer)
    width_px: Mapped[int] = mapped_column(Integer)
    height_px: Mapped[int] = mapped_column(Integer)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
