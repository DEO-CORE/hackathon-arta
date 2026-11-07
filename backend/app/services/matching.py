from decimal import Decimal

from app.services.materials import BUYER_VISIBLE

RULES_VERSION = "match-rules-v1"


REASONS = {
    "MATERIAL_NOT_CONFIRMED": "Характеристики партии не подтверждены.",
    "MATERIAL_NOT_AVAILABLE": "У партии нет доступного остатка для продажи.",
    "DEMAND_INACTIVE": "Потребность неактивна.",
    "DEMAND_EXHAUSTED": "Спрос уже удовлетворён или зарезервирован.",
    "DEMAND_INCOMPLETE": "Не указаны допустимые типы или состояния.",
    "UNKNOWN_TYPE": "Тип материала неизвестен.",
    "TYPE_MISMATCH": "Тип материала не подходит покупателю.",
    "UNKNOWN_CONDITION": "Состояние материала неизвестно.",
    "CONDITION_MISMATCH": "Состояние материала не подходит покупателю.",
    "UNKNOWN_APPLICATION": "Нужный способ применения материала не подтверждён.",
    "MIN_LOT_IMPOSSIBLE": "Доступный объём меньше минимального объёма покупки.",
    "PRICE_UNKNOWN": "Цена партии не указана.",
    "PRICE_ABOVE_BUDGET": "Цена партии превышает бюджет покупателя.",
}


def compatibility(m, r):
    """Shared hard filters. Unconfirmed AI suggestions never count as applications."""
    reasons = []
    if m.confirmed_at is None:
        reasons.append("MATERIAL_NOT_CONFIRMED")
    if m.status not in BUYER_VISIBLE or m.available_kg <= 0:
        reasons.append("MATERIAL_NOT_AVAILABLE")
    if not r.active:
        reasons.append("DEMAND_INACTIVE")
    if r.remaining_demand_kg <= 0:
        reasons.append("DEMAND_EXHAUSTED")
    if not r.material_types or not r.conditions:
        reasons.append("DEMAND_INCOMPLETE")
    if m.material_type is None:
        reasons.append("UNKNOWN_TYPE")
    elif m.material_type not in r.material_types:
        reasons.append("TYPE_MISMATCH")
    if m.condition is None:
        reasons.append("UNKNOWN_CONDITION")
    elif m.condition not in r.conditions:
        reasons.append("CONDITION_MISMATCH")
    if r.uses:
        reasons.append("UNKNOWN_APPLICATION")
    upper = min(m.available_kg, r.remaining_demand_kg, r.max_kg)
    if r.min_kg > upper:
        reasons.append("MIN_LOT_IMPOSSIBLE")
    if m.price_per_kg is None:
        reasons.append("PRICE_UNKNOWN")
    elif r.budget_per_kg is not None and m.price_per_kg > r.budget_per_kg:
        reasons.append("PRICE_ABOVE_BUDGET")
    return reasons, max(Decimal(0), upper)


def components(m, r):
    return {
        "city": 30
        if m.city and r.city and m.city.strip().casefold() == r.city.strip().casefold()
        else 0,
        "use": 30,
        "coverage": int(
            (40 * min(m.available_kg / r.remaining_demand_kg, Decimal(1))).quantize(Decimal(1))
        ),
    }


def match(m, requirements, organizations, limit):
    matches, excluded = [], []
    for r in requirements:
        reasons, upper = compatibility(m, r)
        if reasons:
            excluded.append(
                dict(
                    requirement_id=str(r.id),
                    reason_codes=reasons,
                    reasons=[REASONS[code] for code in reasons],
                )
            )
            continue
        scores = components(m, r)
        matches.append(
            dict(
                requirement_id=str(r.id),
                organization_name=organizations[r.organization_id].name,
                score=sum(scores.values()),
                components=scores,
                possible_kg=f"{upper:.3f}",
                city=r.city,
                reasons=["Тип и состояние подходят.", "Объём и цена соответствуют потребности."],
            )
        )
    matches.sort(key=lambda x: (-x["score"], x["requirement_id"]))
    excluded.sort(key=lambda x: x["requirement_id"])
    return dict(
        material_id=str(m.id),
        material_version=m.version,
        rules_version=RULES_VERSION,
        matches=matches[:limit],
        excluded=excluded,
    )
