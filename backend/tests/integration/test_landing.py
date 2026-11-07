import hashlib
import uuid
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_engine
from app.models import Organization
from app.models.common import utcnow
from app.models.password_reset import PasswordReset
from tests.integration.conftest import login_headers, published_material
from tests.integration.test_commerce import action, reserve


def personal(client):
    body = {
        "email": f"{uuid.uuid4()}@example.test",
        "password": "buyer-password-123",
        "role": "buyer",
        "profile": {"name": "Айжан", "city": "Бишкек"},
    }
    response = client.post("/auth/register", json=body)
    assert response.status_code == 201, response.text
    assert response.json()["organization"] is None
    assert response.json()["user"]["organization_id"] is None
    return {
        **body,
        **response.json(),
        "headers": login_headers(client, body["email"], body["password"]),
    }


def test_personal_profile_and_commerce_isolation(client, seller):
    with Session(get_engine()) as db:
        before = db.scalar(select(func.count()).select_from(Organization))
    a, b = personal(client), personal(client)
    with Session(get_engine()) as db:
        assert db.scalar(select(func.count()).select_from(Organization)) == before
    m = published_material(client, seller["headers"])
    r = reserve(client, a, m, quantity="10.000")
    assert r.status_code == 201, r.text
    r = r.json()
    assert r["buyer_user_id"] == a["user"]["id"]
    assert client.get("/reservations", headers=b["headers"]).json()["total"] == 0
    assert action(client, b, r, "cancel").status_code == 404
    assert action(client, seller, r, "confirm").status_code == 200
    response = action(client, seller, r, "transfer")
    assert response.status_code == 200, response.text
    assert response.json()["counterparty_contacts"]["contact_name"] == "Айжан"
    assert action(client, a, r, "complete").status_code == 200
    tx = response.json()["transaction"]
    assert (
        client.post(
            "/transactions/" + tx["id"] + "/reuse-confirmation",
            headers=a["headers"] | {"Idempotency-Key": str(uuid.uuid4())},
            json={"reused_kg": "4.000", "basis": "Сумки"},
        ).status_code
        == 201
    )
    assert (
        client.get("/analytics/summary", headers=a["headers"]).json()["confirmed_reuse_kg"]
        == "4.000"
    )
    assert (
        client.get("/analytics/summary", headers=b["headers"]).json()["confirmed_reuse_kg"]
        == "0.000"
    )
    assert client.get("/public/statistics").json()["confirmed_reuse_kg"] == "4.000"
    req = client.post(
        "/buyer-requirements",
        headers=a["headers"],
        json={
            "material_types": ["cotton"],
            "conditions": ["good"],
            "min_kg": "1.000",
            "max_kg": "5.000",
        },
    )
    assert req.status_code == 201, req.text
    assert client.get("/buyer-requirements", headers=b["headers"]).json()["total"] == 0
    assert (
        client.patch(
            "/buyer-requirements/" + req.json()["id"], headers=b["headers"], json={"active": False}
        ).status_code
        == 404
    )
    matched = client.post("/ai/match", headers=seller["headers"], json={"material_id": m["id"]})
    assert matched.status_code == 200, matched.text
    assert matched.json()["matches"][0]["organization_name"] == "Айжан"


def test_public_catalog_and_signed_photo(client, seller):
    m = published_material(client, seller["headers"])
    page = client.get("/public/materials?q=Хлопковые").json()
    assert page["total"] == 1
    assert "balance" not in page["items"][0]
    assert "confirmed_by" not in page["items"][0]
    assert client.get("/public/materials?page_size=101").status_code == 422
    url = client.get(f"/public/materials/{m['id']}/images/{m['images'][0]['id']}/url").json()["url"]
    assert client.get(url).status_code == 200
    assert client.get(url + "bad").status_code == 404
    client.post(
        "/materials/" + m["id"] + "/archive",
        headers=seller["headers"],
        json={"version": m["version"]},
    )
    assert client.get("/public/materials/" + m["id"]).status_code == 404
    assert client.get(url).status_code == 404


def test_browser_session_csrf_and_logout(client):
    a = personal(client)
    body = {"email": a["email"], "password": a["password"]}
    assert (
        client.post(
            "/auth/session", json=body, headers={"Origin": "https://evil.example"}
        ).status_code
        == 403
    )
    response = client.post("/auth/session", json=body, headers={"Origin": "http://testserver"})
    assert response.status_code == 200
    assert "HttpOnly" in response.headers["set-cookie"]
    assert "access_token" not in response.json()
    assert client.get("/auth/me").json()["user"]["email"] == a["email"]
    assert (
        client.delete("/auth/session", headers={"Origin": "https://evil.example"}).status_code
        == 403
    )
    assert (
        client.delete("/auth/session", headers={"Origin": "http://testserver"}).status_code == 204
    )
    assert client.get("/auth/me").status_code == 401


def test_password_reset_one_time_expiry_and_revocation(client, monkeypatch):
    from app.services import passwords

    monkeypatch.setenv("SMTP_HOST", "mail.example.test")
    monkeypatch.setenv("SMTP_FROM", "arta@example.test")
    get_settings.cache_clear()
    sent = []
    monkeypatch.setattr(
        passwords, "send_reset", lambda email, token, settings: sent.append((email, token))
    )
    a = personal(client)
    first = client.post("/auth/forgot-password", json={"email": a["email"]})
    unknown = client.post("/auth/forgot-password", json={"email": "missing@example.test"})
    assert first.status_code == unknown.status_code == 202
    assert first.json() == unknown.json()
    assert len(sent) == 1
    token = sent[0][1]
    with Session(get_engine()) as db:
        record = db.scalar(select(PasswordReset))
        assert record.token_hash == hashlib.sha256(token.encode()).hexdigest()
        assert record.token_hash != token
    payload = {"token": token, "password": "new-password-12345"}
    assert client.post("/auth/reset-password", json=payload).status_code == 200
    assert client.post("/auth/reset-password", json=payload).status_code == 400
    assert client.get("/auth/me", headers=a["headers"]).status_code == 401
    assert (
        client.post(
            "/auth/login", json={"email": a["email"], "password": a["password"]}
        ).status_code
        == 401
    )
    assert (
        client.post(
            "/auth/login", json={"email": a["email"], "password": payload["password"]}
        ).status_code
        == 200
    )
    client.post("/auth/forgot-password", json={"email": a["email"]})
    with Session(get_engine()) as db:
        record = db.scalar(
            select(PasswordReset).where(
                PasswordReset.token_hash == hashlib.sha256(sent[-1][1].encode()).hexdigest()
            )
        )
        record.expires_at = utcnow() - timedelta(minutes=1)
        db.commit()
    assert (
        client.post(
            "/auth/reset-password", json={"token": sent[-1][1], "password": "another-password123"}
        ).status_code
        == 400
    )
    get_settings.cache_clear()
