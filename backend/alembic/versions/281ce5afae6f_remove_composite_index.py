"""remove composite index

Revision ID: 281ce5afae6f
Revises: d0019706a7ed
Create Date: 2026-02-04 10:39:18.401104

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '281ce5afae6f'
down_revision: Union[str, Sequence[str], None] = 'd0019706a7ed'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
