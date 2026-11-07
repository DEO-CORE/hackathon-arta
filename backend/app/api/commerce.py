from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, Query
from sqlalchemy import func, select

from app.api.deps import DbSession, perm
from app.models.commerce import BuyerRequirement, Reservation
from app.models.enums import MaterialType, Role
from app.schemas.commerce import (
    InternalUse,
    InternalUseOut,
    RequirementCreate,
    RequirementOut,
    RequirementPatch,
    RequirementPublic,
    ReservationAction,
    ReservationCreate,
    ReservationOut,
    ReservationStatus,
    ReuseConfirmation,
    ReuseConfirmationOut,
    TransactionViewOut,
)
from app.schemas.material import Page
from app.services import commerce as service

router = APIRouter(tags=["Commerce"])
ReqReader = perm("requirement.read", "requirement.read_public", any_of=True)
ReqWriter = perm("requirement.write")
ResReader = perm("reservation.read")
ResActor = perm("reservation.read")  # action-level permission is checked after the 404 check
ResCreator = perm("reservation.create")
InternalUser = perm("material.internal_use", material_param="id")
ReuseUser = perm("reuse.confirm")
Key = Annotated[
    str, Header(alias="Idempotency-Key", min_length=8, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
]
OptionalKey = Annotated[
    str | None,
    Header(alias="Idempotency-Key", min_length=8, max_length=128, pattern=r"^[A-Za-z0-9_-]+$"),
]


@router.post("/buyer-requirements", status_code=201, response_model=RequirementOut)
def create_requirement(data: RequirementCreate, user: ReqWriter, db: DbSession):
    r = BuyerRequirement(
        **data.model_dump(), organization_id=user.organization_id, remaining_demand_kg=data.max_kg
    )
    db.add(r)
    db.commit()
    return service.requirement_out(r, user)


@router.patch("/buyer-requirements/{id}", response_model=RequirementOut)
def patch_requirement(id: str, data: RequirementPatch, user: ReqWriter, db: DbSession):
    return service.patch_requirement(db, user, id, data)


@router.get("/buyer-requirements", response_model=Page[RequirementOut | RequirementPublic])
def requirements(
    user: ReqReader,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    active: bool | None = None,
    material_type: MaterialType | None = None,
    city: str | None = None,
):
    stmt = select(BuyerRequirement)
    if user.role == Role.buyer:
        stmt = stmt.where(BuyerRequirement.organization_id == user.organization_id)
        if active is not None:
            stmt = stmt.where(BuyerRequirement.active == active)
    else:
        stmt = stmt.where(
            BuyerRequirement.active.is_(True),
            BuyerRequirement.organization_id != user.organization_id,
        )
    if city:
        stmt = stmt.where(func.lower(BuyerRequirement.city) == city.strip().lower())
    rows = db.scalars(stmt.order_by(BuyerRequirement.created_at.desc(), BuyerRequirement.id)).all()
    if material_type:
        rows = [r for r in rows if material_type in r.material_types]
    return dict(
        items=[
            service.requirement_out(r, user)
            for r in rows[(page - 1) * page_size : page * page_size]
        ],
        total=len(rows),
        page=page,
        page_size=page_size,
    )


@router.post("/reservations", status_code=201, response_model=ReservationOut)
def create_reservation(data: ReservationCreate, user: ResCreator, db: DbSession, key: Key):
    return service.idempotent(
        db,
        user,
        "POST /reservations",
        key,
        data,
        201,
        lambda: service.create_reservation(db, user, data),
    )


@router.get("/reservations", response_model=Page[ReservationOut])
def reservations(
    user: ResReader,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Annotated[list[ReservationStatus] | None, Query()] = None,
    material_id: UUID | None = None,
):
    owner = (
        Reservation.seller_organization_id
        if user.role == Role.enterprise
        else Reservation.buyer_organization_id
    )
    stmt = select(Reservation).where(owner == user.organization_id)
    if status:
        stmt = stmt.where(Reservation.status.in_(status))
    if material_id:
        stmt = stmt.where(Reservation.material_id == material_id)
    total = db.scalar(select(func.count()).select_from(stmt.subquery()))
    rows = db.scalars(
        stmt.order_by(Reservation.created_at.desc(), Reservation.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return dict(
        items=[service.reservation_out(db, r, user) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.patch("/reservations/{id}", response_model=ReservationOut)
def action(
    id: str, data: ReservationAction, user: ResActor, db: DbSession, key: OptionalKey = None
):
    return service.idempotent(
        db,
        user,
        f"PATCH /reservations/{id}/{data.action}",
        key,
        data,
        200,
        lambda: service.act(db, user, id, data),
    )


@router.post("/materials/{id}/internal-use", status_code=201, response_model=InternalUseOut)
def internal_use(id: str, data: InternalUse, user: InternalUser, db: DbSession, key: Key):
    return service.idempotent(
        db,
        user,
        f"POST /materials/{id}/internal-use",
        key,
        data,
        201,
        lambda: service.internal_use(db, user, id, data),
    )


@router.post(
    "/transactions/{id}/reuse-confirmation", status_code=201, response_model=ReuseConfirmationOut
)
def reuse(id: str, data: ReuseConfirmation, user: ReuseUser, db: DbSession, key: Key):
    return service.idempotent(
        db,
        user,
        f"POST /transactions/{id}/reuse-confirmation",
        key,
        data,
        201,
        lambda: service.confirm_reuse(db, user, id, data),
    )


@router.get("/transactions", response_model=Page[TransactionViewOut])
def transactions(
    user: ResReader,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Annotated[list[ReservationStatus] | None, Query()] = None,
):
    return service.list_transactions(db, user, page, page_size, status)


@router.get("/transactions/{id}", response_model=TransactionViewOut)
def transaction(id: str, user: ResReader, db: DbSession):
    return service.get_transaction(db, user, id)
