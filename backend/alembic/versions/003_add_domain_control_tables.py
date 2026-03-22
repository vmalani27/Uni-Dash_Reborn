"""Add domain control tables for global defaults + user overrides.

Revision ID: 003_add_domain_tables
Revises: 2b9620d703df
Create Date: 2026-03-17

Purpose:
    Replace static hardcoded lists with database-driven control layer.
    - `domains`: Global defaults (coursera, unstop, etc.)
    - `user_domain_preferences`: Per-user overrides (marks domain as trusted/blocked)
    
Philosophy:
    - Code holds TLD patterns (.ac.in, .edu)
    - DB holds dynamic lists and user customization
    - No ML/learning — just control.
"""

from alembic import op
import sqlalchemy as sa


revision = "003_add_domain_tables"
down_revision = "2b9620d703df"
branch_labels = None
depends_on = None


def upgrade():
    # Create domains table
    op.create_table(
        "domains",
        sa.Column("id", sa.Integer(), nullable=False, primary_key=True),
        sa.Column("domain", sa.String(), nullable=False, unique=True, index=True),
        sa.Column(
            "source_type",
            sa.String(),
            nullable=False,
            comment="'institution' | 'student' | 'external_academic' | 'external_misc'",
        ),
        sa.Column("is_default_trusted", sa.Boolean(), default=False, nullable=False),
        sa.Column("priority", sa.Integer(), default=0, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
            onupdate=sa.func.now(),
        ),
    )

    # Create user_domain_preferences table
    op.create_table(
        "user_domain_preferences",
        sa.Column("id", sa.Integer(), nullable=False, primary_key=True),
        sa.Column("user_id", sa.String(), nullable=False, index=True),
        sa.Column("domain", sa.String(), nullable=False, index=True),
        sa.Column(
            "is_trusted",
            sa.Boolean(),
            default=False,
            nullable=False,
            comment="User marked this domain as important",
        ),
        sa.Column(
            "is_blocked",
            sa.Boolean(),
            default=False,
            nullable=False,
            comment="User blocked this domain",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
            onupdate=sa.func.now(),
        ),
        sa.UniqueConstraint("user_id", "domain", name="uq_user_domain"),
    )

    # Create index for common queries
    op.create_index("idx_user_domain", "user_domain_preferences", ["user_id", "domain"])


def downgrade():
    op.drop_table("user_domain_preferences")
    op.drop_table("domains")
