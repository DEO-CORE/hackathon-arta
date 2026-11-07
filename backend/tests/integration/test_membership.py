"""R1: organization kind, memberships and permissions (docs/api.md 20.12). PostgreSQL only."""

import os
import uuid
from datetime import UTC, datetime

import jwt
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import create_access_token, hash_password
from app.db.session import get_engine
from app.models import AuditLog, Organization, OrganizationMembership, PlatformAdmin, User
from app.models.enums import MembershipStatus, OrganizationKind, OrgRole, Role
from tests.integration.conftest import (
    login_headers,
    new_material,
    published_material,
    ready_material,
    register,
    upload,
)

PASSWORD = "correct-horse-battery"


def add_member(client, org_id: str, role: OrgRole, user_role: Role = Role.enterprise) -> dict:
    """Test-only: there is no invitation route yet, so write the user and membership directly."""
    email = f"{role.value.lower()}-{uuid.uuid4().hex[:8]}@example.test"
    with Session(get_engine()) as db:
        user = User(
            email=email,
            password_hash=hash_password(PASSWORD),
            role=user_role,
            organization_id=uuid.UUID(org_id),
            active=True,
            email_confirmed=True,
            email_confirmed_at=datetime.now(UTC),
        )
        db.add(user)
        db.flush()
        db.add(
            OrganizationMembership(user_id=user.id, organization_id=user.organization_id, role=role)
        )
        user.default_organization_id = user.organization_id
        db.commit()
    return {"email": email, "headers": login_headers(client, email)}


# ---------- registration and /auth/me ----------


def test_register_creates_owner_membership_kind_default_and_audit(client):
    s = register(client, "enterprise")
    b = register(client, "buyer", activity_type="recycler")
    with Session(get_engine()) as db:
        for acc, kind in ((s, OrganizationKind.supplier), (b, OrganizationKind.buyer)):
            org = db.get(Organization, uuid.UUID(acc["organization"]["id"]))
            user = db.get(User, uuid.UUID(acc["user"]["id"]))
            assert org.kind == kind and acc["organization"]["kind"] == kind.value
            ms = db.scalars(
                select(OrganizationMembership).where(OrganizationMembership.user_id == user.id)
            ).all()
            assert [(m.role, m.status, m.organization_id) for m in ms] == [
                (OrgRole.OWNER, MembershipStatus.active, org.id)
            ]
            assert user.default_organization_id == org.id
        actions = {a.action for a in db.scalars(select(AuditLog))}
        assert {"organization.created", "membership.created"} <= actions
    # recycler is a buyer organization with a specialization
    assert b["organization"]["activity_type"] == "recycler"


def test_auth_me_context_and_permissions(client, seller, buyer):
    me = client.get("/auth/me", headers=seller["headers"]).json()
    assert me["organization_kind"] == "supplier"
    assert me["membership"]["role"] == "OWNER" and me["membership"]["status"] == "active"
    assert me["default_organization_id"] == seller["organization"]["id"]
    assert me["organization"]["id"] == seller["organization"]["id"]
    assert {"material.publish", "material.archive", "reservation.approve", "analytics.read"} <= set(
        me["permissions"]
    )
    assert "reservation.create" not in me["permissions"]  # buyer-side right
    assert me["permissions"] == sorted(me["permissions"])
    mb = client.get("/auth/me", headers=buyer["headers"]).json()
    assert mb["organization_kind"] == "buyer"
    assert "material.publish" not in mb["permissions"] and "reservation.create" in mb["permissions"]
    assert client.get("/auth/me").status_code == 401


def test_me_permissions_by_org_role(client, seller):
    org = seller["organization"]["id"]
    manager = add_member(client, org, OrgRole.MANAGER)
    member = add_member(client, org, OrgRole.MEMBER)
    pm = set(client.get("/auth/me", headers=manager["headers"]).json()["permissions"])
    pe = set(client.get("/auth/me", headers=member["headers"]).json()["permissions"])
    assert "material.publish" in pm and "members.manage" not in pm
    assert "members.manage" in set(
        client.get("/auth/me", headers=seller["headers"]).json()["permissions"]
    )
    assert {"material.draft", "material.confirm", "ai.analyze", "reservation.read"} <= pe
    assert not pe & {
        "material.publish",
        "material.archive",
        "reservation.approve",
        "analytics.read",
        "org.update",
    }


# ---------- role boundaries ----------


def test_member_drafts_and_confirms_but_cannot_publish_archive_or_edit_published(client, seller):
    member = add_member(client, seller["organization"]["id"], OrgRole.MEMBER)
    hm = member["headers"]
    m = ready_material(client, seller["headers"])  # owner prepared a confirmed draft
    r = client.post(f"/materials/{m['id']}/publish", json={"version": m["version"]}, headers=hm)
    assert r.status_code == 403 and r.json()["error"]["code"] == "FORBIDDEN"
    # authorization precedes business state: no 422 requirements leak, no version check
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 999}, headers=hm)
    assert r.status_code == 403
    assert (
        client.post(f"/materials/{m['id']}/archive", json={"version": 1}, headers=hm).status_code
        == 403
    )
    # drafts are allowed
    d = client.post("/materials", json={"name": "Черновик участника"}, headers=hm)
    assert d.status_code == 201
    did = d.json()["id"]
    assert (
        client.patch(
            f"/materials/{did}", json={"version": 1, "name": "Новое"}, headers=hm
        ).status_code
        == 200
    )
    assert (
        client.post(f"/materials/{did}/confirm", json={"version": 2}, headers=hm).status_code == 200
    )
    assert upload(client, hm, did).status_code == 201
    # published material: MEMBER cannot edit
    pub = published_material(client, seller["headers"])
    r = client.patch(
        f"/materials/{pub['id']}", json={"version": pub["version"], "name": "x"}, headers=hm
    )
    assert r.status_code == 403
    assert upload(client, hm, pub["id"]).status_code == 403
    assert client.get("/analytics/summary", headers=hm).status_code == 403
    assert client.patch("/organizations/me", json={"city": "Ош"}, headers=hm).status_code == 403
    assert client.get("/organizations/me", headers=hm).status_code == 200


def test_manager_can_publish_archive_but_owner_only_rights_absent(client, seller):
    mgr = add_member(client, seller["organization"]["id"], OrgRole.MANAGER)["headers"]
    m = ready_material(client, seller["headers"])
    assert (
        client.post(
            f"/materials/{m['id']}/publish", json={"version": m["version"]}, headers=mgr
        ).status_code
        == 200
    )
    assert client.get("/analytics/summary", headers=mgr).status_code == 200
    assert client.patch("/organizations/me", json={"city": "Ош"}, headers=mgr).status_code == 200
    assert (
        client.post(
            f"/materials/{m['id']}/archive", json={"version": m["version"]}, headers=mgr
        ).status_code
        == 200
    )


def test_role_escalation_is_not_possible(client, seller):
    org = seller["organization"]["id"]
    member = add_member(client, org, OrgRole.MEMBER)["headers"]
    # no field or route changes a membership role
    for body in (
        {"role": "OWNER"},
        {"membership_role": "OWNER"},
        {"kind": "buyer"},
        {"permissions": ["x"]},
    ):
        r = client.patch("/organizations/me", json=body, headers=member)
        assert r.status_code in (403, 422), body
        r = client.patch("/organizations/me", json=body, headers=seller["headers"])
        assert r.status_code == 422, body
    for path in ("/organizations/me/members", "/memberships", "/auth/me/role"):
        assert client.post(path, json={"role": "OWNER"}, headers=member).status_code in (404, 405)
    # registration cannot choose an org role or join an organization
    r = client.post(
        "/auth/register",
        json={
            "email": "x@example.test",
            "password": PASSWORD,
            "role": "enterprise",
            "membership_role": "OWNER",
            "organization_id": org,
            "organization": {"name": "n", "city": "c", "activity_type": "other"},
        },
    )
    assert r.status_code == 422
    # the legacy users.role is not a source of rights
    with Session(get_engine()) as db:
        u = db.scalar(select(User).where(User.email == seller["email"]))
        u.role = Role.admin
        db.commit()
    assert client.get("/admin/api/summary", headers=seller["headers"]).status_code == 403
    assert client.get("/materials", headers=seller["headers"]).status_code == 200
    with Session(get_engine()) as db:
        u = db.scalar(select(User).where(User.email == seller["email"]))
        u.role = Role.buyer
        db.commit()
    assert (
        client.post("/materials", json={"name": "ещё"}, headers=seller["headers"]).status_code
        == 201
    )
    me = client.get("/auth/me", headers=seller["headers"]).json()
    assert me["organization_kind"] == "supplier" and "reservation.create" not in me["permissions"]


def test_buyer_side_roles_and_cross_side_403(client, buyer, seller):
    member = add_member(client, buyer["organization"]["id"], OrgRole.MEMBER, Role.buyer)["headers"]
    assert client.get("/materials", headers=member).status_code == 200
    assert client.post("/buyer-requirements", json={}, headers=member).status_code == 403
    assert client.get("/analytics/summary", headers=member).status_code == 403
    assert client.get("/reservations", headers=member).status_code == 200
    # supplier side cannot use buyer routes
    assert client.post("/buyer-requirements", json={}, headers=seller["headers"]).status_code == 403
    assert client.post("/reservations", json={}, headers=seller["headers"]).status_code == 403


def test_cross_organization_is_404_even_for_owner_and_member(client, seller, seller2):
    m = new_material(client, seller["headers"])
    member2 = add_member(client, seller2["organization"]["id"], OrgRole.MEMBER)["headers"]
    for h in (seller2["headers"], member2):
        assert client.get(f"/materials/{m['id']}", headers=h).status_code == 404
        assert client.post(
            f"/materials/{m['id']}/publish", json={"version": 1}, headers=h
        ).status_code in (404, 403)
    # 404 precedes 403: a MEMBER of another org gets 404, not 403, for a foreign material
    r = client.post(f"/materials/{m['id']}/publish", json={"version": 1}, headers=member2)
    assert r.status_code == 404


# ---------- token and membership lifecycle ----------


def test_old_token_without_claims_other_than_sub_keeps_working(client, seller):
    settings = get_settings()
    token, _ = create_access_token(uuid.UUID(seller["user"]["id"]), settings)
    claims = jwt.decode(token, settings.jwt_secret.get_secret_value(), algorithms=["HS256"])
    assert set(claims) == {"sub", "iat", "exp"}  # no role, organization or permissions in the token
    h = {"Authorization": f"Bearer {token}"}
    assert client.get("/auth/me", headers=h).status_code == 200
    assert client.get("/materials", headers=h).status_code == 200


@pytest.mark.parametrize("status", [MembershipStatus.removed, MembershipStatus.suspended])
def test_token_without_active_membership_gets_403_code(client, seller, status):
    with Session(get_engine()) as db:
        m = db.scalar(
            select(OrganizationMembership).where(
                OrganizationMembership.user_id == uuid.UUID(seller["user"]["id"])
            )
        )
        m.status = status
        db.commit()
    for path in ("/auth/me", "/organizations/me", "/materials", "/analytics/summary"):
        r = client.get(path, headers=seller["headers"])
        assert r.status_code == 403, path
        assert r.json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP"
    assert client.get("/health").status_code == 200
    # login itself still works: the token stays valid, only business access is closed
    assert (
        client.post(
            "/auth/login", json={"email": seller["email"], "password": PASSWORD}
        ).status_code
        == 200
    )


def test_one_active_membership_per_user_enforced_by_database(client, seller, buyer):
    with Session(get_engine()) as db:
        db.add(
            OrganizationMembership(
                user_id=uuid.UUID(seller["user"]["id"]),
                organization_id=uuid.UUID(buyer["organization"]["id"]),
                role=OrgRole.MEMBER,
            )
        )
        with pytest.raises(Exception, match="uq_memberships_one_active_per_user"):
            db.commit()


# ---------- platform admin ----------


def test_platform_admin_is_separate_from_organizations(client, seller):
    acc = register(client, "enterprise")
    with Session(get_engine()) as db:
        user = db.scalar(select(User).where(User.email == acc["email"]))
        db.query(OrganizationMembership).filter_by(user_id=user.id).delete()
        db.add(PlatformAdmin(user_id=user.id))
        db.commit()
    h = login_headers(client, acc["email"])
    assert client.get("/admin/api/me", headers=h).status_code == 200
    # cannot act on behalf of an organization
    for method, path in (
        ("get", "/materials"),
        ("get", "/organizations/me"),
        ("get", "/auth/me"),
        ("post", "/materials"),
    ):
        r = getattr(client, method)(
            path, headers=h, **({"json": {"name": "x"}} if method == "post" else {})
        )
        assert r.status_code == 403 and r.json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP", path
    assert client.get("/admin/api/summary", headers=seller["headers"]).status_code == 403


def test_admin_access_change_is_audited(client, buyer):
    acc = register(client, "enterprise")
    with Session(get_engine()) as db:
        user = db.scalar(select(User).where(User.email == acc["email"]))
        db.add(PlatformAdmin(user_id=user.id))
        db.commit()
    h = login_headers(client, acc["email"])
    r = client.patch(
        f"/admin/api/users/{buyer['user']['id']}/access", json={"active": False}, headers=h
    )
    assert r.status_code == 200
    with Session(get_engine()) as db:
        row = db.scalar(select(AuditLog).where(AuditLog.action == "user.access_changed"))
        assert row.target_id == buyer["user"]["id"] and row.details == {
            "active_before": True,
            "active_after": False,
        }
        assert row.actor_user_id == uuid.UUID(acc["user"]["id"])


# ---------- migration of existing data ----------


def test_migration_gives_every_unambiguous_user_a_membership_and_flags_the_rest(client):
    cfg = Config("alembic.ini")
    command.downgrade(cfg, "0003")
    pw = hash_password(PASSWORD)
    engine = create_engine(os.environ["DATABASE_URL"])
    org = lambda n: f"a0000000-0000-0000-0000-00000000000{n}"  # noqa: E731
    usr = lambda n: f"b0000000-0000-0000-0000-00000000000{n}"  # noqa: E731
    with engine.begin() as c:
        for i, (name, act) in enumerate(
            [
                ("S", "garment_factory"),
                ("R", "recycler"),
                ("Adm", "other"),
                ("Conf", "workshop"),
                ("Orphan", "workshop"),
                ("EntRec", "recycler"),
                ("BuyG", "garment_factory"),
            ],
            start=1,
        ):
            c.execute(
                text(
                    "insert into organizations (id,name,city,activity_type,created_at,updated_at) values (:i,:n,'Бишкек',:a,now(),now())"
                ),
                {"i": org(i), "n": name, "a": act},
            )
        users = [
            (1, "enterprise", 1),
            (2, "buyer", 2),
            (3, "admin", 3),
            (4, "enterprise", 4),
            (5, "buyer", 4),
            (6, "enterprise", 6),
            (7, "buyer", 7),
        ]
        for n, role, o in users:
            c.execute(
                text(
                    "insert into users (id,email,password_hash,role,organization_id,active,email_confirmed,created_at) values (:i,:e,:p,:r,:o,true,true,now())"
                ),
                {"i": usr(n), "e": f"u{n}@x.test", "p": pw, "r": role, "o": org(o)},
            )
    token_before, _ = create_access_token(uuid.UUID(usr(1)), get_settings())  # issued "before" R1
    command.upgrade(cfg, "head")

    with Session(get_engine()) as db:
        active = {
            m.user_id: m
            for m in db.scalars(
                select(OrganizationMembership).where(
                    OrganizationMembership.status == MembershipStatus.active
                )
            )
        }
        for n in (1, 2, 7):  # every unambiguous non-admin user keeps access as OWNER
            assert active[uuid.UUID(usr(n))].role == OrgRole.OWNER
        kinds = {o.name: o.kind for o in db.scalars(select(Organization))}
        assert kinds["S"] == OrganizationKind.supplier
        assert kinds["R"] == OrganizationKind.buyer and kinds["BuyG"] == OrganizationKind.buyer
        assert kinds["Conf"] is None and kinds["EntRec"] is None and kinds["Orphan"] is None
        assert {uuid.UUID(usr(n)) for n in (3, 4, 5, 6)}.isdisjoint(active)
        assert db.get(PlatformAdmin, uuid.UUID(usr(3))) is not None
        flagged = {
            a.details["reason"]
            for a in db.scalars(select(AuditLog).where(AuditLog.action == "backfill.ambiguous"))
        }
        assert flagged == {"multiple_users", "no_users", "enterprise_recycler_contradiction"}
        assert db.get(User, uuid.UUID(usr(1))).default_organization_id == uuid.UUID(org(1))
        # legacy columns untouched
        assert db.get(User, uuid.UUID(usr(4))).role == Role.enterprise

    # token from before the migration still works and resolves context from the database
    h = {"Authorization": f"Bearer {token_before}"}
    me = client.get("/auth/me", headers=h).json()
    assert me["organization_kind"] == "supplier" and me["membership"]["role"] == "OWNER"
    # ambiguous users are told why, not 401
    r = client.post("/auth/login", json={"email": "u4@x.test", "password": PASSWORD})
    h4 = {"Authorization": f"Bearer {r.json()['access_token']}"}
    assert client.get("/materials", headers=h4).json()["error"]["code"] == "NO_ACTIVE_MEMBERSHIP"

    # rollback strategy: downgrade removes what the backfill created and nothing else
    command.downgrade(cfg, "0004")
    with Session(get_engine()) as db:
        assert db.scalar(text("select count(*) from organization_memberships")) == 0
        assert db.scalar(text("select count(*) from platform_admins")) == 0
        assert db.scalar(text("select count(*) from organizations where kind is not null")) == 0
    command.upgrade(cfg, "head")
    engine.dispose()


# ---------- approved A20-12/13: MEMBER planning and reservation requests ----------


def test_member_plans_without_side_effects_and_buyer_member_requests_reservation(
    client, seller, buyer
):
    from tests.integration.test_commerce import requirement, reserve

    org = seller["organization"]["id"]
    m = published_material(client, seller["headers"])
    req = requirement(client, buyer, max_kg="50.000")
    seller_member = add_member(client, org, OrgRole.MEMBER)["headers"]
    buyer_member = add_member(client, buyer["organization"]["id"], OrgRole.MEMBER)["headers"]

    perms = set(client.get("/auth/me", headers=seller_member).json()["permissions"])
    assert "planning.run" in perms and "reservation.approve" not in perms

    before = client.get("/materials/" + m["id"], headers=seller["headers"]).json()["balance"]
    match = client.post("/ai/match", json={"material_id": m["id"]}, headers=seller_member)
    assert match.status_code == 200, match.text
    assert match.json()["matches"][0]["requirement_id"] == req["id"]
    plan = client.post("/optimization/run", json={"material_ids": [m["id"]]}, headers=seller_member)
    assert plan.status_code == 201, plan.text

    # Planning proposes only: no reservation and no change of stock.
    assert client.get("/reservations", headers=buyer["headers"]).json()["total"] == 0
    after = client.get("/materials/" + m["id"], headers=seller["headers"]).json()["balance"]
    assert after == before

    # Buyer organizations do not plan; the supplier-side right stays on the supplier.
    denied = client.post(
        "/optimization/run", json={"material_ids": [m["id"]]}, headers=buyer_member
    )
    assert denied.status_code == 403 and denied.json()["error"]["code"] == "FORBIDDEN"

    # MEMBER may create a reservation request on the buyer side.
    created = reserve(client, {"headers": buyer_member}, m, req)
    assert created.status_code == 201, created.text
    assert client.get("/reservations", headers=buyer["headers"]).json()["total"] == 1
