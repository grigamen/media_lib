"""add moderation_status to media_items

Revision ID: e9b2c4d8f1a3
Revises: c8e1a4b9f2d0
Create Date: 2026-05-09

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e9b2c4d8f1a3"
down_revision: Union[str, Sequence[str], None] = "c8e1a4b9f2d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "media_items",
        sa.Column(
            "moderation_status",
            sa.String(length=20),
            nullable=False,
            server_default="approved",
        ),
    )
    op.alter_column("media_items", "moderation_status", server_default=None)


def downgrade() -> None:
    op.drop_column("media_items", "moderation_status")
