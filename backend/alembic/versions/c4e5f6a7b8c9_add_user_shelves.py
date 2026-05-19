"""add user shelves tables

Revision ID: c4e5f6a7b8c9
Revises: b2c8d4e5f6a1
Create Date: 2026-05-20 10:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "c4e5f6a7b8c9"
down_revision: Union[str, Sequence[str], None] = "b2c8d4e5f6a1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_shelves",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_shelves_user_id", "user_shelves", ["user_id"])

    op.create_table(
        "user_shelf_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("shelf_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("media_item_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["shelf_id"], ["user_shelves.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["media_item_id"], ["media_items.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("shelf_id", "media_item_id", name="uq_user_shelf_items_shelf_media"),
    )
    op.create_index("ix_user_shelf_items_shelf_id", "user_shelf_items", ["shelf_id"])
    op.create_index("ix_user_shelf_items_media_item_id", "user_shelf_items", ["media_item_id"])
    op.alter_column("user_shelf_items", "position", server_default=None)


def downgrade() -> None:
    op.drop_table("user_shelf_items")
    op.drop_table("user_shelves")
