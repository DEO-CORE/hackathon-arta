from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.core.config import Settings

# argon2-cffi's PasswordHasher defaults to Argon2id.
_hasher = PasswordHasher()
# Verified against when the email is unknown, to even out response time (api.md 18.9).
_DUMMY_HASH = _hasher.hash("arta-timing-equalizer")

ALLOWED_ALGORITHMS = ["HS256"]


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str | None, password: str) -> bool:
    try:
        return _hasher.verify(password_hash or _DUMMY_HASH, password) and password_hash is not None
    except (VerificationError, InvalidHashError):
        return False


def create_access_token(
    user_id: UUID, settings: Settings, token_version: int = 0
) -> tuple[str, int]:
    expires_in = settings.access_token_minutes * 60
    now = datetime.now(UTC)
    payload = {
        "ver": token_version,
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(seconds=expires_in),
    }
    token = jwt.encode(payload, settings.jwt_secret.get_secret_value(), algorithm="HS256")
    return token, expires_in


def decode_access_token(token: str, settings: Settings) -> UUID | None:
    """Return the user id or None for any invalid token (signature, exp, alg, claims)."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret.get_secret_value(),
            algorithms=ALLOWED_ALGORITHMS,
            options={"require": ["exp", "sub"]},
        )
        return UUID(str(payload["sub"]))
    except (jwt.PyJWTError, ValueError):
        return None
