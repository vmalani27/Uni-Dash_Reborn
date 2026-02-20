"""add_deadline_fields_to_gmail_messages

Revision ID: 12b711ad091d
Revises: 691a2180ae91
Create Date: 2026-02-15 13:36:48.246065

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '12b711ad091d'
down_revision: Union[str, Sequence[str], None] = '691a2180ae91'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add deadline fields to gmail_messages table
    op.add_column('gmail_messages', sa.Column('deadline_iso', sa.DateTime(), nullable=True))
    op.add_column('gmail_messages', sa.Column('deadline_confidence', sa.String(), nullable=True, default='None'))


def downgrade() -> None:
    """Downgrade schema."""
    # Remove deadline fields from gmail_messages table
    op.drop_column('gmail_messages', 'deadline_confidence')
    op.drop_column('gmail_messages', 'deadline_iso')
