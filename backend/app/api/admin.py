"""Custom admin UI and role-protected operational API."""

from pathlib import Path
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from fastapi.responses import FileResponse
from pydantic import StrictBool
from sqlalchemy import func, or_, select

from app.api.deps import DbSession, require_roles
from app.core.errors import AppError, not_found
from app.models import Material, Organization, User
from app.models.commerce import BuyerRequirement, Reservation, Transaction
from app.models.enums import Role
from app.models.planning import Analysis, OptimizationRun
from app.schemas.auth import UserOut
from app.schemas.types import StrictIn

router = APIRouter(tags=["Admin"])
AdminUser = Annotated[User, Depends(require_roles(Role.admin))]
ROOT = Path(__file__).resolve().parents[1] / "admin_ui"
HEADERS = {
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self'; style-src 'self'; "
        "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; "
        "base-uri 'none'; form-action 'self'"
    ),
}
RESOURCES = {
    "users": (User, ("id", "email", "role", "organization_id", "active", "created_at")),
    "organizations": (
        Organization,
        (
            "id",
            "name",
            "city",
            "activity_type",
            "contact_name",
            "contact_email",
            "contact_phone",
            "created_at",
        ),
    ),
    "materials": (
        Material,
        (
            "id",
            "name",
            "organization_id",
            "material_type",
            "condition",
            "city",
            "status",
            "total_kg",
            "available_kg",
            "held_kg",
            "transferred_kg",
            "internally_used_kg",
            "price_per_kg",
            "version",
            "confirmed_at",
            "created_at",
        ),
    ),
    "requirements": (
        BuyerRequirement,
        (
            "id",
            "organization_id",
            "material_types",
            "conditions",
            "min_kg",
            "max_kg",
            "remaining_demand_kg",
            "budget_per_kg",
            "city",
            "uses",
            "active",
            "created_at",
        ),
    ),
    "reservations": (
        Reservation,
        (
            "id",
            "material_id",
            "seller_organization_id",
            "buyer_organization_id",
            "quantity_kg",
            "agreed_price_per_kg",
            "status",
            "cancel_reason",
            "created_at",
        ),
    ),
    "transactions": (
        Transaction,
        (
            "id",
            "reservation_id",
            "transferred_kg",
            "sale_amount_kgs",
            "confirmed_reuse_kg",
            "transfer_confirmed_at",
            "receipt_confirmed_at",
            "created_at",
        ),
    ),
    "analyses": (
        Analysis,
        (
            "id",
            "material_id",
            "input_version",
            "status",
            "provider",
            "model",
            "mode",
            "error_code",
            "created_at",
        ),
    ),
    "plans": (OptimizationRun, ("id", "organization_id", "created_at")),
}
Resource = Literal[
    "users",
    "organizations",
    "materials",
    "requirements",
    "reservations",
    "transactions",
    "analyses",
    "plans",
]


def serialize(row, fields):
    from datetime import datetime
    from decimal import Decimal

    result = {}
    for field in fields:
        value = getattr(row, field)
        if isinstance(value, Decimal):
            value = (
                f"{value:.3f}"
                if field.endswith("_kg") and "price" not in field and "budget" not in field
                else f"{value:.2f}"
            )
        elif isinstance(value, datetime):
            value = value.isoformat()
        result[field] = value
    if isinstance(row, OptimizationRun):
        result.update(
            {k: row.result.get(k) for k in ("status", "objective_kgs", "method", "label")}
        )
    return result


@router.get("/admin", include_in_schema=False)
@router.get("/admin/", include_in_schema=False)
def page():
    return FileResponse(ROOT / "index.html", headers=HEADERS)


@router.get("/admin/assets/{filename}", include_in_schema=False)
def asset(filename: Literal["admin.css", "admin.js"]):
    return FileResponse(ROOT / filename, headers=HEADERS)


@router.get("/admin/api/me", response_model=UserOut)
def me(user: AdminUser):
    return user


@router.get("/admin/api/summary")
def summary(user: AdminUser, db: DbSession):
    counts = {
        name: db.scalar(select(func.count()).select_from(model))
        for name, (model, _) in RESOURCES.items()
    }
    counts["active_users"] = db.scalar(
        select(func.count()).select_from(User).where(User.active.is_(True))
    )
    totals = db.execute(
        select(
            func.coalesce(func.sum(Material.total_kg), 0),
            func.coalesce(func.sum(Material.available_kg), 0),
        )
    ).one()
    revenue = db.scalar(
        select(func.coalesce(func.sum(Transaction.sale_amount_kgs), 0))
        .join(Reservation, Reservation.id == Transaction.reservation_id)
        .where(Reservation.status == "completed")
    )
    return dict(
        counts=counts,
        total_kg=f"{totals[0]:.3f}",
        available_kg=f"{totals[1]:.3f}",
        revenue_kgs=f"{revenue:.2f}",
    )


@router.get("/admin/api/records/{resource}")
def records(
    resource: Resource,
    user: AdminUser,
    db: DbSession,
    q: str = Query("", max_length=200),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    model, fields = RESOURCES[resource]
    stmt = select(model)
    if q.strip():
        value = q.strip()
        escaped = value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        clauses = [
            getattr(model, k).ilike(f"%{escaped}%", escape="\\")
            for k in ("name", "email", "city")
            if hasattr(model, k)
        ]
        try:
            clauses.append(model.id == UUID(value))
        except ValueError:
            pass
        if not clauses:
            return dict(items=[], total=0, page=page, page_size=page_size)
        stmt = stmt.where(or_(*clauses))
    total = db.scalar(select(func.count()).select_from(stmt.subquery()))
    rows = db.scalars(
        stmt.order_by(model.created_at.desc(), model.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return dict(
        items=[serialize(row, fields) for row in rows], total=total, page=page, page_size=page_size
    )


class AccessPatch(StrictIn):
    active: StrictBool


@router.patch("/admin/api/users/{id}/access", response_model=UserOut)
def access(id: UUID, data: AccessPatch, user: AdminUser, db: DbSession):
    import logging

    target = db.scalar(select(User).where(User.id == id).with_for_update())
    if target is None:
        raise not_found()
    if target.role == Role.admin:
        raise AppError(409, "PRECONDITION_FAILED", details={"reason": "ADMIN_ACCOUNT_PROTECTED"})
    previous = target.active
    target.active = data.active
    db.commit()
    logging.getLogger("arta.admin.audit").info(
        "actor=%s target=%s active_before=%s active_after=%s",
        user.id,
        target.id,
        previous,
        data.active,
    )
    return target
