"""PENDING_REVIEW memberships for users the R1 backfill could not classify

Revision ID: 0006
Revises: 0005

Every non-admin user who has no membership after 0005 (their organization was ambiguous) gets a
membership with status 'pending_review', role MEMBER, pointing at their original organization.
The organization kind stays NULL and no rights derive from it. Nothing is activated
automatically; a platform admin does that (/admin/api/memberships/{id}/activate).

Deterministic (ordered by created_at, id), idempotent (NOT EXISTS guard + unique constraints) and
atomic (PostgreSQL transactional DDL: a partial failure rolls the whole revision back).
"""

import json
import logging
import uuid

import sqlalchemy as sa
from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None

log = logging.getLogger("alembic.runtime.migration")
STATUSES = ("active", "pending_review", "suspended", "removed")


def _swap_status_check(values: tuple[str, ...]) -> None:
    name = "ck_organization_memberships_membership_status"
    op.drop_constraint(op.f(name), "organization_memberships", type_="check")
    listed = ", ".join(f"'{v}'" for v in values)
    op.create_check_constraint(op.f(name), "organization_memberships", f"status IN ({listed})")


def upgrade() -> None:
    _swap_status_check(STATUSES)
    op.drop_index("uq_memberships_one_active_per_user", table_name="organization_memberships")
    op.create_index(
        "uq_memberships_one_active_per_user",
        "organization_memberships",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status IN ('active', 'pending_review')"),
    )

    conn = op.get_bind()
    rows = conn.execute(
        sa.text(
            "SELECT u.id, u.organization_id, o.kind, o.activity_type FROM users u"
            " JOIN organizations o ON o.id = u.organization_id"
            " WHERE u.role <> 'admin'"
            "   AND NOT EXISTS (SELECT 1 FROM organization_memberships m WHERE m.user_id = u.id)"
            " ORDER BY u.created_at, u.id"
        )
    ).all()
    for r in rows:
        mid = uuid.uuid4()
        conn.execute(
            sa.text(
                "INSERT INTO organization_memberships (id, user_id, organization_id, role,"
                " status, created_at) VALUES (:id, :u, :o, 'MEMBER', 'pending_review', now())"
                " ON CONFLICT DO NOTHING"
            ),
            {"id": mid, "u": r.id, "o": r.organization_id},
        )
        conn.execute(
            sa.text(
                "UPDATE users SET default_organization_id = :o"
                " WHERE id = :u AND default_organization_id IS NULL"
            ),
            {"o": r.organization_id, "u": r.id},
        )
        conn.execute(
            sa.text(
                "INSERT INTO audit_log (id, organization_id, action, target_type, target_id,"
                " details, created_at) VALUES (:id, :o, 'backfill.pending_review', 'membership',"
                " :t, CAST(:d AS json), now())"
            ),
            {
                "id": uuid.uuid4(),
                "o": r.organization_id,
                "t": str(mid),
                "d": json.dumps({"user_id": str(r.id), "kind_assigned": False}),
            },
        )
    log.warning("R1 pending-review backfill: %s memberships created", len(rows))
    lost = conn.execute(
        sa.text(
            "SELECT count(*) FROM users u WHERE u.role <> 'admin' AND NOT EXISTS ("
            " SELECT 1 FROM organization_memberships m WHERE m.user_id = u.id)"
        )
    ).scalar_one()
    if lost:  # guard: never finish with a user who lost the link to the organization
        raise RuntimeError(f"{lost} non-admin users without membership; aborting")


def downgrade() -> None:
    conn = op.get_bind()
    conn.execute(
        sa.text(
            "DELETE FROM organization_memberships WHERE id::text IN ("
            " SELECT target_id FROM audit_log WHERE action = 'backfill.pending_review')"
        )
    )
    conn.execute(sa.text("DELETE FROM audit_log WHERE action = 'backfill.pending_review'"))
    # Rows activated or created after 0006 in these states cannot survive the narrower check.
    conn.execute(sa.text("DELETE FROM organization_memberships WHERE status = 'pending_review'"))
    op.drop_index("uq_memberships_one_active_per_user", table_name="organization_memberships")
    op.create_index(
        "uq_memberships_one_active_per_user",
        "organization_memberships",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status = 'active'"),
    )
    _swap_status_check(("active", "suspended", "removed"))
