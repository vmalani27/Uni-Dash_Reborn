"""add composite index

Revision ID: d0019706a7ed
Revises: 82cde58a7208
Create Date: 2026-02-04 10:37:51.108445

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd0019706a7ed'
down_revision: Union[str, Sequence[str], None] = '82cde58a7208'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
