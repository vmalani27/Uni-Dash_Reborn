"""add_unidash_broadcast_id_to_gmail_messages

Revision ID: 04ca7add4d79
Revises: e1fd433944f4
Create Date: 2026-03-17 18:35:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '04ca7add4d79'
down_revision: Union[str, Sequence[str], None] = 'e1fd433944f4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('gmail_messages', sa.Column('unidash_broadcast_id', sa.String(), nullable=True))
    op.create_index(op.f('ix_gmail_messages_unidash_broadcast_id'), 'gmail_messages', ['unidash_broadcast_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_gmail_messages_unidash_broadcast_id'), table_name='gmail_messages')
    op.drop_column('gmail_messages', 'unidash_broadcast_id')
