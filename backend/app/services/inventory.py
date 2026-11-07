"""Single place that derives material status from balances (CLAUDE.md section 5)."""

from decimal import Decimal

from app.models.enums import MaterialStatus
from app.models.material import Material

ZERO = Decimal("0.000")


def balance_is_consistent(m: Material) -> bool:
    parts = (m.available_kg, m.held_kg, m.transferred_kg, m.internally_used_kg)
    return all(p >= 0 for p in parts) and m.total_kg == sum(parts, ZERO)


def derive_published_status(m: Material) -> MaterialStatus:
    """Status of a published (non-draft, non-archived) material from its balance."""
    if m.available_kg == m.total_kg:
        return MaterialStatus.available
    if m.available_kg > 0:
        return MaterialStatus.partially_allocated
    if m.held_kg > 0:
        return MaterialStatus.reserved
    return MaterialStatus.completed


def refresh_status(m: Material) -> None:
    """Recompute status after any balance change. draft/archived are explicit owner states."""
    if m.status in (MaterialStatus.draft, MaterialStatus.archived):
        return
    m.status = derive_published_status(m)


def has_obligations(m: Material) -> bool:
    return m.held_kg > 0 or m.transferred_kg > 0
