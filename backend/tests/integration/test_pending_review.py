"""R1-MIGRATION-01: ambiguous legacy organizations keep their users as PENDING_REVIEW members."""

import os
import uuid

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import Session

from app.core.permissions import permissions_for
from app.core.security import hash_password
from app.db.session import get_engine
from app.models import AuditLog, Organization, OrganizationMembership, PlatformAdmin, User
from app.models.enums import MembershipStatus, OrganizationKind, OrgRole
from tests.integration.conftest import login_headers, register
from tests.integration.test_membership import PASSWORD, add_member

LEGACY_ORGS = [  # (name, activity_type)
    ("S1", "garment_factory"),
    ("S2", "workshop"),
    ("S3", "garment_factory"),
    ("B1", "workshop"),
    ("B2", "recycler"),
    ("B3", "workshop"),
    ("Conflict", "workshop"),
    ("EntRecycler", "recycler"),
]
# (email, legacy role, organization index); 10 non-admin users + 1 admin
LEGACY_USERS = [
    ("s1", "enterprise", 0),
    ("s2", "enterprise", 1),
    ("s3", "enterprise", 2),
    ("b1", "buyer", 3),
    ("b2", "buyer", 4),
    ("b3", "buyer", 5),
    ("b4", "buyer", 3 + 0),  # second user in B1 -> B1 becomes ambiguous too
    ("c1", "enterprise", 6),
    ("c2", "buyer", 6),
    ("er", "enterprise", 7),
]


def _legacy_database():
    """Roll the schema back to 0003 and insert pre-R1 data; returns ids."""
    command.downgrade(Config("alembic.ini"), "0003")
    pw = hash_password(PASSWORD)
    org_ids = [str(uuid.uuid4()) for _ in LEGACY_ORGS]
    user_ids = {}
    engine = create_engine(os.environ["DATABASE_URL"])
    with engine.begin() as c:
        for oid, (name, act) in zip(org_ids, LEGACY_ORGS, strict=True):
            c.execute(
                text(
                    "insert into organizations (id,name,city,activity_type,created_at,updated_at)"
                    " values (:i,:n,'Бишкек',:a,now(),now())"
                ),
                {"i": oid, "n": name, "a": act},
            )
        adm_org = str(uuid.uuid4())
        c.execute(
            text(
                "insert into organizations (id,name,city,activity_type,created_at,updated_at)"
                " values (:i,'Admin','Бишкек','other',now(),now())"
            ),
            {"i": adm_org},
        )
        for key, role, oi in [*LEGACY_USERS, ("admin", "admin", None)]:
            uid = str(uuid.uuid4())
            user_ids[key] = uid
            c.execute(
                text(
                    "insert into users (id,email,password_hash,role,organization_id,active,"
                    "email_confirmed,created_at) values (:i,:e,:p,:r,:o,true,true,now())"
                ),
                {
                    "i": uid,
                    "e": f"{key}@legacy.test",
                    "p": pw,
                    "r": role,
                    "o": adm_org if oi is None else org_ids[oi],
                },
            )
    engine.dispose()
    return org_ids, user_ids


def test_no_membership_lost_and_ambiguous_users_get_no_rights(client):
    org_ids, user_ids = _legacy_database()
    command.upgrade(Config("alembic.ini"), "head")
    with Session(get_engine()) as db:
        non_admin = [u for k, u in user_ids.items() if k != "admin"]
        assert len(non_admin) == 10
        mem = {
            str(m.user_id): m
            for m in db.scalars(select(OrganizationMembership))
            if str(m.user_id) in non_admin
        }
        # 1. nobody with a valid organization link lost a membership
        assert set(mem) == set(non_admin)
        for key, _role, oi in LEGACY_USERS:
            m = mem[user_ids[key]]
            assert str(m.organization_id) == org_ids[oi]  # original link preserved
        # ambiguous = B1 (two users), Conflict (two), EntRecycler -> 5 users pending
        pending = {
            k
            for k, *_ in LEGACY_USERS
            if mem[user_ids[k]].status == MembershipStatus.pending_review
        }
        assert pending == {"b1", "b4", "c1", "c2", "er"}
        active = {k for k, *_ in LEGACY_USERS if mem[user_ids[k]].status == MembershipStatus.active}
        assert active == {"s1", "s2", "s3", "b2", "b3"}
        assert all(mem[user_ids[k]].role == OrgRole.OWNER for k in active)
        kinds = {o.name: o.kind for o in db.scalars(select(Organization))}
        assert kinds["S1"] == OrganizationKind.supplier
        assert kinds["B2"] == kinds["B3"] == OrganizationKind.buyer  # recycler stays a buyer
        # 3/6. the kind of ambiguous organizations is never guessed
        for name in ("B1", "Conflict", "EntRecycler"):
            assert kinds[name] is None
        assert db.get(PlatformAdmin, uuid.UUID(user_ids["admin"])) is not None
        assert str(user_ids["admin"]) not in mem

    # no escalation: pending users have empty permissions and explicit status
    for key in pending:
        h = login_headers(client, f"{key}@legacy.test")
        me = client.get("/auth/me", headers=h).json()
        assert me["permissions"] == [] and me["organization_kind"] is None
        assert me["membership"]["status"] == "pending_review"
    # active users keep working scenarios
    h = login_headers(client, "s1@legacy.test")
    assert client.post("/materials", json={"name": "после миграции"}, headers=h).status_code == 201
    assert "material.publish" in client.get("/auth/me", headers=h).json()["permissions"]

    # idempotent and reversible: down to 0005 and up again gives the same result
    cfg = Config("alembic.ini")
    command.downgrade(cfg, "0005")
    with Session(get_engine()) as db:
        assert (
            db.scalar(
                text("select count(*) from organization_memberships where status='pending_review'")
            )
            == 0
        )
        assert db.scalar(text("select count(*) from organization_memberships")) == 5
    command.upgrade(cfg, "head")
    command.upgrade(cfg, "head")  # second run is a no-op
    with Session(get_engine()) as db:
        assert db.scalar(text("select count(*) from organization_memberships")) == 10
        assert (
            db.scalar(text("select count(*) from audit_log where action='backfill.pending_review'"))
            == 5
        )


def test_pending_review_can_log_in_and_sees_status_but_nothing_else(client):
    _legacy_database()
    command.upgrade(Config("alembic.ini"), "head")
    h = login_headers(client, "c1@legacy.test")
    me = client.get("/auth/me", headers=h)
    assert me.status_code == 200
    body = me.json()
    assert body["membership"]["status"] == "pending_review" and body["permissions"] == []
    assert body["organization"]["name"] == "Conflict" and body["organization"]["kind"] is None
    assert client.get("/organizations/me", headers=h).status_code == 200
    blocked = [
        ("get", "/materials", None),
        ("post", "/materials", {"name": "x"}),
        ("patch", "/organizations/me", {"city": "Ош"}),
        ("post", f"/materials/{uuid.uuid4()}/publish", {"version": 1}),
        ("post", f"/materials/{uuid.uuid4()}/archive", {"version": 1}),
        ("post", "/reservations", {}),
        ("patch", f"/reservations/{uuid.uuid4()}", {"action": "transfer"}),
        ("get", "/analytics/summary", None),
        ("get", "/buyer-requirements", None),
        ("post", "/ai/analyze", {}),
    ]
    for method, path, payload in blocked:
        r = getattr(client, method)(
            path, headers=h, **({"json": payload} if payload is not None else {})
        )
        err = r.json()["error"]
        assert r.status_code == 403 and err["code"] == "NO_ACTIVE_MEMBERSHIP", path
        assert err["details"] == {"membership_status": "pending_review"}, path
    for path in ("/admin/api/me", "/admin/api/summary", "/admin/api/reviews"):
        assert client.get(path, headers=h).status_code == 403
    assert (
        client.post(
            f"/admin/api/memberships/{uuid.uuid4()}/activate",
            json={"kind": "supplier", "role": "OWNER"},
            headers=h,
        ).status_code
        == 403
    )


def _admin(client):
    acc = register(client, "enterprise")
    with Session(get_engine()) as db:
        user = db.scalar(select(User).where(User.email == acc["email"]))
        db.query(OrganizationMembership).filter_by(user_id=user.id).delete()
        db.add(PlatformAdmin(user_id=user.id))
        db.commit()
    return login_headers(client, acc["email"]), acc["user"]["id"]


def test_admin_review_activation_flow_is_explicit_and_audited(client):
    _legacy_database()
    command.upgrade(Config("alembic.ini"), "head")
    admin, admin_id = _admin(client)
    r = client.get("/admin/api/reviews", headers=admin)
    assert r.status_code == 200 and r.json()["total"] == 5
    items = {i["user_email"]: i for i in r.json()["items"]}
    assert items["c1@legacy.test"]["review_reason"] == "multiple_users"
    assert items["er@legacy.test"]["review_reason"] == "enterprise_recycler_contradiction"
    assert all(i["kind"] is None for i in items.values())

    # nothing is activated automatically; activation needs explicit kind AND role
    mid = items["c1@legacy.test"]["membership_id"]
    assert (
        client.post(
            f"/admin/api/memberships/{mid}/activate", json={"kind": "supplier"}, headers=admin
        ).status_code
        == 422
    )
    r = client.post(
        f"/admin/api/memberships/{mid}/activate",
        json={"kind": "supplier", "role": "OWNER"},
        headers=admin,
    )
    assert (
        r.status_code == 200 and r.json()["status"] == "active" and r.json()["kind"] == "supplier"
    )
    hc1 = login_headers(client, "c1@legacy.test")
    me = client.get("/auth/me", headers=hc1).json()
    assert me["organization_kind"] == "supplier" and "material.publish" in me["permissions"]
    assert client.post("/materials", json={"name": "ok"}, headers=hc1).status_code == 201

    # repeat is a state error; the second user of the same organization cannot contradict the kind
    assert (
        client.post(
            f"/admin/api/memberships/{mid}/activate",
            json={"kind": "supplier", "role": "OWNER"},
            headers=admin,
        ).status_code
        == 409
    )
    mid2 = items["c2@legacy.test"]["membership_id"]
    r = client.post(
        f"/admin/api/memberships/{mid2}/activate",
        json={"kind": "buyer", "role": "MEMBER"},
        headers=admin,
    )
    assert (
        r.status_code == 409
        and r.json()["error"]["details"]["reason"] == "ORGANIZATION_KIND_MISMATCH"
    )
    # a recycler organization cannot become a supplier
    mid3 = items["er@legacy.test"]["membership_id"]
    r = client.post(
        f"/admin/api/memberships/{mid3}/activate",
        json={"kind": "supplier", "role": "OWNER"},
        headers=admin,
    )
    assert r.status_code == 422
    # reject closes access and is audited
    assert (
        client.post(
            f"/admin/api/memberships/{mid3}/reject", json={"reason": "дубль"}, headers=admin
        ).status_code
        == 200
    )
    h_er = login_headers(client, "er@legacy.test")
    r = client.get("/auth/me", headers=h_er)
    assert r.status_code == 403 and r.json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP"
    assert (
        client.post(
            f"/admin/api/memberships/{uuid.uuid4()}/reject", json={}, headers=admin
        ).status_code
        == 404
    )

    with Session(get_engine()) as db:
        rows = {
            a.action: a
            for a in db.scalars(
                select(AuditLog).where(
                    AuditLog.action.in_(["membership.activated", "membership.rejected"])
                )
            )
        }
        assert rows["membership.activated"].actor_user_id == uuid.UUID(admin_id)
        assert rows["membership.activated"].details["kind"] == "supplier"
        assert rows["membership.rejected"].target_id == mid3
    # ordinary organization users cannot reach the review routes
    h = login_headers(client, "s1@legacy.test")
    assert client.get("/admin/api/reviews", headers=h).status_code == 403


def test_buyer_member_recycler_and_member_rights(client):
    buyer = register(client, "buyer", activity_type="workshop")
    recycler = register(client, "buyer", activity_type="recycler")
    member = add_member(client, buyer["organization"]["id"], OrgRole.MEMBER)
    perms = set(client.get("/auth/me", headers=member["headers"]).json()["permissions"])
    assert {"reservation.create", "match.request", "reservation.receive"} <= perms
    assert not perms & {
        "reservation.approve",
        "members.manage",
        "recycling.operate",
        "material.publish",
    }
    # a recycler inherits every buyer right; recycling operations are an explicit extra
    buyer_owner = permissions_for(OrgRole.OWNER, OrganizationKind.buyer, "workshop")
    rec_owner = permissions_for(OrgRole.OWNER, OrganizationKind.buyer, "recycler")
    assert buyer_owner < rec_owner and rec_owner - buyer_owner == {"recycling.operate"}
    assert "recycling.operate" not in permissions_for(
        OrgRole.MEMBER, OrganizationKind.buyer, "recycler"
    )
    assert "recycling.operate" in set(
        client.get(
            "/auth/me",
            headers=recycler["headers"]
            if "headers" in recycler
            else login_headers(client, recycler["email"]),
        ).json()["permissions"]
    )
    assert permissions_for(OrgRole.OWNER, None, "recycler") == frozenset()
