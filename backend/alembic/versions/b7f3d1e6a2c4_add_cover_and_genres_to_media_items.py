"""add cover and genres to media items

Revision ID: b7f3d1e6a2c4
Revises: a4f2c9d1e7b0
Create Date: 2026-05-07 17:13:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "b7f3d1e6a2c4"
down_revision: Union[str, Sequence[str], None] = "a4f2c9d1e7b0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("media_items", sa.Column("cover_url", sa.String(length=1024), nullable=True))
    op.add_column("media_items", sa.Column("genres", postgresql.JSONB(astext_type=sa.Text()), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("media_items", "genres")
    op.drop_column("media_items", "cover_url")
