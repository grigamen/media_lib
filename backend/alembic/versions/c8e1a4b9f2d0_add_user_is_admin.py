"""add is_admin to users

Revision ID: c8e1a4b9f2d0
Revises: b7f3d1e6a2c4
Create Date: 2026-05-09

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "c8e1a4b9f2d0"
down_revision: Union[str, Sequence[str], None] = "b7f3d1e6a2c4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("is_admin", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.alter_column("users", "is_admin", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "is_admin")
