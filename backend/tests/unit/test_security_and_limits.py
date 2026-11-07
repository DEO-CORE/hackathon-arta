from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
import pytest

from app.core.config import Settings
from app.core.errors import AppError
from app.core.ratelimit import RateLimiter
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from tests.conftest import TEST_JWT_SECRET


def _settings() -> Settings:
    return Settings(database_url="postgresql://x@h/db_test", jwt_secret=TEST_JWT_SECRET)


def test_password_hash_is_argon2id_and_verifies():
    h = hash_password("correct-horse-battery")
    assert h.startswith("$argon2id$")
    assert verify_password(h, "correct-horse-battery")
    assert not verify_password(h, "wrong")
    assert not verify_password(None, "anything")  # unknown user


def test_token_round_trip_and_expiry():
    s = _settings()
    uid = uuid4()
    token, expires_in = create_access_token(uid, s)
    assert expires_in == 3600
    assert decode_access_token(token, s) == uid
    old = jwt.encode(
        {"sub": str(uid), "exp": datetime.now(UTC) - timedelta(seconds=1)}, TEST_JWT_SECRET, "HS256"
    )
    assert decode_access_token(old, s) is None


def test_settings_require_secrets_and_min_length(monkeypatch):
    monkeypatch.delenv("JWT_SECRET", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(ValueError):
        Settings(_env_file=None)
    with pytest.raises(ValueError):
        Settings(_env_file=None, database_url="postgresql://x@h/d", jwt_secret="short")


def test_database_url_gets_psycopg_driver():
    assert _settings().database_url.startswith("postgresql+psycopg://")


def test_rate_limiter_blocks_then_reports_retry_after():
    rl = RateLimiter()
    rl.hit("k", 2, 60)
    rl.hit("k", 2, 60)
    with pytest.raises(AppError) as e:
        rl.hit("k", 2, 60)
    assert e.value.status_code == 429 and int(e.value.headers["Retry-After"]) >= 1
    rl.hit("other", 2, 60)  # keys are independent
