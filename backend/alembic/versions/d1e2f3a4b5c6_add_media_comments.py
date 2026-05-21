"""add media comments

Revision ID: d1e2f3a4b5c6
Revises: c4e5f6a7b8c9
Create Date: 2026-05-21 08:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "d1e2f3a4b5c6"
down_revision: Union[str, Sequence[str], None] = "c4e5f6a7b8c9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "media_comments",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("media_item_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("author_display_name", sa.String(length=120), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["media_item_id"], ["media_items.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_media_comments_media_item_id", "media_comments", ["media_item_id"])
    op.create_index("ix_media_comments_user_id", "media_comments", ["user_id"])
    op.create_index(
        "ix_media_comments_media_created",
        "media_comments",
        ["media_item_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_media_comments_media_created", table_name="media_comments")
    op.drop_index("ix_media_comments_user_id", table_name="media_comments")
    op.drop_index("ix_media_comments_media_item_id", table_name="media_comments")
    op.drop_table("media_comments")
