"""add_academic_score_to_gmail_messages

Revision ID: e1fd433944f4
Revises: 12b711ad091d
Create Date: 2026-02-15 13:58:04.489301

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1fd433944f4'
down_revision: Union[str, Sequence[str], None] = '12b711ad091d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add academic_score field to gmail_messages table
    op.add_column('gmail_messages', sa.Column('academic_score', sa.Integer(), nullable=True, default=0))


def downgrade() -> None:
    """Downgrade schema."""
    # Remove academic_score field from gmail_messages table
    op.drop_column('gmail_messages', 'academic_score')
