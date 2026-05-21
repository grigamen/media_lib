"""add authors catalog

Revision ID: f3a4b5c6d7e8
Revises: e2f3a4b5c6d7
Create Date: 2026-05-21 18:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "f3a4b5c6d7e8"
down_revision: Union[str, Sequence[str], None] = "e2f3a4b5c6d7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "authors",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("name_normalized", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name_normalized"),
    )
    op.create_index("ix_authors_name_normalized", "authors", ["name_normalized"], unique=True)

    op.add_column("media_items", sa.Column("author_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_index("ix_media_items_author_id", "media_items", ["author_id"])
    op.create_foreign_key(
        "fk_media_items_author_id_authors",
        "media_items",
        "authors",
        ["author_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.execute(
        """
        INSERT INTO authors (id, name, name_normalized, created_at)
        SELECT gen_random_uuid(), sub.name, lower(trim(sub.name)), TIMEZONE('utc', NOW())
        FROM (
            SELECT DISTINCT trim(author) AS name
            FROM media_items
            WHERE author IS NOT NULL AND trim(author) <> ''
        ) sub
        ON CONFLICT (name_normalized) DO NOTHING
        """
    )
    op.execute(
        """
        UPDATE media_items AS mi
        SET author_id = a.id
        FROM authors AS a
        WHERE mi.author IS NOT NULL
          AND trim(mi.author) <> ''
          AND a.name_normalized = lower(trim(mi.author))
        """
    )


def downgrade() -> None:
    op.drop_constraint("fk_media_items_author_id_authors", "media_items", type_="foreignkey")
    op.drop_index("ix_media_items_author_id", table_name="media_items")
    op.drop_column("media_items", "author_id")
    op.drop_index("ix_authors_name_normalized", table_name="authors")
    op.drop_table("authors")
