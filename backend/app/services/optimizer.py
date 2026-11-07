"""MILP on integer grams; Decimal accounting and independent feasibility validation."""

from dataclasses import dataclass
from decimal import ROUND_FLOOR, Decimal
from time import monotonic

import numpy as np
from scipy.optimize import Bounds, LinearConstraint, milp
from scipy.sparse import lil_matrix

from app.services.matching import RULES_VERSION, compatibility, components


@dataclass(frozen=True)
class Edge:
    material: str
    option: str
    direction: str
    requirement: str | None
    upper: Decimal
    minimum: Decimal
    value: Decimal
    cost: Decimal
    score: int


def build_edges(materials, requirements, assumptions, organizations):
    edges, capacities, excluded = [], {}, []
    for m in materials:
        for r in requirements:
            reasons, upper = compatibility(m, r)
            cost = assumptions.delivery_cost_per_kg
            if cost is None:
                reasons.append("COST_UNKNOWN")
            if reasons:
                excluded.append(dict(material_id=str(m.id), option_id=str(r.id), reasons=reasons))
                continue
            if m.price_per_kg <= cost:
                excluded.append(
                    dict(
                        material_id=str(m.id), option_id=str(r.id), reasons=["NON_POSITIVE_MARGIN"]
                    )
                )
                continue
            key = "req:" + str(r.id)
            capacities[key] = r.remaining_demand_kg
            edges.append(
                Edge(
                    str(m.id),
                    key,
                    "recycling"
                    if organizations[r.organization_id].activity_type == "recycler"
                    else "sale",
                    str(r.id),
                    upper,
                    r.min_kg,
                    m.price_per_kg,
                    cost,
                    sum(components(m, r).values()),
                )
            )
        for direction in ("internal_use", "recycling"):
            estimate = getattr(assumptions, direction)
            if (
                estimate is None
                or estimate.capacity_kg <= 0
                or estimate.value_per_kg <= estimate.cost_per_kg
            ):
                excluded.append(
                    dict(
                        material_id=str(m.id),
                        option_id=direction,
                        reasons=["MISSING_OR_NON_POSITIVE_ESTIMATE"],
                    )
                )
                continue
            capacities[direction] = estimate.capacity_kg
            edges.append(
                Edge(
                    str(m.id),
                    direction,
                    direction,
                    None,
                    min(m.available_kg, estimate.capacity_kg),
                    Decimal(0),
                    estimate.value_per_kg,
                    estimate.cost_per_kg,
                    0,
                )
            )
    return sorted(edges, key=lambda e: (e.material, e.option)), capacities, excluded


def greedy(edges, stock, capacities):
    available, demand = stock.copy(), capacities.copy()
    result = [Decimal(0)] * len(edges)
    order = sorted(
        range(len(edges)), key=lambda i: (edges[i].material, -edges[i].score, edges[i].option)
    )
    for i in order:
        e = edges[i]
        kg = min(available[e.material], demand[e.option], e.upper)
        if kg <= 0 or kg < e.minimum:
            continue
        result[i] = kg
        available[e.material] -= kg
        demand[e.option] -= kg
    return result


def validate_plan(edges, quantities, stock, capacities):
    available, demand = stock.copy(), capacities.copy()
    for e, kg in zip(edges, quantities, strict=True):
        if kg < 0 or kg > e.upper or kg % Decimal(".001") or (kg > 0 and kg < e.minimum):
            raise ValueError("invalid allocation")
        available[e.material] -= kg
        demand[e.option] -= kg
    if any(v < 0 for v in (*available.values(), *demand.values())):
        raise ValueError("capacity exceeded")
    return available


def value(edges, quantities):
    return sum(
        ((e.value - e.cost) * q).quantize(Decimal(".01"))
        for e, q in zip(edges, quantities, strict=True)
    )


def solve(edges, stock, capacities, timeout):
    baseline = greedy(edges, stock, capacities)
    validate_plan(edges, baseline, stock, capacities)
    if not edges:
        return [], baseline, "optimal"
    # Integer grams plus binary activation, avoiding HiGHS semi-integer upper-bound caps.
    n = len(edges)
    stock_keys, demand_keys = list(stock), list(capacities)
    count = len(stock_keys) + len(demand_keys)
    matrix = lil_matrix((count + 2 * n, 2 * n), dtype=float)
    upper = np.zeros(count + 2 * n)
    upper[:count] = [float(v * 1000) for v in (*stock.values(), *capacities.values())]
    for i, edge in enumerate(edges):
        matrix[stock_keys.index(edge.material), i] = 1
        matrix[len(stock_keys) + demand_keys.index(edge.option), i] = 1
        matrix[count + 2 * i, i] = 1
        matrix[count + 2 * i, n + i] = -int(edge.upper * 1000)
        matrix[count + 2 * i + 1, i] = -1
        matrix[count + 2 * i + 1, n + i] = int(edge.minimum * 1000)
    try:
        result = milp(
            c=[-float(e.value - e.cost) / 1000 for e in edges] + [0] * n,
            integrality=np.ones(2 * n),
            bounds=Bounds(np.zeros(2 * n), [int(e.upper * 1000) for e in edges] + [1] * n),
            constraints=LinearConstraint(matrix.tocsc(), np.full(count + 2 * n, -np.inf), upper),
            options={"time_limit": timeout, "mip_rel_gap": 0.0},
        )
    except (ValueError, RuntimeError):
        return baseline, baseline, "heuristic"
    if result.x is None:
        return baseline, baseline, "heuristic"
    quantities = [
        max(Decimal(0), Decimal(str(x)).to_integral_value(rounding=ROUND_FLOOR) / 1000)
        for x in result.x[:n]
    ]
    quantities = [
        q if q >= e.minimum else Decimal(0) for e, q in zip(edges, quantities, strict=True)
    ]
    try:
        validate_plan(edges, quantities, stock, capacities)
    except ValueError:
        return baseline, baseline, "heuristic"
    if value(edges, quantities) < value(edges, baseline):
        return baseline, baseline, "heuristic"
    return quantities, baseline, "optimal" if result.status == 0 else "feasible"


def optimize(materials, requirements, assumptions, organizations, timeout):
    start = monotonic()
    edges, capacities, excluded = build_edges(materials, requirements, assumptions, organizations)
    stock = {str(m.id): m.available_kg for m in materials}
    quantities, baseline, status = solve(edges, stock, capacities, timeout)
    remainder = validate_plan(edges, quantities, stock, capacities)
    allocations = [
        dict(
            material_id=e.material,
            direction=e.direction,
            requirement_id=e.requirement,
            quantity_kg=f"{q:.3f}",
            unit_value_kgs=f"{e.value:.2f}",
            unit_cost_kgs=f"{e.cost:.2f}",
            net_value_kgs=f"{((e.value - e.cost) * q).quantize(Decimal('.01')):.2f}",
            explanation=(
                "Положительная ожидаемая ценность; учтены остаток, спрос и минимальный объём."
            ),
        )
        for e, q in zip(edges, quantities, strict=True)
        if q > 0
    ]
    objective, base = value(edges, quantities), value(edges, baseline)
    return dict(
        status=status,
        method="greedy-v1" if status == "heuristic" else "scipy_milp",
        algorithm_version="allocation-grams-v1",
        rules_version=RULES_VERSION,
        label="expected",
        objective_kgs=f"{objective:.2f}",
        baseline=dict(method="baseline-v1", value_kgs=f"{base:.2f}"),
        delta_vs_baseline_kgs=f"{objective - base:.2f}",
        allocations=allocations,
        remainder=[dict(material_id=k, remainder_kg=f"{v:.3f}") for k, v in remainder.items()],
        input_versions=[dict(material_id=str(m.id), version=m.version) for m in materials],
        assumptions={**assumptions.model_dump(mode="json"), "origin": "user_supplied"},
        excluded_options=excluded,
        solve_time_ms=int((monotonic() - start) * 1000),
        is_stale=False,
    )
