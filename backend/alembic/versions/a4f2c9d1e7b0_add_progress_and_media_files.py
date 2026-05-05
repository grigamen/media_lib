"""add progress and media files

Revision ID: a4f2c9d1e7b0
Revises: 95a38ae1f9a2
Create Date: 2026-05-05 08:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a4f2c9d1e7b0"
down_revision: Union[str, Sequence[str], None] = "95a38ae1f9a2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "media_files",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("media_item_id", sa.UUID(), nullable=False),
        sa.Column("storage_provider", sa.String(length=32), nullable=False),
        sa.Column("storage_bucket", sa.String(length=255), nullable=False),
        sa.Column("storage_key", sa.String(length=1024), nullable=False),
        sa.Column("content_type", sa.String(length=255), nullable=False),
        sa.Column("file_size", sa.Integer(), nullable=True),
        sa.Column("upload_status", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["media_item_id"], ["media_items.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("storage_key"),
    )
    op.create_index(op.f("ix_media_files_media_item_id"), "media_files", ["media_item_id"], unique=False)
    op.create_index(op.f("ix_media_files_user_id"), "media_files", ["user_id"], unique=False)

    op.create_table(
        "progress",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("media_item_id", sa.UUID(), nullable=False),
        sa.Column("position_seconds", sa.Integer(), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("progress_percent", sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column("is_completed", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["media_item_id"], ["media_items.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "media_item_id", name="uq_progress_user_media"),
    )
    op.create_index(op.f("ix_progress_media_item_id"), "progress", ["media_item_id"], unique=False)
    op.create_index(op.f("ix_progress_user_id"), "progress", ["user_id"], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_progress_user_id"), table_name="progress")
    op.drop_index(op.f("ix_progress_media_item_id"), table_name="progress")
    op.drop_table("progress")

    op.drop_index(op.f("ix_media_files_user_id"), table_name="media_files")
    op.drop_index(op.f("ix_media_files_media_item_id"), table_name="media_files")
    op.drop_table("media_files")
