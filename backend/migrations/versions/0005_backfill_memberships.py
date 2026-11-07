"""backfill organization kind, OWNER memberships and platform admins

Revision ID: 0005
Revises: 0004

Rules (docs/api.md 20.12):
- enterprise -> supplier, buyer -> buyer (a recycler stays a buyer with activity_type=recycler);
- the only non-admin user of an organization becomes its OWNER;
- users.role = admin -> platform_admins row, no membership;
- anything else is left untouched and written to audit_log as action 'backfill.ambiguous'
  (reasons: no_users, multiple_users, admin_mixed_with_users, enterprise_recycler_contradiction).
Nothing is classified silently under uncertainty. users.role / organization_id are not modified.
"""

import json
import logging
import uuid

import sqlalchemy as sa
from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None

log = logging.getLogger("alembic.runtime.migration")
KIND = {"enterprise": "supplier", "buyer": "buyer"}


def _audit(conn, action, org_id=None, target_type=None, target_id=None, details=None):
    conn.execute(
        sa.text(
            "INSERT INTO audit_log (id, organization_id, action, target_type, target_id,"
            " details, created_at) VALUES (:id, :org, :a, :tt, :ti, CAST(:d AS json), now())"
        ),
        {
            "id": uuid.uuid4(),
            "org": org_id,
            "a": action,
            "tt": target_type,
            "ti": str(target_id) if target_id else None,
            "d": json.dumps(details or {}),
        },
    )


def upgrade() -> None:
    conn = op.get_bind()
    orgs = conn.execute(sa.text("SELECT id, activity_type FROM organizations ORDER BY id")).all()
    users = conn.execute(
        sa.text("SELECT id, role, organization_id FROM users ORDER BY created_at, id")
    ).all()
    by_org: dict = {}
    for u in users:
        by_org.setdefault(u.organization_id, []).append(u)

    for u in users:
        if u.role == "admin":
            res = conn.execute(
                sa.text(
                    "INSERT INTO platform_admins (user_id, granted_at) VALUES (:u, now())"
                    " ON CONFLICT DO NOTHING"
                ),
                {"u": u.id},
            )
            if res.rowcount:
                _audit(conn, "backfill.platform_admin", None, "user", u.id)

    counts = {"classified": 0, "ambiguous": 0, "admin_only": 0}
    for org in orgs:
        members = by_org.get(org.id, [])
        humans = [u for u in members if u.role != "admin"]
        reason = None
        if not members:
            reason = "no_users"
        elif not humans:
            counts["admin_only"] += 1
            _audit(conn, "backfill.platform_admin_organization", org.id, "organization", org.id)
            continue
        elif len(humans) != len(members):
            reason = "admin_mixed_with_users"
        elif len(humans) > 1:
            reason = "multiple_users"
        else:
            user = humans[0]
            if user.role == "enterprise" and org.activity_type == "recycler":
                reason = "enterprise_recycler_contradiction"
        if reason:
            counts["ambiguous"] += 1
            roles = sorted({u.role for u in members})
            _audit(
                conn,
                "backfill.ambiguous",
                org.id,
                "organization",
                org.id,
                {"reason": reason, "user_count": len(members), "user_roles": roles},
            )
            log.warning("R1 backfill: organization %s needs manual review (%s)", org.id, reason)
            continue

        user = humans[0]
        kind = KIND[user.role]
        mid = uuid.uuid4()
        conn.execute(
            sa.text("UPDATE organizations SET kind = :k WHERE id = :o AND kind IS NULL"),
            {"k": kind, "o": org.id},
        )
        conn.execute(
            sa.text(
                "INSERT INTO organization_memberships (id, user_id, organization_id, role,"
                " status, created_at) VALUES (:id, :u, :o, 'OWNER', 'active', now())"
                " ON CONFLICT DO NOTHING"
            ),
            {"id": mid, "u": user.id, "o": org.id},
        )
        conn.execute(
            sa.text(
                "UPDATE users SET default_organization_id = :o"
                " WHERE id = :u AND default_organization_id IS NULL"
            ),
            {"o": org.id, "u": user.id},
        )
        _audit(
            conn,
            "backfill.membership",
            org.id,
            "membership",
            mid,
            {"kind": kind, "role": "OWNER", "user_id": str(user.id)},
        )
        if kind == "buyer" and org.activity_type == "garment_factory":
            _audit(
                conn,
                "backfill.warning",
                org.id,
                "organization",
                org.id,
                {"reason": "buyer_with_garment_factory_activity", "assigned_kind": kind},
            )
        counts["classified"] += 1
    log.warning("R1 backfill report: %s", counts)


def downgrade() -> None:
    conn = op.get_bind()
    # Remove only what the backfill created; rows made later by registration stay until 0004
    # is downgraded as well.
    conn.execute(
        sa.text(
            "UPDATE users SET default_organization_id = NULL WHERE id IN ("
            " SELECT (details->>'user_id')::uuid FROM audit_log WHERE action = 'backfill.membership')"
        )
    )
    conn.execute(
        sa.text(
            "DELETE FROM organization_memberships WHERE id::text IN ("
            " SELECT target_id FROM audit_log WHERE action = 'backfill.membership')"
        )
    )
    conn.execute(
        sa.text(
            "UPDATE organizations SET kind = NULL WHERE id IN ("
            " SELECT organization_id FROM audit_log WHERE action = 'backfill.membership')"
        )
    )
    conn.execute(
        sa.text(
            "DELETE FROM platform_admins WHERE user_id::text IN ("
            " SELECT target_id FROM audit_log WHERE action = 'backfill.platform_admin')"
        )
    )
    conn.execute(sa.text("DELETE FROM audit_log WHERE action LIKE 'backfill.%'"))
