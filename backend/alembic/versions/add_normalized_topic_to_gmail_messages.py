"""add_normalized_topic_to_gmail_messages

Revision ID: add_normalized_topic
Revises: e1fd433944f4
Create Date: 2026-02-15 16:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'add_normalized_topic'
down_revision: Union[str, Sequence[str], None] = 'e1fd433944f4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema - add normalized_topic field."""
    op.add_column(
        'gmail_messages',
        sa.Column('normalized_topic', sa.String(), nullable=False, server_default='OTHER')
    )


def downgrade() -> None:
    """Downgrade schema - remove normalized_topic field."""
    op.drop_column('gmail_messages', 'normalized_topic')
