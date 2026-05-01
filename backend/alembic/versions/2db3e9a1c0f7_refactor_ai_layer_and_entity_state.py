"""refactor ai layer and entity state

Revision ID: 2db3e9a1c0f7
Revises: fcc4b7702e5a
Create Date: 2026-04-26 12:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "2db3e9a1c0f7"
down_revision: Union[str, Sequence[str], None] = "fcc4b7702e5a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "academic_entities",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("uid", sa.String(), nullable=False),
        sa.Column("canonical_title", sa.String(), nullable=False),
        sa.Column("entity_type", sa.String(), nullable=False),
        sa.Column("best_deadline", sa.DateTime(), nullable=True),
        sa.Column("confidence_score", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_academic_entities_best_deadline"), "academic_entities", ["best_deadline"], unique=False)
    op.create_index(op.f("ix_academic_entities_canonical_title"), "academic_entities", ["canonical_title"], unique=False)
    op.create_index(op.f("ix_academic_entities_entity_type"), "academic_entities", ["entity_type"], unique=False)
    op.create_index(op.f("ix_academic_entities_uid"), "academic_entities", ["uid"], unique=False)

    op.create_table(
        "entity_source_map",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=False),
        sa.Column("source_email_id", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["entity_id"], ["academic_entities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["source_email_id"], ["gmail_messages.gmail_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("entity_id", "source_email_id", name="uq_entity_source_map_entity_email"),
    )
    op.create_index(op.f("ix_entity_source_map_entity_id"), "entity_source_map", ["entity_id"], unique=False)
    op.create_index(op.f("ix_entity_source_map_source_email_id"), "entity_source_map", ["source_email_id"], unique=False)

    op.create_table(
        "extracted_signals",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("source_email_id", sa.String(), nullable=False),
        sa.Column("uid", sa.String(), nullable=False),
        sa.Column("raw_llm_output", sa.JSON(), nullable=True),
        sa.Column("extracted_dates", sa.JSON(), nullable=True),
        sa.Column("extracted_entities", sa.JSON(), nullable=True),
        sa.Column("intent", sa.String(), nullable=True),
        sa.Column("type_candidates", sa.JSON(), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["source_email_id"], ["gmail_messages.gmail_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_extracted_signals_created_at"), "extracted_signals", ["created_at"], unique=False)
    op.create_index(op.f("ix_extracted_signals_intent"), "extracted_signals", ["intent"], unique=False)
    op.create_index(op.f("ix_extracted_signals_source_email_id"), "extracted_signals", ["source_email_id"], unique=False)
    op.create_index(op.f("ix_extracted_signals_uid"), "extracted_signals", ["uid"], unique=False)

    op.create_table(
        "entity_action_state",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=False),
        sa.Column("uid", sa.String(), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False),
        sa.Column("dismissed", sa.Boolean(), nullable=False),
        sa.Column("snoozed_until", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["entity_id"], ["academic_entities.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("entity_id", "uid", name="uq_entity_action_state_entity_uid"),
    )
    op.create_index(op.f("ix_entity_action_state_uid"), "entity_action_state", ["uid"], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_entity_action_state_uid"), table_name="entity_action_state")
    op.drop_table("entity_action_state")

    op.drop_index(op.f("ix_extracted_signals_uid"), table_name="extracted_signals")
    op.drop_index(op.f("ix_extracted_signals_source_email_id"), table_name="extracted_signals")
    op.drop_index(op.f("ix_extracted_signals_intent"), table_name="extracted_signals")
    op.drop_index(op.f("ix_extracted_signals_created_at"), table_name="extracted_signals")
    op.drop_table("extracted_signals")

    op.drop_index(op.f("ix_entity_source_map_source_email_id"), table_name="entity_source_map")
    op.drop_index(op.f("ix_entity_source_map_entity_id"), table_name="entity_source_map")
    op.drop_table("entity_source_map")

    op.drop_index(op.f("ix_academic_entities_uid"), table_name="academic_entities")
    op.drop_index(op.f("ix_academic_entities_entity_type"), table_name="academic_entities")
    op.drop_index(op.f("ix_academic_entities_canonical_title"), table_name="academic_entities")
    op.drop_index(op.f("ix_academic_entities_best_deadline"), table_name="academic_entities")
    op.drop_table("academic_entities")

