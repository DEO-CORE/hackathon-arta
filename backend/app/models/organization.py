import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.common import utcnow
from app.models.enums import ActivityType, OrganizationKind


class Organization(Base):
    __tablename__ = "organizations"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200))
    city: Mapped[str] = mapped_column(String(100))
    activity_type: Mapped[ActivityType] = mapped_column(
        Enum(
            ActivityType, native_enum=False, create_constraint=True, length=32, name="activity_type"
        )
    )
    # NULL only for records the R1 backfill could not classify (manual review).
    kind: Mapped[OrganizationKind | None] = mapped_column(
        Enum(
            OrganizationKind,
            native_enum=False,
            create_constraint=True,
            length=16,
            name="organization_kind",
        ),
        nullable=True,
    )
    contact_name: Mapped[str | None] = mapped_column(String(200))
    contact_phone: Mapped[str | None] = mapped_column(String(200))
    contact_email: Mapped[str | None] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
