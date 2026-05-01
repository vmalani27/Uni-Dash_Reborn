"""add source_ai_processed_at to academic_items

Revision ID: 6c2f2a5a1b31
Revises: 024f0eea0fa2
Create Date: 2026-04-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "6c2f2a5a1b31"
down_revision: Union[str, Sequence[str], None] = "024f0eea0fa2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "academic_items",
        sa.Column("source_ai_processed_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("academic_items", "source_ai_processed_at")
