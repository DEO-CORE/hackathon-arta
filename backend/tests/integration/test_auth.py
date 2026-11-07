import jwt
from sqlalchemy import create_engine, text

from tests.conftest import TEST_JWT_SECRET
from tests.integration.conftest import login_headers, register


def _reg_body(**over):
    body = {
        "email": "Seller@Example.test",
        "password": "correct-horse-battery",
        "role": "enterprise",
        "organization": {"name": "Фабрика", "city": "Бишкек", "activity_type": "garment_factory"},
    }
    body.update(over)
    return body


def test_register_returns_user_and_org_no_token(client):
    r = client.post("/auth/register", json=_reg_body())
    assert r.status_code == 201
    data = r.json()
    assert data["user"]["email"] == "seller@example.test"
    assert data["user"]["role"] == "enterprise"
    assert data["user"]["active"] is True
    assert data["user"]["organization_id"] == data["organization"]["id"]
    assert "access_token" not in r.text and "password" not in r.text
    assert data["organization"]["contacts"] == {
        "contact_name": None,
        "contact_phone": None,
        "contact_email": None,
    }


def test_admin_role_cannot_be_self_assigned(client):
    r = client.post("/auth/register", json=_reg_body(role="admin"))
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0]["field"] == "role"


def test_register_rejects_extra_fields_like_organization_id(client):
    r = client.post("/auth/register", json=_reg_body(organization_id="x"))
    assert r.status_code == 422
    err = r.json()["error"]["details"]["errors"][0]
    assert (err["field"], err["code"]) == ("organization_id", "extra_forbidden")


def test_register_short_password_and_bad_email(client):
    r = client.post("/auth/register", json=_reg_body(password="short", email="nope"))
    assert r.status_code == 422
    fields = {e["field"]: e["code"] for e in r.json()["error"]["details"]["errors"]}
    assert fields == {"email": "invalid_value", "password": "too_short"}


def test_duplicate_email_409_case_insensitive(client):
    assert client.post("/auth/register", json=_reg_body()).status_code == 201
    r = client.post("/auth/register", json=_reg_body(email="SELLER@example.test"))
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "EMAIL_ALREADY_REGISTERED"


def test_password_is_stored_as_argon2id(client):
    client.post("/auth/register", json=_reg_body())
    engine = create_engine(__import__("os").environ["DATABASE_URL"])
    with engine.connect() as c:
        h = c.execute(text("select password_hash from users")).scalar_one()
    engine.dispose()
    assert h.startswith("$argon2id$")
    assert "correct-horse" not in h


def test_login_ok_token_is_hs256_with_60min_expiry(client):
    register(client, "buyer", email="b@example.test")
    r = client.post(
        "/auth/login", json={"email": "B@example.test", "password": "correct-horse-battery"}
    )
    assert r.status_code == 200
    body = r.json()
    assert body["token_type"] == "bearer" and body["expires_in"] == 3600
    claims = jwt.decode(body["access_token"], TEST_JWT_SECRET, algorithms=["HS256"])
    assert claims["exp"] - claims["iat"] == 3600
    assert jwt.get_unverified_header(body["access_token"])["alg"] == "HS256"


def test_login_wrong_password_and_unknown_email_same_401(client):
    register(client, "buyer", email="b@example.test")
    r1 = client.post(
        "/auth/login", json={"email": "b@example.test", "password": "wrong-password-1"}
    )
    r2 = client.post(
        "/auth/login", json={"email": "x@example.test", "password": "wrong-password-1"}
    )
    assert r1.status_code == r2.status_code == 401
    assert r1.json()["error"]["code"] == r2.json()["error"]["code"] == "INVALID_CREDENTIALS"
    assert r1.json()["error"]["message"] == r2.json()["error"]["message"]


def _disable(email: str) -> None:
    engine = create_engine(__import__("os").environ["DATABASE_URL"])
    with engine.begin() as c:
        c.execute(text("update users set active = false where email = :e"), {"e": email})
    engine.dispose()


def test_disabled_account_403_only_after_correct_password(client):
    register(client, "buyer", email="b@example.test")
    _disable("b@example.test")
    ok = client.post(
        "/auth/login", json={"email": "b@example.test", "password": "correct-horse-battery"}
    )
    assert ok.status_code == 403 and ok.json()["error"]["code"] == "ACCOUNT_DISABLED"
    bad = client.post(
        "/auth/login", json={"email": "b@example.test", "password": "wrong-password-1"}
    )
    assert bad.status_code == 401 and bad.json()["error"]["code"] == "INVALID_CREDENTIALS"


def test_token_of_disabled_user_is_401(client):
    acc = register(client, "buyer", email="b@example.test")
    headers = login_headers(client, acc["email"])
    _disable("b@example.test")
    r = client.get("/organizations/me", headers=headers)
    assert r.status_code == 401 and r.json()["error"]["code"] == "UNAUTHENTICATED"


def test_tampered_alg_none_and_wrong_signature_rejected(client):
    acc = register(client, "buyer")
    uid = acc["user"]["id"]
    forged = jwt.encode(
        {"sub": uid, "exp": 9999999999}, "another-secret-another-secret-12345", "HS256"
    )
    none_tok = jwt.encode({"sub": uid, "exp": 9999999999}, None, algorithm="none")
    hs512 = jwt.encode({"sub": uid, "exp": 9999999999}, TEST_JWT_SECRET, "HS512")
    expired = jwt.encode({"sub": uid, "exp": 1}, TEST_JWT_SECRET, "HS256")
    no_exp = jwt.encode({"sub": uid}, TEST_JWT_SECRET, "HS256")
    for tok in (forged, none_tok, hs512, expired, no_exp, "garbage"):
        r = client.get("/organizations/me", headers={"Authorization": f"Bearer {tok}"})
        assert r.status_code == 401, tok


def test_login_rate_limited_with_retry_after(make_app, monkeypatch):
    from fastapi.testclient import TestClient

    monkeypatch.setenv("RATE_LIMIT_LOGIN_PER_EMAIL", "3")
    monkeypatch.setenv("RATE_LIMIT_WINDOW_SECONDS", "60")
    with TestClient(make_app(), raise_server_exceptions=False) as c:
        codes = []
        for _ in range(4):
            r = c.post(
                "/auth/login", json={"email": "x@example.test", "password": "wrong-password-1"}
            )
            codes.append(r.status_code)
        assert codes == [401, 401, 401, 429]
        err = r.json()["error"]
        assert err["code"] == "RATE_LIMITED"
        assert int(r.headers["retry-after"]) >= 1
        assert err["details"]["retry_after_seconds"] == int(r.headers["retry-after"])
    monkeypatch.undo()


def test_organization_get_and_patch(client):
    acc = register(client, "buyer", email="b@example.test", activity_type="workshop")
    h = login_headers(client, acc["email"])
    r = client.get("/organizations/me", headers=h)
    assert r.status_code == 200 and r.json()["id"] == acc["organization"]["id"]

    r = client.patch(
        "/organizations/me",
        json={
            "city": "Ош",
            "contacts": {"contact_name": "Айгуль", "contact_phone": "+996000000000"},
        },
        headers=h,
    )
    assert r.status_code == 200
    assert r.json()["city"] == "Ош"
    assert r.json()["contacts"]["contact_email"] is None

    r = client.patch("/organizations/me", json={"contacts": {"contact_name": "Б"}}, headers=h)
    assert r.json()["contacts"] == {
        "contact_name": "Б",
        "contact_phone": None,
        "contact_email": None,
    }


def test_organization_patch_validation(client):
    acc = register(client, "enterprise")
    h = login_headers(client, acc["email"])
    r = client.patch("/organizations/me", json={}, headers=h)
    assert r.status_code == 422
    assert r.json()["error"]["details"]["errors"][0] == {
        "field": "",
        "code": "no_changes",
        "message": "Укажите хотя бы одно изменяемое поле.",
    }
    r = client.patch("/organizations/me", json={"activity_type": "recycler"}, headers=h)
    assert r.status_code == 422  # recycler only for buyer
    r = client.patch("/organizations/me", json={"name": None}, headers=h)
    assert r.json()["error"]["details"]["errors"][0]["code"] == "null_not_allowed"


def test_buyer_can_become_recycler(client):
    acc = register(client, "buyer")
    h = login_headers(client, acc["email"])
    r = client.patch("/organizations/me", json={"activity_type": "recycler"}, headers=h)
    assert r.status_code == 200 and r.json()["activity_type"] == "recycler"


def test_organizations_are_isolated(client):
    a = register(client, "enterprise")
    b = register(client, "enterprise")
    ha = login_headers(client, a["email"])
    hb = login_headers(client, b["email"])
    client.patch("/organizations/me", json={"name": "Только А"}, headers=ha)
    assert client.get("/organizations/me", headers=hb).json()["name"] != "Только А"
