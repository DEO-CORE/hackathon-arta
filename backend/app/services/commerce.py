import hashlib
import json
from datetime import timedelta
from decimal import Decimal

from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from app.core.errors import AppError, error_body, not_found, validation_error
from app.models import Material, Organization
from app.models.commerce import (
    BuyerRequirement,
    IdempotencyRecord,
    ImpactRecord,
    Reservation,
    Transaction,
)
from app.models.common import utcnow
from app.models.enums import Role
from app.schemas.commerce import (
    RequirementCreate,
    RequirementOut,
    RequirementPublic,
    ReservationOut,
    TransactionOut,
)
from app.services.inventory import refresh_status
from app.services.materials import BUYER_VISIBLE, get_owned, material_out, parse_uuid_or_404


def idempotent(db, user, operation, key, data, status, execute):
    """Unique DB claim and business savepoint commit together; concurrent duplicates wait."""
    if key is None:
        result = execute()
        db.commit()
        return JSONResponse(jsonable_encoder(result), status_code=status)
    payload = json.dumps(data.model_dump(mode="json"), sort_keys=True, separators=(",", ":"))
    fingerprint = hashlib.sha256(payload.encode()).hexdigest()
    scope = dict(user_id=user.id, operation=operation, key=key)
    db.execute(
        insert(IdempotencyRecord)
        .values(
            **scope,
            fingerprint=fingerprint,
            status_code=0,
            body={},
            expires_at=utcnow() + timedelta(hours=24),
        )
        .on_conflict_do_nothing(constraint="uq_idempotency_scope")
    )
    record = db.scalar(select(IdempotencyRecord).filter_by(**scope).with_for_update())
    if record.expires_at <= utcnow():
        record.fingerprint, record.status_code = fingerprint, 0
        record.expires_at = utcnow() + timedelta(hours=24)
    if record.fingerprint != fingerprint:
        raise AppError(409, "IDEMPOTENCY_KEY_REUSED")
    if record.status_code:
        db.commit()
        return JSONResponse(
            record.body, status_code=record.status_code, headers={"Idempotent-Replay": "true"}
        )
    try:
        with db.begin_nested():
            body = jsonable_encoder(execute())
    except AppError as error:
        if error.status_code != 409:
            raise
        status = error.status_code
        body = error_body(error.code, error.message, error.details)
    record.body, record.status_code = body, status
    db.commit()
    return JSONResponse(body, status_code=status)


def requirement_out(r, user):
    schema = RequirementOut if user.role == Role.buyer else RequirementPublic
    return schema.model_validate(r)


def patch_requirement(db, user, raw_id, data):
    r = db.scalar(
        select(BuyerRequirement)
        .where(
            BuyerRequirement.id == parse_uuid_or_404(raw_id),
            BuyerRequirement.organization_id == user.organization_id,
        )
        .with_for_update()
    )
    if r is None:
        raise not_found()
    merged = RequirementOut.model_validate(r).model_dump(mode="json")
    merged = {k: v for k, v in merged.items() if k in RequirementCreate.model_fields}
    changes = data.model_dump(mode="json", exclude_unset=True)
    merged.update({k: v for k, v in changes.items() if k != "active"})
    try:
        checked = RequirementCreate.model_validate(merged)
    except ValidationError:
        raise validation_error(
            "min_kg", "invalid_value", "Проверьте диапазон и списки потребности."
        ) from None
    consumed = r.max_kg - r.remaining_demand_kg
    if checked.max_kg < consumed:
        raise AppError(409, "DEMAND_EXCEEDED")
    for k, v in checked.model_dump().items():
        setattr(r, k, v)
    r.remaining_demand_kg = r.max_kg - consumed
    if "active" in changes:
        r.active = changes["active"]
    db.commit()
    return requirement_out(r, user)


def reservation_out(db, r, user):
    transaction = db.scalar(select(Transaction).where(Transaction.reservation_id == r.id))
    contacts = None
    if r.status in ("confirmed", "transferred", "completed"):
        other = (
            r.buyer_organization_id if user.role == Role.enterprise else r.seller_organization_id
        )
        org = db.get(Organization, other)
        contacts = {k: getattr(org, k) for k in ("contact_name", "contact_phone", "contact_email")}
    return ReservationOut(
        **{
            k: getattr(r, k)
            for k in ReservationOut.model_fields
            if k not in ("material_name", "transaction", "counterparty_contacts")
        },
        material_name=db.get(Material, r.material_id).name,
        transaction=TransactionOut.model_validate(transaction) if transaction else None,
        counterparty_contacts=contacts,
    )


def check_stock(m, quantity):
    if m.available_kg < quantity:
        raise AppError(
            409,
            "INSUFFICIENT_STOCK",
            details={"available_kg": f"{m.available_kg:.3f}", "requested_kg": f"{quantity:.3f}"},
        )


def check_requirement(r, m, quantity, price):
    if not r.active or r.remaining_demand_kg < quantity:
        raise AppError(409, "DEMAND_EXCEEDED")
    if (
        quantity < r.min_kg
        or m.material_type not in r.material_types
        or m.condition not in r.conditions
    ):
        raise validation_error(
            "requirement_id", "invalid_value", "Партия или объём не соответствует потребности."
        )
    if r.budget_per_kg is not None and price > r.budget_per_kg:
        raise validation_error("agreed_price_per_kg", "out_of_range", "Цена превышает бюджет.")
    # No confirmed applications exist in v1; AI suggestions cannot satisfy this constraint.
    if r.uses:
        raise validation_error(
            "requirement_id", "invalid_value", "Применение материала не подтверждено."
        )


def create_reservation(db, user, data):
    m = db.scalar(select(Material).where(Material.id == data.material_id).with_for_update())
    if m is None or m.status not in BUYER_VISIBLE or m.organization_id == user.organization_id:
        raise not_found()
    check_stock(m, data.quantity_kg)
    price = data.agreed_price_per_kg if data.agreed_price_per_kg is not None else m.price_per_kg
    if price is None:
        raise validation_error("agreed_price_per_kg", "required", "Укажите согласованную цену.")
    if data.requirement_id:
        req = db.scalar(
            select(BuyerRequirement)
            .where(BuyerRequirement.id == data.requirement_id)
            .with_for_update()
        )
        if req is None or req.organization_id != user.organization_id:
            raise not_found()
        check_requirement(req, m, data.quantity_kg, price)
    r = Reservation(
        material_id=m.id,
        seller_organization_id=m.organization_id,
        buyer_organization_id=user.organization_id,
        requirement_id=data.requirement_id,
        quantity_kg=data.quantity_kg,
        agreed_price_per_kg=price,
    )
    db.add(r)
    db.flush()
    return reservation_out(db, r, user)


def owned_reservation(db, user, raw_id):
    r = db.get(Reservation, parse_uuid_or_404(raw_id))
    if r is None or user.organization_id != (
        r.seller_organization_id if user.role == Role.enterprise else r.buyer_organization_id
    ):
        raise not_found()
    return r


def act(db, user, raw_id, data):
    r = owned_reservation(db, user, raw_id)
    if (
        data.action in ("confirm", "transfer")
        and user.role != Role.enterprise
        or data.action == "complete"
        and user.role != Role.buyer
    ):
        raise AppError(403, "FORBIDDEN")
    if data.action == "cancel" and user.role == Role.enterprise and not data.reason:
        raise validation_error("reason", "required", "Укажите причину отказа.")
    # Global lock order: material -> requirement -> reservation -> transaction.
    m = db.scalar(
        select(Material)
        .where(Material.id == r.material_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    req = (
        db.scalar(
            select(BuyerRequirement)
            .where(BuyerRequirement.id == r.requirement_id)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if r.requirement_id
        else None
    )
    r = db.scalar(
        select(Reservation)
        .where(Reservation.id == r.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    target = {
        "confirm": "confirmed",
        "cancel": "cancelled",
        "transfer": "transferred",
        "complete": "completed",
    }[data.action]
    if r.status == target:
        return reservation_out(db, r, user)
    allowed = {
        "confirm": ("pending",),
        "cancel": ("pending", "confirmed"),
        "transfer": ("confirmed",),
        "complete": ("transferred",),
    }
    if r.status not in allowed[data.action]:
        raise AppError(409, "INVALID_TRANSITION")
    quantity = r.quantity_kg
    if data.action == "confirm":
        if m.status not in BUYER_VISIBLE or m.confirmed_at is None:
            raise AppError(409, "PRECONDITION_FAILED")
        check_stock(m, quantity)
        if req:
            check_requirement(req, m, quantity, r.agreed_price_per_kg)
            req.remaining_demand_kg -= quantity
        m.available_kg -= quantity
        m.held_kg += quantity
    elif data.action == "cancel":
        if r.status == "confirmed":
            m.held_kg -= quantity
            m.available_kg += quantity
            if req:
                req.remaining_demand_kg += quantity
        r.cancel_reason, r.cancelled_by_role = data.reason, user.role.value
    elif data.action == "transfer":
        actual = data.transferred_kg if data.transferred_kg is not None else quantity
        if actual > quantity:
            raise validation_error("transferred_kg", "out_of_range", "Передача превышает резерв.")
        m.held_kg -= quantity
        m.transferred_kg += actual
        m.available_kg += quantity - actual
        if req:
            req.remaining_demand_kg += quantity - actual
        db.add(
            Transaction(
                reservation_id=r.id,
                transferred_kg=actual,
                sale_amount_kgs=(actual * r.agreed_price_per_kg).quantize(Decimal(".01")),
            )
        )
    else:
        t = db.scalar(
            select(Transaction).where(Transaction.reservation_id == r.id).with_for_update()
        )
        t.receipt_confirmed_at = utcnow()
    r.status = target
    refresh_status(m)
    db.flush()
    return reservation_out(db, r, user)


def internal_use(db, user, raw_id, data):
    m = get_owned(db, user, raw_id, lock=True)
    if m.status not in BUYER_VISIBLE or m.confirmed_at is None:
        raise AppError(409, "INVALID_TRANSITION")
    check_stock(m, data.quantity_kg)
    m.available_kg -= data.quantity_kg
    m.internally_used_kg += data.quantity_kg
    refresh_status(m)
    record = ImpactRecord(
        material_id=m.id,
        author_id=user.id,
        kind="internal_use",
        quantity_kg=data.quantity_kg,
        basis=data.basis,
        used_on=data.used_on or utcnow().date(),
    )
    db.add(record)
    db.flush()
    return {"impact_record_id": record.id, "material": material_out(m)}


def confirm_reuse(db, user, raw_id, data):
    t = db.get(Transaction, parse_uuid_or_404(raw_id))
    if t is None:
        raise not_found()
    r = owned_reservation(db, user, str(t.reservation_id))
    if r.status != "completed":
        raise AppError(409, "INVALID_TRANSITION")
    t = db.scalar(
        select(Transaction)
        .where(Transaction.id == t.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    remaining = t.transferred_kg - t.confirmed_reuse_kg
    if data.reused_kg > remaining:
        raise AppError(422, "VALIDATION_ERROR", details={"max_reusable_kg": f"{remaining:.3f}"})
    t.confirmed_reuse_kg += data.reused_kg
    record = ImpactRecord(
        material_id=r.material_id,
        transaction_id=t.id,
        author_id=user.id,
        kind="confirmed_reuse",
        quantity_kg=data.reused_kg,
        basis=data.basis,
        used_on=data.reused_on or utcnow().date(),
    )
    db.add(record)
    db.flush()
    return {"impact_record_id": record.id, "transaction": TransactionOut.model_validate(t)}
