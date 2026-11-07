"""email_confirmation

Revision ID: 0003
Revises: c9c7720aa55d
"""

import sqlalchemy as sa
from alembic import op

revision = "0003"
down_revision = "c9c7720aa55d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("email_confirmed", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "users", sa.Column("email_confirmed_at", sa.DateTime(timezone=True), nullable=True)
    )
    # Accounts that exist before the feature (including admin) are treated as confirmed (A23-11).
    op.execute("UPDATE users SET email_confirmed = true, email_confirmed_at = now()")
    op.create_table(
        "email_codes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("failed_attempts", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("locked_until", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_email_codes_user_created", "email_codes", ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_email_codes_user_created", table_name="email_codes")
    op.drop_table("email_codes")
    op.drop_column("users", "email_confirmed_at")
    op.drop_column("users", "email_confirmed")
