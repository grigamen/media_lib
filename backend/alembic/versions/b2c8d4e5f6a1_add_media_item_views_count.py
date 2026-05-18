"""add views_count to media_items

Revision ID: b2c8d4e5f6a1
Revises: a9c3e21f7b44
Create Date: 2026-05-19 10:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b2c8d4e5f6a1"
down_revision: Union[str, Sequence[str], None] = "a9c3e21f7b44"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "media_items",
        sa.Column("views_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.alter_column("media_items", "views_count", server_default=None)


def downgrade() -> None:
    op.drop_column("media_items", "views_count")
