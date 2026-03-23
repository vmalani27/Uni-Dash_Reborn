"""merge heads

Revision ID: fd98ab532b75
Revises: 31843f5a52cc, 7464a2e3a03b
Create Date: 2026-03-23 07:54:18.592332

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fd98ab532b75'
down_revision: Union[str, Sequence[str], None] = ('31843f5a52cc', '7464a2e3a03b')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
