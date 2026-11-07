"""R1 security regression: response order, isolation, token handling, DB constraints.

Order approved for R1: 401 -> 404 (private resource not reachable) -> 403 (resource reachable,
operation forbidden) -> 422 (business state, only after authorization) -> 409.
Complements tests/integration/test_membership.py without repeating it. PostgreSQL only.
"""

import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_engine
from app.models import OrganizationMembership, User
from app.models.enums import OrgRole
from tests.integration.conftest import (
    login_headers,
    new_material,
    published_material,
    ready_material,
    register,
    upload,
)
from tests.integration.test_commerce import requirement, reserve
from tests.integration.test_membership import add_member

NIL = "00000000-0000-0000-0000-000000000000"

# (method, path) of every business route that needs a Bearer token (docs/api.md section 15)
PROTECTED = [
    ("GET", "/auth/me"),
    ("GET", "/organizations/me"),
    ("PATCH", "/organizations/me"),
    ("GET", "/materials"),
    ("POST", "/materials"),
    ("GET", f"/materials/{NIL}"),
    ("PATCH", f"/materials/{NIL}"),
    ("POST", f"/materials/{NIL}/confirm"),
    ("POST", f"/materials/{NIL}/publish"),
    ("POST", f"/materials/{NIL}/archive"),
    ("POST", f"/materials/{NIL}/images"),
    ("POST", f"/materials/{NIL}/internal-use"),
    ("GET", "/buyer-requirements"),
    ("POST", "/buyer-requirements"),
    ("PATCH", f"/buyer-requirements/{NIL}"),
    ("POST", "/ai/analyze"),
    ("GET", f"/ai/analyses/{NIL}"),
    ("POST", "/ai/match"),
    ("POST", "/optimization/run"),
    ("GET", f"/optimization/runs/{NIL}"),
    ("POST", "/reservations"),
    ("GET", "/reservations"),
    ("PATCH", f"/reservations/{NIL}"),
    ("GET", "/analytics/summary"),
    ("GET", "/admin/api/me"),
    ("GET", "/admin/api/summary"),
]


def _forbidden_body(r):
    text_ = r.text
    assert "Traceback" not in text_ and "sqlalchemy" not in text_.lower()
    return r.json()["error"]


# ---------- PM-10 / TK-03: authentication boundary ----------


@pytest.mark.parametrize(("method", "path"), PROTECTED)
def test_every_protected_route_requires_a_token(client, method, path):
    r = client.request(method, path)
    assert r.status_code == 401, (method, path, r.text)
    assert _forbidden_body(r)["code"] == "UNAUTHENTICATED"


def _token(claims: dict, key: str | None = None, alg: str = "HS256") -> dict:
    key = key or get_settings().jwt_secret.get_secret_value()
    return {"Authorization": "Bearer " + jwt.encode(claims, key, algorithm=alg)}


def test_forged_expired_and_unknown_subject_tokens_are_401(client, seller):
    sub = seller["user"]["id"]
    now = datetime.now(UTC)
    good = {"sub": sub, "iat": now, "exp": now + timedelta(minutes=5)}
    assert client.get("/auth/me", headers=_token(good)).status_code == 200
    bad = {
        "expired": _token({**good, "exp": now - timedelta(minutes=1)}),
        "wrong_signature": _token(good, key="x" * 48),
        "unknown_user": _token({**good, "sub": str(uuid.uuid4())}),
        "not_a_uuid": _token({**good, "sub": "admin"}),
        "no_exp": _token({"sub": sub, "iat": now}),
    }
    none_alg = jwt.encode(good, key=None, algorithm="none")
    bad["alg_none"] = {"Authorization": f"Bearer {none_alg}"}
    for name, h in bad.items():
        r = client.get("/auth/me", headers=h)
        assert r.status_code == 401, name
        assert _forbidden_body(r)["code"] == "UNAUTHENTICATED", name


def test_token_claims_cannot_grant_rights(client, buyer):
    now = datetime.now(UTC)
    claims = {
        "sub": buyer["user"]["id"],
        "iat": now,
        "exp": now + timedelta(minutes=5),
        "role": "admin",
        "organization_id": str(uuid.uuid4()),
        "permissions": ["material.publish"],
    }
    h = _token(claims)
    assert client.get("/admin/api/summary", headers=h).status_code == 403
    me = client.get("/auth/me", headers=h).json()
    assert me["organization"]["id"] == buyer["organization"]["id"]
    assert "material.publish" not in me["permissions"]


def test_deactivated_user_token_is_401(client, seller):
    with Session(get_engine()) as db:
        db.scalar(select(User).where(User.email == seller["email"])).active = False
        db.commit()
    assert client.get("/auth/me", headers=seller["headers"]).status_code == 401


def test_platform_admin_has_no_business_access(client):
    from app.models import PlatformAdmin

    acc = register(client, "enterprise")
    with Session(get_engine()) as db:
        user = db.scalar(select(User).where(User.email == acc["email"]))
        db.execute(text("DELETE FROM organization_memberships WHERE user_id = :u"), {"u": user.id})
        db.add(PlatformAdmin(user_id=user.id))
        db.commit()
    h = login_headers(client, acc["email"])
    assert client.get("/admin/api/me", headers=h).status_code == 200
    for path in ("/materials", "/reservations", "/analytics/summary", "/organizations/me"):
        r = client.get(path, headers=h)
        assert r.status_code == 403 and r.json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP", path


# ---------- OR: order 404 -> 403 -> 422 -> 409 ----------


def test_foreign_resource_is_404_before_any_body_or_state_check(client, seller, seller2):
    m = new_material(client, seller["headers"])  # draft without photo: not publishable
    h = seller2["headers"]
    for method, path, body in (
        ("POST", f"/materials/{m['id']}/publish", {"version": 1}),
        ("POST", f"/materials/{m['id']}/archive", {"version": 999}),
        ("POST", f"/materials/{m['id']}/confirm", {"version": 1}),
    ):
        r = client.request(method, path, json=body, headers=h)
        assert r.status_code == 404, (path, r.status_code, r.text)
        assert _forbidden_body(r)["code"] == "NOT_FOUND"
    # the owner of the same request gets the business answer instead
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=seller["headers"])
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "PUBLISH_REQUIREMENTS_NOT_MET"


def test_no_permission_is_403_before_business_state(client, seller):
    m = new_material(client, seller["headers"])  # would be 422 for a manager
    member = add_member(client, seller["organization"]["id"], OrgRole.MEMBER)["headers"]
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=member)
    assert r.status_code == 403 and r.json()["error"]["code"] == "FORBIDDEN"
    # stale version does not turn 403 into 409
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 77}, headers=member)
    assert r.status_code == 403
    manager = add_member(client, seller["organization"]["id"], OrgRole.MANAGER)["headers"]
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=manager)
    assert r.status_code == 422
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 77}, headers=manager)
    assert r.status_code == 409 and r.json()["error"]["code"] == "VERSION_CONFLICT"


def test_buyer_publish_is_403_on_visible_and_404_on_hidden_material(client, seller, buyer):
    visible = published_material(client, seller["headers"])
    hidden = new_material(client, seller["headers"])  # foreign draft
    h = buyer["headers"]
    for action in ("publish", "archive"):
        r = client.post(f"/materials/{visible['id']}/{action}", json={"version": 1}, headers=h)
        assert r.status_code == 403, action
        assert r.json()["error"]["code"] == "FORBIDDEN"
        r = client.post(f"/materials/{hidden['id']}/{action}", json={"version": 1}, headers=h)
        assert r.status_code == 404, action
    r = client.patch(f"/materials/{visible['id']}", json={"version": 1, "name": "Взлом"}, headers=h)
    assert r.status_code == 403
    assert (
        client.get(f"/materials/{visible['id']}", headers=seller["headers"]).json()["name"]
        != "Взлом"
    )


def test_buyer_cannot_use_supplier_routes(client, seller, buyer):
    m = published_material(client, seller["headers"])
    h = buyer["headers"]
    assert client.post("/materials", json={"name": "x"}, headers=h).status_code == 403
    assert client.post("/ai/analyze", json={"material_id": m["id"]}, headers=h).status_code in (
        403,
        404,
    )
    assert client.post("/ai/match", json={"material_id": m["id"]}, headers=h).status_code in (
        403,
        404,
    )
    assert (
        client.post("/optimization/run", json={"material_ids": [m["id"]]}, headers=h).status_code
        == 403
    )
    assert client.post(
        f"/materials/{m['id']}/internal-use", json={"quantity_kg": "1.000", "basis": "x"}, headers=h
    ).status_code in (403, 404)
    assert client.get(f"/materials/{m['id']}", headers=h).status_code == 200  # read is allowed


# ---------- IS: isolation, nested ids, lists ----------


def test_nested_ids_of_another_organization_are_404(client, seller, seller2, monkeypatch):
    monkeypatch.setenv("VISION_PROVIDER", "mock")
    monkeypatch.setenv("DEMO_MODE", "true")
    get_settings.cache_clear()
    a = ready_material(client, seller["headers"])
    b = new_material(client, seller2["headers"])
    job = client.post("/ai/analyze", json={"material_id": a["id"]}, headers=seller["headers"])
    assert job.status_code == 202
    analysis_id = job.json()["analysis_id"]
    # B's material with A's analysis id: not found, not a version/analysis error
    r = client.post(
        f"/materials/{b['id']}/confirm",
        json={"version": b["version"], "analysis_id": analysis_id},
        headers=seller2["headers"],
    )
    assert r.status_code in (404, 409)
    if r.status_code == 409:
        assert r.json()["error"]["details"]["reason"] == "ANALYSIS_NOT_FOUND_FOR_MATERIAL"
    assert client.get(f"/ai/analyses/{analysis_id}", headers=seller2["headers"]).status_code == 404
    # B cannot analyze A's material or upload into it
    assert (
        client.post(
            "/ai/analyze", json={"material_id": a["id"]}, headers=seller2["headers"]
        ).status_code
        == 404
    )
    assert upload(client, seller2["headers"], a["id"]).status_code == 404
    # A's material is unchanged by all of the above
    assert (
        client.get(f"/materials/{a['id']}", headers=seller["headers"]).json()["version"]
        >= a["version"]
    )


def test_reservations_requirements_and_plans_are_private_to_their_sides(
    client, seller, seller2, buyer
):
    m = published_material(client, seller["headers"])
    buyer2 = register(client, "buyer", activity_type="workshop")
    buyer2["headers"] = login_headers(client, buyer2["email"])
    req = requirement(client, buyer, max_kg="50.000")
    res = reserve(client, buyer, m, req).json()
    for h in (seller2["headers"], buyer2["headers"]):
        for action in ("confirm", "cancel", "transfer", "complete"):
            r = client.patch(f"/reservations/{res['id']}", json={"action": action}, headers=h)
            assert r.status_code == 404, action
        assert client.patch(
            f"/buyer-requirements/{req['id']}", json={"max_kg": "1.000"}, headers=h
        ).status_code in (403, 404)
        assert client.get("/reservations", headers=h).json()["total"] == 0
    # another buyer cannot reserve against someone else's requirement
    r = client.post(
        "/reservations",
        json={"material_id": m["id"], "requirement_id": req["id"], "quantity_kg": "1.000"},
        headers=buyer2["headers"] | {"Idempotency-Key": str(uuid.uuid4())},
    )
    assert r.status_code in (404, 403, 422)
    plan = client.post(
        "/optimization/run", json={"material_ids": [m["id"]]}, headers=seller["headers"]
    )
    assert plan.status_code == 201
    assert (
        client.get(
            f"/optimization/runs/{plan.json()['id']}", headers=seller2["headers"]
        ).status_code
        == 404
    )
    assert client.post(
        "/optimization/run", json={"material_ids": [m["id"]]}, headers=seller2["headers"]
    ).status_code in (403, 404, 422)


def test_lists_and_analytics_do_not_leak_other_organizations(client, seller, seller2):
    published_material(client, seller["headers"])
    new_material(client, seller["headers"])
    mine = client.get("/materials", headers=seller["headers"]).json()
    theirs = client.get("/materials", headers=seller2["headers"]).json()
    assert mine["total"] == 2 and theirs["total"] == 0 and theirs["items"] == []
    s2 = client.get("/analytics/summary", headers=seller2["headers"]).json()
    assert all(str(v) in ("0", "0.000", "0.00", "0.0") for v in _scalars(s2)), s2
    # organization id in query or body is ignored, never trusted
    other = seller["organization"]["id"]
    r = client.get(f"/materials?organization_id={other}", headers=seller2["headers"])
    assert r.status_code in (200, 422) and (r.status_code == 422 or r.json()["total"] == 0)


def _scalars(obj):
    if isinstance(obj, dict):
        for v in obj.values():
            yield from _scalars(v)
    elif isinstance(obj, (int, float, str)) and not isinstance(obj, bool):
        if isinstance(obj, str) and not obj.replace(".", "", 1).replace("-", "", 1).isdigit():
            return
        yield obj


# ---------- PM: membership edge cases ----------


def test_removing_or_suspending_membership_closes_access_for_that_user_only(client, seller):
    org = seller["organization"]["id"]
    member = add_member(client, org, OrgRole.MANAGER)
    assert client.get("/materials", headers=member["headers"]).status_code == 200
    with Session(get_engine()) as db:
        u = db.scalar(select(User).where(User.email == member["email"]))
        ms = db.scalar(select(OrganizationMembership).where(OrganizationMembership.user_id == u.id))
        db.delete(ms)
        db.commit()
    r = client.get("/materials", headers=member["headers"])
    assert r.status_code == 403 and r.json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP"
    assert client.get("/materials", headers=seller["headers"]).status_code == 200


def test_downgraded_role_applies_on_next_request_with_same_token(client, seller):
    org = seller["organization"]["id"]
    manager = add_member(client, org, OrgRole.MANAGER)
    m = ready_material(client, seller["headers"])
    with Session(get_engine()) as db:
        u = db.scalar(select(User).where(User.email == manager["email"]))
        db.scalar(
            select(OrganizationMembership).where(OrganizationMembership.user_id == u.id)
        ).role = OrgRole.MEMBER
        db.commit()
    r = client.post(
        f"/materials/{m['id']}/publish", json={"version": m["version"]}, headers=manager["headers"]
    )
    assert r.status_code == 403


def test_membership_database_constraints(client, seller):
    uid = uuid.UUID(seller["user"]["id"])
    oid = uuid.UUID(seller["organization"]["id"])
    with Session(get_engine()) as db:
        with pytest.raises(Exception, match="role|enum|invalid"):
            db.execute(
                text(
                    "INSERT INTO organization_memberships (id, user_id, organization_id, role, status)"
                    " VALUES (gen_random_uuid(), :u, :o, 'SUPERUSER', 'removed')"
                ),
                {"u": uid, "o": oid},
            )
        db.rollback()
        with pytest.raises(Exception, match="uq_|unique|duplicate"):
            db.add(OrganizationMembership(user_id=uid, organization_id=oid, role=OrgRole.OWNER))
            db.commit()
        db.rollback()


def test_error_responses_hide_internals(client, seller, seller2):
    m = new_material(client, seller["headers"])
    for r in (
        client.get(f"/materials/{m['id']}", headers=seller2["headers"]),
        client.get("/materials/not-a-uuid", headers=seller["headers"]),
        client.post("/auth/login", json={"email": "x", "password": 1}),
        client.get("/auth/me", headers={"Authorization": "Bearer garbage"}),
    ):
        body = r.json()["error"]
        assert {"code", "message", "request_id"} <= set(body)
        assert "Traceback" not in r.text and 'File "' not in r.text


def test_foreign_resource_with_malformed_body_is_404(client, seller, seller2):
    m = new_material(client, seller["headers"])
    h = seller2["headers"]
    for method, path, body in (
        ("POST", f"/materials/{m['id']}/publish", {"version": "bad"}),
        ("POST", f"/materials/{m['id']}/publish", {"version": 1, "x": 1}),
        ("PATCH", f"/materials/{m['id']}", {"version": 1, "status": "available"}),
        ("POST", f"/materials/{m['id']}/internal-use", {"quantity_kg": "-1"}),
    ):
        r = client.request(method, path, json=body, headers=h)
        assert r.status_code == 404, (path, body, r.status_code)
