"""Email confirmation by code (docs/api.md 23). Real PostgreSQL; mail adapter is a fake."""

import logging
import re

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, text

from app.api.auth import get_mailer
from app.core.config import Settings
from tests.integration.conftest import _test_url, register

PASSWORD = "correct-horse-battery"  # noqa: S105


class FakeMailer:
    def __init__(self) -> None:
        self.sent: list[tuple[str, str]] = []

    def send_code(self, to_email: str, code: str) -> None:
        self.sent.append((to_email, code))


@pytest.fixture
def mailer():
    return FakeMailer()


def _client(make_app, mailer):
    app = make_app()
    app.dependency_overrides[get_mailer] = lambda: mailer
    return TestClient(app, raise_server_exceptions=False), app


@pytest.fixture
def mc(make_app, mailer):
    c, app = _client(make_app, mailer)
    with c:
        c.app_ref = app
        yield c


def _sql(statement: str, **params):
    engine = create_engine(_test_url())
    with engine.begin() as conn:
        result = conn.execute(text(statement), params)
        rows = result.fetchall() if result.returns_rows else []
    engine.dispose()
    return rows


def _pending(client, email="new@example.test"):
    register(client, "buyer", email=email, confirm=False, activity_type="workshop")
    return email


def _send(client, email):
    return client.post("/auth/email-code/send", json={"email": email})


def _verify(client, email, code):
    return client.post("/auth/email-code/verify", json={"email": email, "code": code})


def _login(client, email, password=PASSWORD):
    return client.post("/auth/login", json={"email": email, "password": password})


def _wrong(code: str) -> str:
    return "000000" if code != "000000" else "111111"


def test_login_blocked_until_confirmed_only_after_correct_password(mc):
    email = _pending(mc)
    r = _login(mc, email)
    assert r.status_code == 403 and r.json()["error"]["code"] == "EMAIL_NOT_CONFIRMED"
    assert "access_token" not in r.text
    r = _login(mc, email, "wrong-password-123")
    assert r.status_code == 401 and r.json()["error"]["code"] == "INVALID_CREDENTIALS"
    assert _login(mc, "nobody@example.test").status_code == 401


def test_register_shows_unconfirmed_user(mc):
    r = mc.post(
        "/auth/register",
        json={
            "email": "u@example.test",
            "password": PASSWORD,
            "role": "buyer",
            "organization": {"name": "О", "city": "Бишкек", "activity_type": "workshop"},
        },
    )
    assert r.json()["user"]["email_confirmed"] is False
    assert r.json()["user"]["email_confirmed_at"] is None


def test_full_flow_right_code_confirms_and_nothing_leaks(mc, mailer, caplog):
    email = _pending(mc)
    with caplog.at_level(logging.DEBUG):
        s = _send(mc, email)
        assert s.status_code == 202
        assert s.json() == {"status": "accepted", "resend_after_seconds": 60}
        ((to, code),) = mailer.sent
        assert to == email and re.fullmatch(r"[0-9]{6}", code)
        bad = _verify(mc, email, _wrong(code))
        assert bad.status_code == 409
        assert bad.json()["error"]["code"] == "INVALID_CODE"
        assert bad.json()["error"]["details"] == {"attempts_left": 4}
        ok = _verify(mc, email, code)
    assert ok.status_code == 200
    assert ok.json()["user"]["email_confirmed"] is True
    assert ok.json()["user"]["email_confirmed_at"] is not None
    assert "access_token" not in ok.text
    for body in (s.text, bad.text, ok.text, caplog.text):
        assert code not in body
    stored = _sql("SELECT code_hash FROM email_codes")[0][0]
    assert code not in stored and len(stored) == 64
    assert _login(mc, email).status_code == 200
    # Repeat with the same code is idempotent (A23-9); a different code is a mismatch.
    assert _verify(mc, email, code).status_code == 200
    assert _verify(mc, email, _wrong(code)).status_code == 409


def test_send_is_202_without_revealing_accounts(mc, mailer):
    known = _pending(mc)
    confirmed = register(mc, "buyer", activity_type="workshop")["email"]
    answers = [_send(mc, e) for e in (known, "ghost@example.test", confirmed)]
    assert [a.status_code for a in answers] == [202, 202, 202]
    assert answers[0].json() == answers[1].json() == answers[2].json()
    assert [to for to, _ in mailer.sent] == [known]  # nothing sent to unknown or confirmed
    ghost = _verify(mc, "ghost@example.test", "123456")
    assert ghost.status_code == 409 and ghost.json()["error"]["code"] == "INVALID_CODE"
    assert ghost.json()["error"]["details"] is None


def test_expired_code(mc, mailer):
    email = _pending(mc)
    _send(mc, email)
    code = mailer.sent[0][1]
    _sql("UPDATE email_codes SET expires_at = now() - interval '1 second'")
    r = _verify(mc, email, code)
    assert r.status_code == 409 and r.json()["error"]["code"] == "CODE_EXPIRED"
    assert _login(mc, email).status_code == 403


def test_five_wrong_attempts_lock_even_the_right_code(mc, mailer):
    email = _pending(mc)
    _send(mc, email)
    code = mailer.sent[0][1]
    lefts = []
    for _ in range(5):
        r = _verify(mc, email, _wrong(code))
        assert r.status_code == 409
        lefts.append(r.json()["error"]["details"]["attempts_left"])
    assert lefts == [4, 3, 2, 1, 0]
    r = _verify(mc, email, code)
    assert r.status_code == 429 and r.json()["error"]["code"] == "RATE_LIMITED"
    assert int(r.headers["Retry-After"]) >= 1
    assert r.json()["error"]["details"]["retry_after_seconds"] >= 1
    assert _login(mc, email).status_code == 403
    # While locked, a new send issues no code (no bypass of the lock).
    mc.app_ref.state.limiter.reset()
    assert _send(mc, email).status_code == 202
    assert len(mailer.sent) == 1


def test_resend_cooldown_and_hourly_limit(mc, mailer):
    email = _pending(mc)
    assert _send(mc, email).status_code == 202
    r = _send(mc, email)
    assert r.status_code == 429 and r.json()["error"]["code"] == "RATE_LIMITED"
    assert int(r.headers["Retry-After"]) >= 1
    # Same answer for an unknown email: the limit does not depend on the account.
    assert _send(mc, "ghost@example.test").status_code == 202
    assert _send(mc, "ghost@example.test").status_code == 429


def test_new_code_invalidates_previous(mc, mailer):
    email = _pending(mc)
    _send(mc, email)
    mc.app_ref.state.limiter.reset()
    _send(mc, email)
    old, new = mailer.sent[0][1], mailer.sent[1][1]
    assert _sql("SELECT count(*) FROM email_codes WHERE active")[0][0] == 1
    if old != new:
        assert _verify(mc, email, old).status_code == 409
        assert _login(mc, email).status_code == 403
    assert _verify(mc, email, new).status_code == 200


def test_code_format_validation_and_no_demo_code_outside_demo(mc):
    email = _pending(mc)
    for bad in ("12ab56", "12345", "1234567", "", "7777"):
        r = _verify(mc, email, bad)
        assert r.status_code == 422, bad
        assert r.json()["error"]["details"]["errors"][0]["field"] == "code"
    assert _verify(mc, email, "777777").status_code == 409  # not special either
    assert _login(mc, email).status_code == 403
    assert _verify(mc, "not-an-email", "123456").status_code == 422


def test_delivery_unavailable_without_provider_is_503_for_any_email(make_app):
    with TestClient(make_app(), raise_server_exceptions=False) as c:
        email = _pending(c)
        known = _send(c, email)
        c.app.state.limiter.reset()
        unknown = _send(c, "ghost@example.test")
    for r in (known, unknown):
        assert r.status_code == 503
        assert r.json()["error"]["code"] == "EMAIL_DELIVERY_UNAVAILABLE"
    assert known.json()["error"]["message"] == unknown.json()["error"]["message"]
    assert _sql("SELECT count(*) FROM email_codes")[0][0] == 0


def test_missing_hmac_key_blocks_delivery(make_app, mailer, monkeypatch):
    monkeypatch.delenv("EMAIL_CODE_HMAC_KEY")
    c, _ = _client(make_app, mailer)
    with c:
        email = _pending(c)
        r = _send(c, email)
    assert r.status_code == 503 and mailer.sent == []


def test_demo_code_7777_only_in_demo_mode(make_app, mailer, monkeypatch):
    monkeypatch.setenv("DEMO_MODE", "true")
    c, _ = _client(make_app, mailer)
    with c:
        email = _pending(c)
        assert _login(c, email).status_code == 403
        assert _send(c, email).status_code == 202
        assert mailer.sent == []  # demo mode never sends real email
        assert _verify(c, email, "1234").json()["error"]["code"] == "INVALID_CODE"
        assert _verify(c, "ghost@example.test", "7777").status_code == 409
        assert _verify(c, email, "7777").status_code == 200
        assert _login(c, email).status_code == 200
        assert _verify(c, email, "7777").status_code == 200  # idempotent


def test_demo_seller_logs_in_without_code_only_in_demo(make_app, mailer, monkeypatch):
    c, _ = _client(make_app, mailer)
    with c:
        register(c, "enterprise", email="seller@demo.arta", confirm=False)
        assert _login(c, "seller@demo.arta").status_code == 403
    _sql("DELETE FROM users")
    monkeypatch.setenv("DEMO_MODE", "true")
    c, _ = _client(make_app, mailer)
    with c:
        register(c, "enterprise", email="seller@demo.arta", confirm=False)
        assert _login(c, "seller@demo.arta").status_code == 200
        register(c, "buyer", email="other@demo.arta", confirm=False)
        assert _login(c, "other@demo.arta").status_code == 403


def _settings(**env) -> Settings:
    base = {
        "database_url": "postgresql://u@localhost/x",
        "jwt_secret": "j" * 32,
    }
    return Settings(_env_file=None, **{**base, **env})


def test_startup_rejects_demo_with_production_signs():
    with pytest.raises(ValidationError):
        _settings(demo_mode=True, app_env="production")
    with pytest.raises(ValidationError):
        _settings(demo_mode=True, mail_provider="smtp", smtp_host="h", smtp_from="a@b.c")
    with pytest.raises(ValidationError):
        _settings(mail_provider="smtp")  # smtp without host/from
    assert _settings(demo_mode=True).demo_mode is True
