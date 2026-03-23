"""Drop domain_stats table - no longer needed with simplified domain classification.

Revision ID: 004_drop_domain_stats
Revises: 003_add_domain_tables
Create Date: 2026-03-17

Reason:
    The old system tracked behavioral stats (deadline_count, high_score_count) to 
    calculate trust scores. The new system uses deterministic classification based on 
    academic role (institutional, student, external platform, misc).
    
    DomainStats is now obsolete and can be safely dropped.
"""
from alembic import op
import sqlalchemy as sa


revision = "004_drop_domain_stats"
down_revision = "003_add_domain_tables"
branch_labels = None
depends_on = None


def upgrade():
    op.drop_table("domain_stats")


def downgrade():
    op.create_table(
        "domain_stats",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("domain", sa.String(), nullable=True),
        sa.Column("total_emails", sa.Integer(), nullable=True),
        sa.Column("deadline_count", sa.Integer(), nullable=True),
        sa.Column("high_score_count", sa.Integer(), nullable=True),
        sa.Column("last_computed_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("domain"),
    )
    op.create_index("ix_domain_stats_domain", "domain_stats", ["domain"])
