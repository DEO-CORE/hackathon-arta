import logging
import uuid
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import AppError, not_found
from app.integrations.storage import ObjectStorage
from app.models import Material, MaterialImage, Organization, User
from app.models.common import utcnow
from app.models.enums import MaterialCondition, MaterialStatus, MaterialType, Role
from app.schemas.material import (
    CHARACTERISTIC_FIELDS,
    BalanceOut,
    MaterialCreateIn,
    MaterialImageOut,
    MaterialOut,
    MaterialPatchIn,
    MaterialPublicOut,
    Page,
)
from app.schemas.types import Mass, Money, trimmed
from app.services import images as image_service
from app.services import inventory

logger = logging.getLogger("arta")

OBLIGATION_BLOCKED_FIELDS = ("material_type", "condition", "city", "total_kg")
BUYER_VISIBLE = (MaterialStatus.available, MaterialStatus.partially_allocated)


# ---------- DTO builders ----------


def material_out(m: Material) -> MaterialOut:
    return MaterialOut(
        id=m.id,
        organization_id=m.organization_id,
        name=m.name,
        material_type=m.material_type,
        description=m.description,
        composition=m.composition,
        scrap_size=m.scrap_size,
        condition=m.condition,
        price_per_kg=m.price_per_kg,
        city=m.city,
        status=m.status,
        balance=BalanceOut(
            total_kg=m.total_kg,
            available_kg=m.available_kg,
            held_kg=m.held_kg,
            transferred_kg=m.transferred_kg,
            internally_used_kg=m.internally_used_kg,
        ),
        version=m.version,
        confirmed_at=m.confirmed_at,
        confirmed_by=m.confirmed_by,
        is_confirmation_current=m.confirmed_at is not None,
        images=[MaterialImageOut.model_validate(i) for i in m.images],
        created_at=m.created_at,
        updated_at=m.updated_at,
    )


def public_out(m: Material, organization_name: str) -> MaterialPublicOut:
    return MaterialPublicOut(
        id=m.id,
        organization_id=m.organization_id,
        organization_name=organization_name,
        name=m.name,
        material_type=m.material_type,
        description=m.description,
        composition=m.composition,
        scrap_size=m.scrap_size,
        condition=m.condition,
        price_per_kg=m.price_per_kg,
        city=m.city,
        available_kg=m.available_kg,
        status=m.status,
        images=[MaterialImageOut.model_validate(i) for i in m.images],
        version=m.version,
        created_at=m.created_at,
    )


# ---------- lookups ----------


def parse_uuid_or_404(raw: str) -> uuid.UUID:
    try:
        return uuid.UUID(raw)
    except ValueError:
        raise not_found() from None


def get_owned(db: Session, user: User, raw_id: str, *, lock: bool = False) -> Material:
    """Owner's material; foreign, missing and malformed IDs are all 404."""
    material_id = parse_uuid_or_404(raw_id)
    stmt = select(Material).where(
        Material.id == material_id, Material.organization_id == user.organization_id
    )
    if lock:
        # Row lock; populate_existing so an already-loaded instance is refreshed under the lock.
        stmt = stmt.with_for_update().execution_options(populate_existing=True)
    m = db.scalar(stmt)
    if m is None:
        raise not_found()
    return m


def get_for_user(db: Session, user: User, raw_id: str) -> MaterialOut | MaterialPublicOut:
    material_id = parse_uuid_or_404(raw_id)
    if user.role == Role.enterprise:
        return material_out(get_owned(db, user, raw_id))
    row = db.execute(
        select(Material, Organization.name)
        .join(Organization, Organization.id == Material.organization_id)
        .where(
            Material.id == material_id,
            Material.status.in_(BUYER_VISIBLE),
            Material.available_kg > 0,
        )
    ).first()
    if row is None:
        raise not_found()
    return public_out(row[0], row[1])


# ---------- list ----------


class MaterialListQuery(BaseModel):
    page: int = Field(1, ge=1)
    page_size: int = Field(20, ge=1, le=100)
    status: MaterialStatus | None = None
    material_type: list[MaterialType] = Field(default_factory=list)
    condition: list[MaterialCondition] = Field(default_factory=list)
    city: trimmed(100) | None = None
    min_available_kg: Mass | None = None
    max_price_per_kg: Money | None = None
    q: trimmed(100) | None = None
    sort: Literal["created_at_desc", "created_at_asc", "price_asc", "available_kg_desc"] = (
        "created_at_desc"
    )


def _escape_like(s: str) -> str:
    return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def list_materials(db: Session, user: User, q: MaterialListQuery) -> Page[Any]:
    stmt = select(Material)
    if user.role == Role.enterprise:
        stmt = stmt.where(Material.organization_id == user.organization_id)
        if q.status is not None:
            stmt = stmt.where(Material.status == q.status)
        else:
            stmt = stmt.where(Material.status != MaterialStatus.archived)  # A18-8
    else:
        stmt = stmt.where(Material.status.in_(BUYER_VISIBLE), Material.available_kg > 0)
    if q.material_type:
        stmt = stmt.where(Material.material_type.in_(q.material_type))
    if q.condition:
        stmt = stmt.where(Material.condition.in_(q.condition))
    if q.city:
        stmt = stmt.where(func.lower(Material.city) == q.city.lower())
    if q.min_available_kg is not None:
        stmt = stmt.where(Material.available_kg >= q.min_available_kg)
    if q.max_price_per_kg is not None:
        stmt = stmt.where(Material.price_per_kg <= q.max_price_per_kg)  # NULL price excluded
    if q.q:
        stmt = stmt.where(Material.name.ilike(f"%{_escape_like(q.q)}%", escape="\\"))

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    order = {
        "created_at_desc": [Material.created_at.desc()],
        "created_at_asc": [Material.created_at.asc()],
        "price_asc": [Material.price_per_kg.asc().nulls_last(), Material.created_at.desc()],
        "available_kg_desc": [Material.available_kg.desc(), Material.created_at.desc()],
    }[q.sort]
    stmt = stmt.order_by(*order, Material.id.asc())
    stmt = stmt.limit(q.page_size).offset((q.page - 1) * q.page_size)
    materials = list(db.scalars(stmt).all())

    if user.role == Role.enterprise:
        items: list[Any] = [material_out(m) for m in materials]
    else:
        org_ids = {m.organization_id for m in materials}
        names = dict(
            db.execute(
                select(Organization.id, Organization.name).where(Organization.id.in_(org_ids))
            ).all()
        )
        items = [public_out(m, names.get(m.organization_id, "")) for m in materials]
    return Page(items=items, page=q.page, page_size=q.page_size, total=total)


# ---------- create / patch ----------


def create_material(db: Session, user: User, data: MaterialCreateIn) -> Material:
    m = Material(
        organization_id=user.organization_id,
        name=data.name,
        material_type=data.material_type,
        description=data.description,
        composition=data.composition,
        scrap_size=data.scrap_size,
        condition=data.condition,
        price_per_kg=data.price_per_kg,
        city=data.city,
        status=MaterialStatus.draft,
        total_kg=data.total_kg,
        available_kg=data.total_kg,
        held_kg=Decimal("0.000"),
        transferred_kg=Decimal("0.000"),
        internally_used_kg=Decimal("0.000"),
        version=1,
    )
    db.add(m)
    db.commit()
    return m


def _version_conflict(m: Material) -> AppError:
    return AppError(409, "VERSION_CONFLICT", details={"current_version": m.version})


def _archived_error(action: str) -> AppError:
    return AppError(
        409, "INVALID_TRANSITION", details={"from": MaterialStatus.archived.value, "action": action}
    )


def _invalidate_inputs(m: Material) -> None:
    """Input characteristics changed: drop confirmation; unobligated published goes to draft."""
    m.confirmed_at = None
    m.confirmed_by = None
    if m.status not in (
        MaterialStatus.draft,
        MaterialStatus.archived,
    ) and not inventory.has_obligations(m):
        m.status = MaterialStatus.draft


def patch_material(db: Session, user: User, raw_id: str, data: MaterialPatchIn) -> Material:
    m = get_owned(db, user, raw_id, lock=True)
    sent = data.model_fields_set
    changes = {
        f: getattr(data, f) for f in ("name", "price_per_kg", *CHARACTERISTIC_FIELDS) if f in sent
    }

    if "total_kg" in changes and changes["total_kg"] == 0 and m.status != MaterialStatus.draft:
        raise AppError(
            422,
            "VALIDATION_ERROR",
            details={
                "errors": [
                    {
                        "field": "total_kg",
                        "code": "out_of_range",
                        "message": "Масса опубликованной партии должна быть больше нуля.",
                    }
                ]
            },
        )
    if m.version != data.version:
        raise _version_conflict(m)
    if m.status == MaterialStatus.archived:
        raise _archived_error("patch")

    actual = {f: v for f, v in changes.items() if getattr(m, f) != v}
    if not actual:
        return m  # A18-13: no real change, no version bump

    blocked: list[str] = []
    if inventory.has_obligations(m):
        blocked = [f for f in OBLIGATION_BLOCKED_FIELDS if f in actual]
    new_available: Decimal | None = None
    if "total_kg" in actual:
        new_available = actual["total_kg"] - m.held_kg - m.transferred_kg - m.internally_used_kg
        if new_available < 0 and "total_kg" not in blocked:
            blocked.append("total_kg")
    if blocked:
        raise AppError(409, "ACTIVE_OBLIGATIONS", details={"blocked_fields": blocked})

    for f, v in actual.items():
        setattr(m, f, v)
    if new_available is not None:
        m.available_kg = new_available
    m.version += 1
    if any(f in actual for f in CHARACTERISTIC_FIELDS):
        _invalidate_inputs(m)
    inventory.refresh_status(m)
    db.commit()
    return m


# ---------- confirm / publish / archive ----------


def confirm_material(
    db: Session, user: User, raw_id: str, version: int, analysis_id: uuid.UUID | None
) -> Material:
    m = get_owned(db, user, raw_id, lock=True)
    if m.version != version:
        raise _version_conflict(m)
    if m.status == MaterialStatus.archived:
        raise _archived_error("confirm")
    if analysis_id is not None:
        from app.models.planning import Analysis

        analysis = db.get(Analysis, analysis_id)
        if analysis is None or analysis.material_id != m.id:
            raise AppError(
                409, "PRECONDITION_FAILED", details={"reason": "ANALYSIS_NOT_FOUND_FOR_MATERIAL"}
            )
        if analysis.input_version != m.version:
            raise AppError(409, "PRECONDITION_FAILED", details={"reason": "ANALYSIS_STALE"})
        if analysis.status != "succeeded":
            raise AppError(409, "PRECONDITION_FAILED", details={"reason": "ANALYSIS_NOT_SUCCEEDED"})
        analysis.confirmed_at, analysis.confirmed_by = utcnow(), user.id
    if m.confirmed_at is not None:
        db.commit()
        return m  # repeat for an already confirmed version
    m.confirmed_at = utcnow()
    m.confirmed_by = user.id
    db.commit()
    return m


def missing_for_publish(m: Material) -> list[str]:
    missing: list[str] = []
    if m.material_type is None:
        missing.append("material_type")
    if m.total_kg <= 0:
        missing.append("total_kg")
    if m.condition is None:
        missing.append("condition")
    if m.city is None:
        missing.append("city")
    if not m.images:
        missing.append("images")
    if m.confirmed_at is None:
        missing.append("confirmation")
    return missing


_PUBLISH_MESSAGES = {
    "material_type": "Укажите тип материала.",
    "total_kg": "Укажите массу больше нуля.",
    "condition": "Укажите состояние.",
    "city": "Укажите город.",
    "images": "Добавьте хотя бы одно фото.",
    "confirmation": "Подтвердите характеристики.",
}


def publish_material(db: Session, user: User, raw_id: str, version: int) -> Material:
    m = get_owned(db, user, raw_id, lock=True)
    if m.version != version:
        raise _version_conflict(m)
    if m.status == MaterialStatus.archived:
        raise _archived_error("publish")
    if m.status != MaterialStatus.draft:
        return m  # repeat: 200, nothing written (19.3)
    missing = missing_for_publish(m)
    if missing:
        raise AppError(
            422,
            "PUBLISH_REQUIREMENTS_NOT_MET",
            details={
                "missing": missing,
                "errors": [
                    {"field": f, "code": "required", "message": _PUBLISH_MESSAGES[f]}
                    for f in missing
                ],
            },
        )
    m.status = inventory.derive_published_status(m)
    db.commit()
    return m


def archive_material(db: Session, user: User, raw_id: str, version: int) -> Material:
    m = get_owned(db, user, raw_id, lock=True)
    if m.version != version:
        raise _version_conflict(m)
    if m.status == MaterialStatus.archived:
        return m
    if m.held_kg > 0:
        raise AppError(
            409,
            "ACTIVE_OBLIGATIONS",
            details={"held_kg": f"{m.held_kg:.3f}", "reason": "HELD_RESERVATIONS"},
        )
    from app.models.commerce import Reservation

    for reservation in db.scalars(
        select(Reservation)
        .where(Reservation.material_id == m.id, Reservation.status == "pending")
        .with_for_update()
    ):
        reservation.status = "cancelled"
        reservation.cancel_reason = "MATERIAL_ARCHIVED"
        reservation.cancelled_by_role = "enterprise"
    m.status = MaterialStatus.archived
    m.version += 1
    db.commit()
    return m


# ---------- images ----------


def _check_can_add_image(m: Material) -> None:
    if m.status == MaterialStatus.archived:
        raise _archived_error("images")
    if len(m.images) >= image_service.MAX_IMAGES:
        raise AppError(409, "IMAGE_LIMIT_REACHED", details={"max_images": image_service.MAX_IMAGES})
    if inventory.has_obligations(m):
        raise AppError(409, "ACTIVE_OBLIGATIONS")


def precheck_image_upload(db: Session, user: User, raw_id: str) -> None:
    """Ownership and limits before the file body is processed (order from api.md 18.7)."""
    _check_can_add_image(get_owned(db, user, raw_id))
    db.rollback()  # end the read transaction; add_image re-reads under a lock


def add_image(
    db: Session,
    user: User,
    raw_id: str,
    raw: bytes,
    sort_order: int | None,
    storage: ObjectStorage,
) -> tuple[MaterialImage, int]:
    material_id = parse_uuid_or_404(raw_id)
    checked = image_service.validate_and_clean(raw, material_id)  # 422 before any lock/IO
    stored = False
    try:
        m = get_owned(db, user, raw_id, lock=True)
        _check_can_add_image(m)  # re-check under the lock: concurrent uploads
        storage.put(checked.key, checked.data, checked.mime_type)
        stored = True
        existing = list(m.images)
        if sort_order is None:
            sort_order = max((i.sort_order for i in existing), default=-1) + 1
        else:
            for i in existing:
                if i.sort_order >= sort_order:
                    i.sort_order += 1
        image = MaterialImage(
            material_id=m.id,
            storage_key=checked.key,
            mime_type=checked.mime_type,
            size_bytes=len(checked.data),
            width_px=checked.width,
            height_px=checked.height,
            sort_order=sort_order,
        )
        db.add(image)
        m.version += 1
        m.updated_at = utcnow()
        _invalidate_inputs(m)
        inventory.refresh_status(m)
        db.commit()
        return image, m.version
    except BaseException:
        db.rollback()
        if stored:
            storage.delete(checked.key)
        raise
