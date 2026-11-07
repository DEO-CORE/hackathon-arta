"""R1-MIGRATION-01: users of ambiguous legacy organizations keep a link (PENDING_REVIEW) but no rights.

Representative data: 10 users, 3 of them in ambiguous organizations (the "3 of 10 lose access"
scenario). Synthetic data only; PostgreSQL test database only (alembic downgrade/upgrade).
"""

import os
import uuid

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import get_engine
from app.models import AuditLog, Organization, OrganizationMembership, PlatformAdmin, User
from app.models.enums import MembershipStatus, OrganizationKind, OrgRole
from tests.integration.conftest import login_headers, register

PASSWORD = "correct-horse-battery"
ORG = lambda n: f"a0000000-0000-0000-0000-{n:012d}"  # noqa: E731
USR = lambda n: f"b0000000-0000-0000-0000-{n:012d}"  # noqa: E731
VALID = (1, 2, 7, 8, 9, 10)  # unambiguous, non-admin
AMBIGUOUS = (4, 5, 6)  # 3 of 10 users
ADMIN = 3

# organization n -> (name, activity_type)
ORGS = {
    1: ("S", "garment_factory"),
    2: ("R", "recycler"),
    3: ("Adm", "other"),
    4: ("Conf", "workshop"),  # two users: enterprise + buyer
    6: ("EntRec", "recycler"),  # enterprise + recycler: contradiction
    7: ("BuyG", "garment_factory"),
    8: ("S2", "garment_factory"),
    9: ("B2", "workshop"),
    10: ("B3", "workshop"),
}
# user n -> (legacy role, organization n)
USERS = {
    1: ("enterprise", 1),
    2: ("buyer", 2),
    3: ("admin", 3),
    4: ("enterprise", 4),
    5: ("buyer", 4),
    6: ("enterprise", 6),
    7: ("buyer", 7),
    8: ("enterprise", 8),
    9: ("buyer", 9),
    10: ("buyer", 10),
}


@pytest.fixture
def legacy(client):
    """Database in the pre-R1 state (revision 0003) with the representative users; head afterwards."""
    cfg = Config("alembic.ini")
    command.downgrade(cfg, "0003")
    engine = create_engine(os.environ["DATABASE_URL"])
    pw = hash_password(PASSWORD)
    with engine.begin() as c:
        for n, (name, act) in ORGS.items():
            c.execute(
                text(
                    "insert into organizations (id,name,city,activity_type,created_at,updated_at)"
                    " values (:i,:n,'Бишкек',:a,now(),now())"
                ),
                {"i": ORG(n), "n": name, "a": act},
            )
        for n, (role, o) in USERS.items():
            c.execute(
                text(
                    "insert into users (id,email,password_hash,role,organization_id,active,"
                    "email_confirmed,created_at) values (:i,:e,:p,:r,:o,true,true,now())"
                ),
                {"i": USR(n), "e": f"u{n}@x.test", "p": pw, "r": role, "o": ORG(o)},
            )
    engine.dispose()
    yield cfg
    command.upgrade(cfg, "head")


def _snapshot() -> dict:
    with Session(get_engine()) as db:
        rows = db.execute(
            select(
                OrganizationMembership.user_id,
                OrganizationMembership.organization_id,
                OrganizationMembership.role,
                OrganizationMembership.status,
            )
        ).all()
        audit = db.execute(
            text("select action, count(*) from audit_log group by action order by action")
        ).all()
    return {"memberships": sorted(map(tuple, rows), key=str), "audit": [tuple(a) for a in audit]}


def _h(client, n: int) -> dict:
    return login_headers(client, f"u{n}@x.test")


def _migrate(cfg):
    command.upgrade(cfg, "head")
    get_settings.cache_clear()


# ---------- migration ----------


def test_no_user_with_a_valid_link_loses_membership(legacy):
    _migrate(legacy)
    with Session(get_engine()) as db:
        live = {
            m.user_id: m
            for m in db.scalars(
                select(OrganizationMembership).where(
                    OrganizationMembership.status.in_(
                        [MembershipStatus.active, MembershipStatus.pending_review]
                    )
                )
            )
        }
        non_admin = [uuid.UUID(USR(n)) for n in USERS if n != ADMIN]
        assert set(non_admin) <= set(live), "a non-admin user ended up without any membership"
        assert uuid.UUID(USR(ADMIN)) not in live
        assert db.get(PlatformAdmin, uuid.UUID(USR(ADMIN))) is not None
        for n in VALID:
            m = live[uuid.UUID(USR(n))]
            assert m.status == MembershipStatus.active and m.role == OrgRole.OWNER, n
            assert m.organization_id == uuid.UUID(ORG(USERS[n][1]))
        # nobody in an ambiguous organization is active, privileged or typed
        for n in AMBIGUOUS:
            m = live[uuid.UUID(USR(n))]
            assert m.status == MembershipStatus.pending_review, n
            assert m.role == OrgRole.MEMBER, n
            assert m.organization_id == uuid.UUID(ORG(USERS[n][1]))
            assert db.get(Organization, m.organization_id).kind is None
            assert db.get(User, m.user_id).default_organization_id == m.organization_id
        assert sum(1 for m in live.values() if m.status == MembershipStatus.pending_review) == 3
        kinds = {o.name: o.kind for o in db.scalars(select(Organization))}
        assert kinds["S"] == OrganizationKind.supplier and kinds["B2"] == OrganizationKind.buyer
        pend = db.scalars(
            select(AuditLog).where(AuditLog.action == "backfill.pending_review")
        ).all()
        assert len(pend) == 3
        # legacy columns are untouched
        assert db.get(User, uuid.UUID(USR(4))).organization_id == uuid.UUID(ORG(4))


def test_migration_is_idempotent_and_reversible(legacy):
    _migrate(legacy)
    first = _snapshot()
    # re-running the head upgrade is a no-op
    command.upgrade(legacy, "head")
    assert _snapshot() == first
    # one step back and forward again: no duplicate rows, audit entries are not doubled
    command.downgrade(legacy, "0005")
    with Session(get_engine()) as db:
        assert (
            db.scalar(
                text("select count(*) from organization_memberships where status='pending_review'")
            )
            == 0
        )
        assert db.scalar(text("select count(*) from organization_memberships")) == len(VALID)
    command.upgrade(legacy, "head")
    again = _snapshot()
    assert again["audit"] == first["audit"]
    assert [m[:2] + m[3:] for m in again["memberships"]] == [
        m[:2] + m[3:] for m in first["memberships"]
    ]
    # full rollback to the pre-R1 revision keeps users and organizations
    command.downgrade(legacy, "0003")
    engine = create_engine(os.environ["DATABASE_URL"])
    with engine.begin() as c:
        assert c.scalar(text("select count(*) from users")) == 10
        assert c.scalar(text("select count(*) from organizations")) == len(ORGS)
        assert (
            c.scalar(
                text(
                    "select count(*) from users where role = 'enterprise' and organization_id is not null"
                )
            )
            == 4
        )
    engine.dispose()
    command.upgrade(legacy, "head")
    assert _snapshot()["audit"] == first["audit"]


# ---------- behaviour of a PENDING_REVIEW user ----------

PENDING_DENIED = [
    ("GET", "/materials", None),
    ("POST", "/materials", {"name": "x"}),
    ("GET", f"/materials/{uuid.uuid4()}", None),
    ("POST", f"/materials/{uuid.uuid4()}/publish", {"version": 1}),
    ("POST", f"/materials/{uuid.uuid4()}/archive", {"version": 1}),
    ("POST", f"/materials/{uuid.uuid4()}/confirm", {"version": 1}),
    ("POST", "/ai/analyze", {"material_id": str(uuid.uuid4())}),
    ("POST", "/ai/match", {"material_id": str(uuid.uuid4())}),
    ("POST", "/optimization/run", {"material_ids": [str(uuid.uuid4())]}),
    ("GET", "/buyer-requirements", None),
    ("POST", "/buyer-requirements", {}),
    ("GET", "/reservations", None),
    ("POST", "/reservations", {}),
    ("PATCH", f"/reservations/{uuid.uuid4()}", {"action": "confirm"}),
    ("PATCH", f"/reservations/{uuid.uuid4()}", {"action": "transfer"}),
    ("POST", f"/materials/{uuid.uuid4()}/internal-use", {"quantity_kg": "1.000", "basis": "x"}),
    ("GET", "/analytics/summary", None),
    ("PATCH", "/organizations/me", {"name": "Новое имя"}),
    ("GET", "/admin/api/me", None),
    ("GET", "/admin/api/reviews", None),
    (
        "POST",
        f"/admin/api/memberships/{uuid.uuid4()}/activate",
        {"kind": "supplier", "role": "OWNER"},
    ),
]


@pytest.mark.parametrize("n", AMBIGUOUS)
def test_pending_review_user_can_log_in_and_see_status_but_has_no_rights(client, legacy, n):
    _migrate(legacy)
    h = _h(client, n)  # login is allowed
    me = client.get("/auth/me", headers=h)
    assert me.status_code == 200, me.text
    body = me.json()
    assert body["membership"]["status"] == "pending_review"
    assert body["membership"]["role"] == "MEMBER"
    assert body["permissions"] == []
    assert body["organization_kind"] is None
    assert body["organization"]["id"] == ORG(USERS[n][1])
    assert client.get("/organizations/me", headers=h).status_code == 200  # reading own org only
    for method, path, payload in PENDING_DENIED:
        if method == "GET" and path == "/organizations/me":
            continue
        r = client.request(method, path, json=payload, headers=h)
        assert r.status_code == 403, (method, path, r.status_code, r.text)
        code = r.json()["error"]["code"]
        assert code in ("NO_ACTIVE_MEMBERSHIP", "FORBIDDEN"), (path, code)
    # still nothing was written for the user
    with Session(get_engine()) as db:
        assert db.scalar(text("select count(*) from materials")) == 0
        assert db.scalar(text("select count(*) from reservations")) == 0
        m = db.scalar(
            select(OrganizationMembership).where(
                OrganizationMembership.user_id == uuid.UUID(USR(n))
            )
        )
        assert (
            m.status == MembershipStatus.pending_review
            and db.get(Organization, m.organization_id).kind is None
        )


def test_active_users_keep_their_scenarios_after_migration(client, legacy):
    _migrate(legacy)
    seller, buyer = _h(client, 1), _h(client, 9)
    me = client.get("/auth/me", headers=seller).json()
    assert me["membership"]["status"] == "active" and "material.publish" in me["permissions"]
    r = client.post("/materials", json={"name": "Остатки", "total_kg": "10.000"}, headers=seller)
    assert r.status_code == 201
    assert client.get("/materials", headers=seller).json()["total"] == 1
    assert client.get("/materials", headers=buyer).status_code == 200  # catalog for buyer
    mb = client.get("/auth/me", headers=buyer).json()
    assert "reservation.create" in mb["permissions"] and mb["organization_kind"] == "buyer"
    assert (
        client.get("/auth/me", headers=_h(client, 2)).json()["organization"]["activity_type"]
        == "recycler"
    )


# ---------- administrative process ----------


def _platform_admin(client) -> dict:
    acc = register(client, "enterprise")
    with Session(get_engine()) as db:
        u = db.scalar(select(User).where(User.email == acc["email"]))
        db.execute(text("delete from organization_memberships where user_id = :u"), {"u": u.id})
        db.add(PlatformAdmin(user_id=u.id))
        db.commit()
    return {"headers": login_headers(client, acc["email"]), "id": acc["user"]["id"]}


def _membership_id(n: int) -> str:
    with Session(get_engine()) as db:
        return str(
            db.scalar(
                select(OrganizationMembership.id).where(
                    OrganizationMembership.user_id == uuid.UUID(USR(n))
                )
            )
        )


def test_only_platform_admin_can_review_and_nothing_activates_by_itself(client, legacy):
    _migrate(legacy)
    mid = _membership_id(4)
    body = {"kind": "supplier", "role": "OWNER"}
    # nobody but a platform admin: the pending user, an active owner, a buyer
    for n in (4, 1, 9):
        h = _h(client, n)
        assert client.get("/admin/api/reviews", headers=h).status_code == 403, n
        r = client.post(f"/admin/api/memberships/{mid}/activate", json=body, headers=h)
        assert r.status_code == 403, n
        assert (
            client.post(f"/admin/api/memberships/{mid}/reject", json={}, headers=h).status_code
            == 403
        )
    assert client.post(f"/admin/api/memberships/{mid}/activate", json=body).status_code == 401
    # repeated login, /auth/me and a second migration pass do not change anything
    for _ in range(2):
        _h(client, 4)
        client.get("/auth/me", headers=_h(client, 4))
    before = _snapshot()
    command.upgrade(legacy, "head")
    assert _snapshot() == before
    with Session(get_engine()) as db:
        pending = db.scalars(
            select(OrganizationMembership).where(
                OrganizationMembership.status == MembershipStatus.pending_review
            )
        ).all()
        assert len(pending) == 3

    admin = _platform_admin(client)
    listed = client.get("/admin/api/reviews", headers=admin["headers"]).json()
    assert listed["total"] == 3
    assert {i["user_email"] for i in listed["items"]} == {f"u{n}@x.test" for n in AMBIGUOUS}
    assert all("password" not in str(i).lower() for i in listed["items"])


def test_admin_activation_is_audited_and_grants_exactly_the_chosen_role(client, legacy):
    _migrate(legacy)
    admin = _platform_admin(client)
    mid = _membership_id(6)  # recycler organization with a conflicting enterprise user
    # a recycler can only be a buyer
    r = client.post(
        f"/admin/api/memberships/{mid}/activate",
        json={"kind": "supplier", "role": "OWNER"},
        headers=admin["headers"],
    )
    assert r.status_code == 422, r.text
    assert (
        client.post(
            f"/admin/api/memberships/{uuid.uuid4()}/activate",
            json={"kind": "buyer", "role": "MEMBER"},
            headers=admin["headers"],
        ).status_code
        == 404
    )
    r = client.post(
        f"/admin/api/memberships/{mid}/activate",
        json={"kind": "buyer", "role": "MEMBER"},
        headers=admin["headers"],
    )
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "active" and r.json()["role"] == "MEMBER"
    me = client.get("/auth/me", headers=_h(client, 6)).json()
    assert me["membership"] == {
        "organization_id": ORG(6),
        "role": "MEMBER",
        "status": "active",
    }
    assert me["organization_kind"] == "buyer" and me["permissions"]
    assert "members.manage" not in me["permissions"]  # exactly the chosen role, no more
    with Session(get_engine()) as db:
        a = db.scalar(select(AuditLog).where(AuditLog.action == "membership.activated"))
        assert a is not None and str(a.actor_user_id) == admin["id"]
        assert a.details["role"] == "MEMBER" and a.details["kind"] == "buyer"
    # repeat is a conflict, not a second activation
    again = client.post(
        f"/admin/api/memberships/{mid}/activate",
        json={"kind": "buyer", "role": "OWNER"},
        headers=admin["headers"],
    )
    assert again.status_code == 409 and again.json()["error"]["code"] == "INVALID_TRANSITION"
    with Session(get_engine()) as db:
        assert (
            db.scalar(
                select(OrganizationMembership.role).where(
                    OrganizationMembership.id == uuid.UUID(mid)
                )
            )
            == OrgRole.MEMBER
        )


def test_admin_rejection_closes_the_link_and_is_audited(client, legacy):
    _migrate(legacy)
    admin = _platform_admin(client)
    mid = _membership_id(5)
    r = client.post(
        f"/admin/api/memberships/{mid}/reject",
        json={"reason": "дубликат"},
        headers=admin["headers"],
    )
    assert r.status_code == 200 and r.json()["status"] == "removed"
    r = client.get("/auth/me", headers=_h(client, 5))
    assert r.status_code == 403 and r.json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP"
    with Session(get_engine()) as db:
        a = db.scalar(select(AuditLog).where(AuditLog.action == "membership.rejected"))
        assert a is not None and str(a.actor_user_id) == admin["id"]
        # the other pending users in the same organization are untouched
        assert (
            db.scalar(
                select(OrganizationMembership.status).where(
                    OrganizationMembership.user_id == uuid.UUID(USR(4))
                )
            )
            == MembershipStatus.pending_review
        )
