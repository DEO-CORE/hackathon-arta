from decimal import Decimal
from uuid import UUID

from sqlalchemy import select

from app.core.errors import AppError, not_found
from app.models import Material, Organization
from app.models.commerce import BuyerRequirement
from app.models.planning import Allocation, OptimizationRun
from app.schemas.commerce import RequirementOut
from app.schemas.planning import Assumptions
from app.services.materials import BUYER_VISIBLE, get_owned, parse_uuid_or_404
from app.services.optimizer import optimize


def demand_snapshot(r):
    return RequirementOut.model_validate(r).model_dump(mode="json")


def material_snapshot(m):
    return dict(
        version=m.version,
        material_type=m.material_type,
        condition=m.condition,
        city=m.city,
        price_per_kg=f"{m.price_per_kg:.2f}" if m.price_per_kg is not None else None,
        available_kg=f"{m.available_kg:.3f}",
        status=m.status.value,
        confirmed_at=m.confirmed_at.isoformat() if m.confirmed_at else None,
    )


def inputs(db, user, ids):
    materials = [get_owned(db, user, str(i)) for i in sorted(ids)]
    if any(m.confirmed_at is None or m.status not in BUYER_VISIBLE for m in materials):
        raise AppError(
            409, "PRECONDITION_FAILED", details={"reason": "MATERIAL_NOT_CONFIRMED_OR_AVAILABLE"}
        )
    requirements = list(
        db.scalars(
            select(BuyerRequirement)
            .where(
                BuyerRequirement.active.is_(True),
                BuyerRequirement.organization_id != user.organization_id,
            )
            .order_by(BuyerRequirement.id)
        ).all()
    )
    if len(requirements) > 100:
        raise AppError(
            422, "VALIDATION_ERROR", details={"reason": "TOO_MANY_REQUIREMENTS", "maximum": 100}
        )
    organizations = {
        o.id: o
        for o in db.scalars(
            select(Organization).where(
                Organization.id.in_({r.organization_id for r in requirements})
            )
        )
    }
    return materials, requirements, organizations


def run_out(db, run):
    stale = False
    for raw_id, snapshot in run.snapshot["materials"].items():
        m = db.get(Material, UUID(raw_id))
        stale |= m is None or material_snapshot(m) != snapshot
    current = {
        str(r.id): demand_snapshot(r)
        for r in db.scalars(
            select(BuyerRequirement).where(
                BuyerRequirement.active.is_(True),
                BuyerRequirement.organization_id != run.organization_id,
            )
        )
    }
    stale |= current != run.snapshot["requirements"]
    return {**run.result, "id": str(run.id), "created_at": run.created_at, "is_stale": stale}


def create_run(db, user, data, settings):
    materials, requirements, organizations = inputs(db, user, data.material_ids)
    snapshot = dict(
        materials={str(m.id): material_snapshot(m) for m in materials},
        requirements={str(r.id): demand_snapshot(r) for r in requirements},
    )
    result = optimize(
        materials,
        requirements,
        data.assumptions or Assumptions(),
        organizations,
        settings.optimization_timeout_seconds,
    )
    run = OptimizationRun(organization_id=user.organization_id, snapshot=snapshot, result=result)
    db.add(run)
    db.flush()
    for row in result["allocations"]:
        values = row.copy()
        values["material_id"] = UUID(values["material_id"])
        values["requirement_id"] = (
            UUID(values["requirement_id"]) if values["requirement_id"] else None
        )
        for field in ("quantity_kg", "unit_value_kgs", "unit_cost_kgs", "net_value_kgs"):
            values[field] = Decimal(values[field])
        db.add(Allocation(run_id=run.id, **values))
    db.commit()
    return run_out(db, run)


def get_run(db, user, raw_id):
    run = db.get(OptimizationRun, parse_uuid_or_404(raw_id))
    if run is None or run.organization_id != user.organization_id:
        raise not_found()
    return run_out(db, run)
