"""add_new_messages_count_to_sync_status

Revision ID: 691a2180ae91
Revises: 049e266e0428
Create Date: 2026-02-15 09:40:53.123315

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '691a2180ae91'
down_revision: Union[str, Sequence[str], None] = '049e266e0428'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add new_messages_count column to gmail_sync_status table
    op.add_column('gmail_sync_status', sa.Column('new_messages_count', sa.Integer(), nullable=True, default=0))


def downgrade() -> None:
    """Downgrade schema."""
    # Remove new_messages_count column from gmail_sync_status table
    op.drop_column('gmail_sync_status', 'new_messages_count')
