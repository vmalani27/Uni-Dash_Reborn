"""merge all heads

Revision ID: 7464a2e3a03b
Revises: 04ca7add4d79, 5aa92243160b, 73f317040bfb, 8bbe4a2ce09c, add_normalized_topic, dd23fb267d0a
Create Date: 2026-03-17 18:44:29.639937

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7464a2e3a03b'
down_revision: Union[str, Sequence[str], None] = ('04ca7add4d79', '5aa92243160b', '73f317040bfb', '8bbe4a2ce09c', 'add_normalized_topic', 'dd23fb267d0a')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
