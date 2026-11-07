import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.core.request_context import get_request_id
from app.models import AuditLog


def record(
    db: Session,
    action: str,
    *,
    actor_user_id: uuid.UUID | None = None,
    organization_id: uuid.UUID | None = None,
    target_type: str | None = None,
    target_id: object | None = None,
    details: dict[str, Any] | None = None,
) -> None:
    """Append an audit row inside the caller's transaction. details: no secrets or contacts."""
    db.add(
        AuditLog(
            actor_user_id=actor_user_id,
            organization_id=organization_id,
            action=action,
            target_type=target_type,
            target_id=str(target_id) if target_id is not None else None,
            details=details,
            request_id=get_request_id(),
        )
    )
