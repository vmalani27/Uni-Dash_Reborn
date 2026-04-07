"""add academic lifecycle fields

Revision ID: c1a9fb1d2a44
Revises: 57f6b8017058
Create Date: 2026-04-06 20:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c1a9fb1d2a44'
down_revision: Union[str, Sequence[str], None] = '57f6b8017058'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('academic_items', sa.Column('status', sa.String(), nullable=True))
    op.add_column('academic_items', sa.Column('snoozed_until', sa.DateTime(), nullable=True))
    op.add_column('academic_items', sa.Column('last_updated_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('academic_items', 'last_updated_at')
    op.drop_column('academic_items', 'snoozed_until')
    op.drop_column('academic_items', 'status')