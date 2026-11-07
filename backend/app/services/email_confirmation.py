"""Email confirmation by one-time code (docs/api.md 23).

The code and its hash are never logged or returned. Demo exception (A23-12): with
DEMO_MODE=true the 4-digit code 7777 confirms a pending account; no email is sent.
"""

import hashlib
import hmac
import logging
import re
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import AppError
from app.integrations.mail import Mailer
from app.models import EmailCode, User
from app.schemas.auth import UserOut

logger = logging.getLogger("arta.email")

DEMO_CODE = "7777"  # accepted only when DEMO_MODE=true (never in production)
DEMO_AUTO_CONFIRM_EMAIL = "seller@demo.arta"
_CODE_RE = re.compile(r"[0-9]{6}")
_DEMO_CODE_RE = re.compile(r"[0-9]{4}")


def _now() -> datetime:
    return datetime.now(UTC)


def _hash(settings: Settings, user_id: UUID, code: str) -> str:
    key = settings.email_code_hmac_key.get_secret_value().encode()  # type: ignore[union-attr]
    return hmac.new(key, f"{user_id}:{code}".encode(), hashlib.sha256).hexdigest()


def _validation_error(message: str) -> AppError:
    return AppError(
        422,
        "VALIDATION_ERROR",
        details={"errors": [{"field": "code", "code": "invalid_value", "message": message}]},
    )


def check_delivery_available(settings: Settings, mailer: Mailer | None) -> None:
    """503 when real delivery is not configured; demo mode needs no delivery."""
    if settings.demo_mode:
        return
    if mailer is None or settings.email_code_hmac_key is None:
        raise AppError(503, "EMAIL_DELIVERY_UNAVAILABLE")


def request_code(db: Session, settings: Settings, email: str) -> str | None:
    """Create a fresh code for an existing unconfirmed user.

    Returns the plaintext code for the mailer, or None when nothing must be sent (unknown
    email, already confirmed, locked, demo mode). The caller answers 202 in every case.
    """
    if settings.demo_mode:
        return None
    user = db.scalar(select(User).where(User.email == email))
    if user is None or user.email_confirmed or not user.active:
        return None
    now = _now()
    latest = db.scalar(
        select(EmailCode)
        .where(EmailCode.user_id == user.id)
        .order_by(EmailCode.created_at.desc())
        .limit(1)
    )
    if latest is not None and latest.locked_until and latest.locked_until > now:
        return None
    db.execute(
        update(EmailCode)
        .where(EmailCode.user_id == user.id, EmailCode.active.is_(True))
        .values(active=False)
    )
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(
        EmailCode(
            user_id=user.id,
            code_hash=_hash(settings, user.id, code),
            expires_at=now + timedelta(seconds=settings.email_code_ttl_seconds),
        )
    )
    db.commit()
    return code


def deliver(mailer: Mailer, email: str, code: str) -> None:
    try:
        mailer.send_code(email, code)
    except Exception:  # noqa: BLE001 - provider failure must not leak details or the code
        logger.error("Email code delivery failed")


def _confirm(db: Session, user: User) -> UserOut:
    if not user.email_confirmed:
        user.email_confirmed = True
        user.email_confirmed_at = _now()
        db.commit()
    return UserOut.model_validate(user)


def verify_code(db: Session, settings: Settings, email: str, raw_code: str) -> UserOut:
    code = raw_code.strip()
    if settings.demo_mode and _DEMO_CODE_RE.fullmatch(code):
        user = db.scalar(select(User).where(User.email == email))
        if code == DEMO_CODE and user is not None and user.active:
            return _confirm(db, user)
        raise AppError(409, "INVALID_CODE")
    if not _CODE_RE.fullmatch(code):
        raise _validation_error("Код состоит из 6 цифр.")

    user = db.scalar(select(User).where(User.email == email).with_for_update())
    if user is None or not user.active or settings.email_code_hmac_key is None:
        raise AppError(409, "INVALID_CODE")
    row = db.scalar(
        select(EmailCode)
        .where(EmailCode.user_id == user.id)
        .order_by(EmailCode.created_at.desc())
        .limit(1)
        .with_for_update()
    )
    now = _now()
    if row is None:
        raise AppError(409, "INVALID_CODE")
    matches = hmac.compare_digest(row.code_hash, _hash(settings, user.id, code))

    if user.email_confirmed:
        # Repeat with the right code is idempotent (A23-9); anything else is a plain mismatch.
        if matches and row.consumed_at is not None:
            return UserOut.model_validate(user)
        raise AppError(409, "INVALID_CODE")

    if row.locked_until and row.locked_until > now:
        retry = max(1, int((row.locked_until - now).total_seconds()) + 1)
        raise AppError(
            429,
            "RATE_LIMITED",
            details={"retry_after_seconds": retry},
            headers={"Retry-After": str(retry)},
        )
    if not row.active:
        raise AppError(409, "INVALID_CODE")
    if row.expires_at <= now:
        raise AppError(409, "CODE_EXPIRED")
    if matches:
        row.active = False
        row.consumed_at = now
        return _confirm(db, user)

    row.failed_attempts += 1
    left = max(0, settings.email_code_max_attempts - row.failed_attempts)
    if left == 0:
        row.active = False
        row.locked_until = now + timedelta(seconds=settings.email_code_lock_seconds)
    db.commit()
    raise AppError(409, "INVALID_CODE", details={"attempts_left": left})
