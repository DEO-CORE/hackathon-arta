"""Persistent commerce records. Inventory is changed only by transactional services."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.common import utcnow


class Record:
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class BuyerRequirement(Record, Base):
    __tablename__ = "buyer_requirements"
    __table_args__ = (
        CheckConstraint("min_kg >= 0 AND max_kg > 0 AND min_kg <= max_kg", name="demand_bounds"),
        CheckConstraint(
            "remaining_demand_kg >= 0 AND remaining_demand_kg <= max_kg", name="remaining_bounds"
        ),
        CheckConstraint("budget_per_kg IS NULL OR budget_per_kg >= 0", name="budget_nonnegative"),
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), index=True)
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("organizations.id"), index=True
    )
    material_types: Mapped[list[str]] = mapped_column(JSON)
    conditions: Mapped[list[str]] = mapped_column(JSON)
    min_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    max_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    remaining_demand_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    budget_per_kg: Mapped[Decimal | None] = mapped_column(Numeric(14, 2))
    city: Mapped[str | None] = mapped_column(String(100))
    uses: Mapped[list[str]] = mapped_column(JSON, default=list)
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class Reservation(Record, Base):
    __tablename__ = "reservations"
    __table_args__ = (
        CheckConstraint("quantity_kg > 0", name="positive_quantity"),
        CheckConstraint("agreed_price_per_kg >= 0", name="price_nonnegative"),
        CheckConstraint(
            "status IN ('pending','confirmed','transferred','completed','cancelled')", name="status"
        ),
    )
    material_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("materials.id"), index=True)
    seller_organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id"), index=True
    )
    buyer_user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), index=True)
    purpose: Mapped[str | None] = mapped_column(String(500))
    buyer_organization_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("organizations.id"), index=True
    )
    requirement_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("buyer_requirements.id"), index=True
    )
    quantity_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    agreed_price_per_kg: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    cancel_reason: Mapped[str | None] = mapped_column(String(500))
    cancelled_by_role: Mapped[str | None] = mapped_column(String(20))


class Transaction(Record, Base):
    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("transferred_kg > 0", name="positive_transfer"),
        CheckConstraint(
            "confirmed_reuse_kg >= 0 AND confirmed_reuse_kg <= transferred_kg", name="reuse_bounds"
        ),
        CheckConstraint("sale_amount_kgs >= 0", name="sale_nonnegative"),
    )
    reservation_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("reservations.id"), unique=True)
    transferred_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    sale_amount_kgs: Mapped[Decimal] = mapped_column(Numeric(24, 2))
    transfer_confirmed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    receipt_confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    confirmed_reuse_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3), default=Decimal(0))


class ImpactRecord(Record, Base):
    __tablename__ = "impact_records"
    __table_args__ = (
        CheckConstraint("quantity_kg > 0", name="positive_quantity"),
        CheckConstraint("kind IN ('internal_use','confirmed_reuse')", name="kind"),
        CheckConstraint(
            "(kind = 'internal_use' AND transaction_id IS NULL) OR "
            "(kind = 'confirmed_reuse' AND transaction_id IS NOT NULL)",
            name="source",
        ),
    )
    material_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("materials.id"), index=True)
    transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("transactions.id"), index=True
    )
    author_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    kind: Mapped[str] = mapped_column(String(32))
    quantity_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    basis: Mapped[str] = mapped_column(String(500))
    used_on: Mapped[date] = mapped_column(Date)


class IdempotencyRecord(Record, Base):
    __tablename__ = "idempotency_records"
    __table_args__ = (UniqueConstraint("user_id", "operation", "key", name="uq_idempotency_scope"),)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    operation: Mapped[str] = mapped_column(String(200))
    key: Mapped[str] = mapped_column(String(128))
    fingerprint: Mapped[str] = mapped_column(String(64))
    status_code: Mapped[int]
    body: Mapped[dict] = mapped_column(JSON)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
