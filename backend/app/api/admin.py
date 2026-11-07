"""Custom admin UI and role-protected operational API."""

from pathlib import Path
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Query
from fastapi.responses import FileResponse
from pydantic import Field, StrictBool
from sqlalchemy import func, or_, select

from app.api.deps import DbSession, PlatformAdminUser
from app.core.errors import AppError, not_found, validation_error
from app.models import (
    AuditLog,
    Material,
    Organization,
    OrganizationMembership,
    PlatformAdmin,
    User,
)
from app.models.commerce import BuyerRequirement, Reservation, Transaction
from app.models.enums import MembershipStatus, OrganizationKind, OrgRole, Role
from app.models.planning import Analysis, OptimizationRun
from app.schemas.auth import UserOut
from app.schemas.types import StrictIn
from app.services import audit

router = APIRouter(tags=["Admin"])
AdminUser = PlatformAdminUser
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
    if target.role == Role.admin or db.get(PlatformAdmin, target.id) is not None:
        raise AppError(409, "PRECONDITION_FAILED", details={"reason": "ADMIN_ACCOUNT_PROTECTED"})
    previous = target.active
    target.active = data.active
    audit.record(
        db,
        "user.access_changed",
        actor_user_id=user.id,
        target_type="user",
        target_id=target.id,
        details={"active_before": previous, "active_after": data.active},
    )
    db.commit()
    logging.getLogger("arta.admin.audit").info(
        "actor=%s target=%s active_before=%s active_after=%s",
        user.id,
        target.id,
        previous,
        data.active,
    )
    return target


# ---------- legacy organization review (R1, docs/api.md 20.12) ----------


class ActivateIn(StrictIn):
    kind: OrganizationKind
    role: OrgRole


class RejectIn(StrictIn):
    reason: Annotated[str, Field(min_length=1, max_length=200)] | None = None


def _pending_membership(db, raw_id: UUID) -> OrganizationMembership:
    m = db.scalar(
        select(OrganizationMembership).where(OrganizationMembership.id == raw_id).with_for_update()
    )
    if m is None:
        raise not_found()
    if m.status != MembershipStatus.pending_review:
        raise AppError(409, "INVALID_TRANSITION", details={"current_status": m.status.value})
    return m


@router.get("/admin/api/reviews")
def reviews(
    user: AdminUser,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    stmt = (
        select(OrganizationMembership, Organization, User)
        .join(Organization, Organization.id == OrganizationMembership.organization_id)
        .join(User, User.id == OrganizationMembership.user_id)
        .where(OrganizationMembership.status == MembershipStatus.pending_review)
    )
    total = db.scalar(select(func.count()).select_from(stmt.subquery()))
    rows = db.execute(
        stmt.order_by(OrganizationMembership.created_at, OrganizationMembership.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    reasons = {
        a.organization_id: (a.details or {}).get("reason")
        for a in db.scalars(
            select(AuditLog).where(
                AuditLog.action == "backfill.ambiguous",
                AuditLog.organization_id.in_({o.id for _, o, _ in rows}),
            )
        )
    }
    items = [
        dict(
            membership_id=str(m.id),
            user_id=str(u.id),
            user_email=u.email,
            legacy_role=u.role.value,
            organization_id=str(o.id),
            organization_name=o.name,
            activity_type=o.activity_type.value,
            kind=o.kind.value if o.kind else None,
            review_reason=reasons.get(o.id),
            created_at=m.created_at.isoformat(),
        )
        for m, o, u in rows
    ]
    return dict(items=items, total=total, page=page, page_size=page_size)


@router.post("/admin/api/memberships/{id}/activate")
def activate_membership(id: UUID, data: ActivateIn, user: AdminUser, db: DbSession):
    m = _pending_membership(db, id)
    org = db.scalar(
        select(Organization).where(Organization.id == m.organization_id).with_for_update()
    )
    if org.kind is not None and org.kind != data.kind:
        raise AppError(
            409,
            "PRECONDITION_FAILED",
            details={"reason": "ORGANIZATION_KIND_MISMATCH", "organization_kind": org.kind.value},
        )
    if org.activity_type.value == "recycler" and data.kind != OrganizationKind.buyer:
        raise validation_error(
            "kind", "invalid_value", "Переработчик может быть только покупателем."
        )
    org.kind = data.kind
    m.status = MembershipStatus.active
    m.role = data.role
    audit.record(
        db,
        "membership.activated",
        actor_user_id=user.id,
        organization_id=org.id,
        target_type="membership",
        target_id=m.id,
        details={"user_id": str(m.user_id), "kind": data.kind.value, "role": data.role.value},
    )
    db.commit()
    return dict(
        membership_id=str(m.id),
        status=m.status.value,
        role=m.role.value,
        organization_id=str(org.id),
        kind=org.kind.value,
    )


@router.post("/admin/api/memberships/{id}/reject")
def reject_membership(id: UUID, data: RejectIn, user: AdminUser, db: DbSession):
    m = _pending_membership(db, id)
    m.status = MembershipStatus.removed
    audit.record(
        db,
        "membership.rejected",
        actor_user_id=user.id,
        organization_id=m.organization_id,
        target_type="membership",
        target_id=m.id,
        details={"user_id": str(m.user_id), "reason": data.reason},
    )
    db.commit()
    return dict(membership_id=str(m.id), status=m.status.value)
