"""Domain control models.

Represents the control layer for domain classification:
- `Domain`: Global defaults (what source_type is each domain by default)
- `UserDomainPreference`: Per-user overrides (user trusts/blocks specific domains)
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, UniqueConstraint, Index
import datetime
from app.core.database import Base


class Domain(Base):
    """Global domain classification defaults.
    
    Purpose: NOT for learning, NOT for scoring.
    Purpose: Control layer — what is the default behavior for this domain?
    
    Examples:
        - coursera.org → external_academic (everyone sees it same way)
        - unstop.com → external_academic
        - charusat.ac.in → institution (pattern-based, but can override here)
    """

    __tablename__ = "domains"

    id = Column(Integer, primary_key=True)
    domain = Column(String, unique=True, nullable=False, index=True)

    # One of: 'institution', 'student', 'external_academic', 'external_misc'
    source_type = Column(String, nullable=False)

    # Is this domain trusted by default?
    is_default_trusted = Column(Boolean, default=False, nullable=False)

    # Optional tuning (lower = higher priority in queue later)
    priority = Column(Integer, default=0, nullable=False)

    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.datetime.utcnow,
        onupdate=datetime.datetime.utcnow,
        nullable=False,
    )


class UserDomainPreference(Base):
    """Per-user domain preferences — overrides global defaults.
    
    Purpose: User control — mark domains as trusted or blocked
    
    Examples:
        - user marks AWS SES mails as "is_trusted" (otherwise would be external_misc)
        - user marks recruiting emails as "is_blocked" (ignore them)
    """

    __tablename__ = "user_domain_preferences"

    id = Column(Integer, primary_key=True)
    user_id = Column(String, nullable=False, index=True)
    domain = Column(String, nullable=False, index=True)

    # User trusts this domain (treat as external_academic if not institutional)
    is_trusted = Column(Boolean, default=False, nullable=False)

    # User blocked this domain (treat as external_misc regardless)
    is_blocked = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.datetime.utcnow,
        onupdate=datetime.datetime.utcnow,
        nullable=False,
    )

    # Ensure user can only have one preference per domain
    __table_args__ = (UniqueConstraint("user_id", "domain", name="uq_user_domain"),)
