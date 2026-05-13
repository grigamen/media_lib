"""add twofa_email_challenges table

Revision ID: f1a2b3c4d5e6
Revises: e9b2c4d8f1a3
Create Date: 2026-05-13

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "e9b2c4d8f1a3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "twofa_email_challenges",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("purpose", sa.String(length=32), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_sent_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_twofa_email_challenges_user_id",
        "twofa_email_challenges",
        ["user_id"],
    )
    op.create_index(
        "ix_twofa_email_challenges_purpose",
        "twofa_email_challenges",
        ["purpose"],
    )


def downgrade() -> None:
    op.drop_index("ix_twofa_email_challenges_purpose", table_name="twofa_email_challenges")
    op.drop_index("ix_twofa_email_challenges_user_id", table_name="twofa_email_challenges")
    op.drop_table("twofa_email_challenges")
