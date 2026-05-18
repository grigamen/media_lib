"""add per-user star rating on progress

Revision ID: a9c3e21f7b44
Revises: f1a2b3c4d5e6
Create Date: 2026-05-18 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a9c3e21f7b44"
down_revision: Union[str, Sequence[str], None] = "f1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "progress",
        sa.Column("rating_stars", sa.SmallInteger(), nullable=True),
    )
    op.create_check_constraint(
        "ck_progress_rating_stars_range",
        "progress",
        "rating_stars IS NULL OR (rating_stars >= 1 AND rating_stars <= 5)",
    )


def downgrade() -> None:
    op.drop_constraint("ck_progress_rating_stars_range", "progress", type_="check")
    op.drop_column("progress", "rating_stars")
