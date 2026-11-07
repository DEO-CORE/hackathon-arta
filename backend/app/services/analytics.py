from decimal import Decimal

from sqlalchemy import select

from app.models import Material
from app.models.commerce import ImpactRecord, Reservation, Transaction
from app.models.common import utcnow
from app.models.enums import Role
from app.models.planning import OptimizationRun
from app.services.planning import run_out


def summary(db, user, settings):
    owner = (
        Reservation.seller_organization_id
        if user.role == Role.enterprise
        else Reservation.buyer_organization_id
    )
    reservations = list(db.scalars(select(Reservation).where(owner == user.organization_id)))
    states = {r.id: r.status for r in reservations}
    transactions = list(
        db.scalars(select(Transaction).where(Transaction.reservation_id.in_(states)))
    )
    revenue = sum(
        (t.sale_amount_kgs for t in transactions if states[t.reservation_id] == "completed"),
        Decimal(0),
    )
    reuse = sum((t.confirmed_reuse_kg for t in transactions), Decimal(0))
    result = dict(
        role_view=user.role.value,
        is_demo=settings.demo_mode,
        generated_at=utcnow(),
        confirmed_reuse_kg=f"{reuse:.3f}",
    )
    if user.role == Role.buyer:
        return {
            **result,
            "received_kg": f"{sum((t.transferred_kg for t in transactions), Decimal(0)):.3f}",
            "spent_kgs": f"{revenue:.2f}",
            "active_reservations_count": sum(
                r.status in ("pending", "confirmed") for r in reservations
            ),
        }
    materials = list(
        db.scalars(select(Material).where(Material.organization_id == user.organization_id))
    )
    totals = {
        field: sum((getattr(m, field) for m in materials), Decimal(0))
        for field in ("total_kg", "available_kg", "held_kg", "transferred_kg", "internally_used_kg")
    }
    internal = sum(
        (
            i.quantity_kg
            for i in db.scalars(
                select(ImpactRecord).where(
                    ImpactRecord.material_id.in_([m.id for m in materials]),
                    ImpactRecord.kind == "internal_use",
                )
            )
        ),
        Decimal(0),
    )
    distributed = totals["held_kg"] + totals["transferred_kg"]
    run = db.scalar(
        select(OptimizationRun)
        .where(OptimizationRun.organization_id == user.organization_id)
        .order_by(OptimizationRun.created_at.desc(), OptimizationRun.id)
        .limit(1)
    )
    forecast = None
    if run:
        plan = run_out(db, run)
        expected_remainder = sum(Decimal(r["remainder_kg"]) for r in plan["remainder"])
        forecast = dict(
            run_id=str(run.id),
            label="expected",
            expected_net_value_kgs=plan["objective_kgs"],
            expected_remainder_kg=f"{expected_remainder:.3f}",
            is_stale=plan["is_stale"],
        )
    efficiency = distributed / totals["total_kg"] * 100 if totals["total_kg"] else Decimal(0)
    return {
        **result,
        "registered_kg": f"{totals['total_kg']:.3f}",
        "available_kg": f"{totals['available_kg']:.3f}",
        "distributed_kg": f"{distributed:.3f}",
        "internally_used_kg": f"{totals['internally_used_kg']:.3f}",
        "confirmed_reuse_kg": f"{reuse + internal:.3f}",
        "revenue_kgs": f"{revenue:.2f}",
        "allocation_efficiency_pct": f"{efficiency:.2f}",
        "forecast": forecast,
    }
