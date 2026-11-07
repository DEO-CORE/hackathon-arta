import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import JSON, CheckConstraint, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.commerce import Record


class Analysis(Record, Base):
    __tablename__ = "ai_analyses"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending','running','succeeded','failed','interrupted')", name="status"
        ),
    )
    material_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("materials.id"), index=True)
    input_version: Mapped[int]
    status: Mapped[str] = mapped_column(String(20), default="pending")
    provider: Mapped[str | None] = mapped_column(String(100))
    model: Mapped[str | None] = mapped_column(String(100))
    mode: Mapped[str | None] = mapped_column(String(20))
    schema_version: Mapped[str] = mapped_column(String(20), default="1.0")
    validated_result: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    image_snapshot: Mapped[list] = mapped_column(JSON)
    error_code: Mapped[str | None] = mapped_column(String(40))
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    confirmed_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))


class OptimizationRun(Record, Base):
    __tablename__ = "optimization_runs"
    organization_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("organizations.id"), index=True)
    snapshot: Mapped[dict] = mapped_column(JSON)
    result: Mapped[dict] = mapped_column(JSON)


class Allocation(Record, Base):
    __tablename__ = "allocations"
    __table_args__ = (CheckConstraint("quantity_kg > 0", name="positive_quantity"),)
    run_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("optimization_runs.id", ondelete="CASCADE"), index=True
    )
    material_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("materials.id"))
    requirement_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("buyer_requirements.id"))
    direction: Mapped[str] = mapped_column(String(20))
    quantity_kg: Mapped[Decimal] = mapped_column(Numeric(12, 3))
    unit_value_kgs: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    unit_cost_kgs: Mapped[Decimal] = mapped_column(Numeric(14, 2))
    net_value_kgs: Mapped[Decimal] = mapped_column(Numeric(24, 2))
    explanation: Mapped[str] = mapped_column(String(500))
