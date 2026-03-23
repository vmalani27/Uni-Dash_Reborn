# app/services/domain_trust_scorer.py
"""
Domain Classification — Maps email sender domains to their role in academic life.

Philosophy:
    This system is NOT a trust/spam filter.
    This is for relevance of notifications
    
    Question: What is the sender's role in this student's academic life?
    
    Answers:
    1. Institutional Sender     → Faculty, admin, official channels
    2. Student / Peer           → Other students, peer collaboration
    3. External Academic Platform → Coursera, Unstop, external recruiters
    4. External / Misc          → Everything else (newsletters, spam, etc.)
"""

import re
from dataclasses import dataclass
from typing import Optional, Set

# ── Configuration ────────────────────────────────────────────

# Patterns that identify institutional senders (faculty, admin)
INSTITUTIONAL_PATTERNS = [
    ".ac.in",
    ".edu",
    ".edu.in",
    ".ac.uk",
    ".edu.au",
]

# Patterns that identify student emails (peer collaboration)
STUDENT_PATTERNS = [
    ".edu.in",  # Adjust based on your university structure
]

# NOTE: External academic domains are now in the `domains` table
# Examples: coursera.org, unstop.com, linkedin.com, etc.
# This keeps the code configuration-free and allows DB-driven control.


@dataclass
class DomainProfile:
    """Classification result for an email sender domain.
    
    This is NOT a trust score.
    This is: What is this sender's role in the student's academic life?
    
    Attributes:
        domain: Email domain (e.g., 'charusat.ac.in')
        classification: One of 4 values:
            'Institutional Sender' → Faculty, admin, official university
            'Student / Peer' → Other students
            'External Academic Platform' → Coursera, Unstop, LinkedIn, job boards
            'External / Misc' → Everything else
        source_weight: Points awarded to academic score (context-dependent)
            - Institutional: 25 points (trusted, official)
            - Student/Peer: 15 points (peer relevance)
            - External Platform: 15 points (user-approved platforms)
            - External/Misc: 0 points (no academic value)
    """
    domain: str
    classification: str  # One of the 4 source types above
    
   
    
    @property
    def source_weight(self) -> float:
        """Points to award in academic score calculation.
        
        Note: This is SIMPLIFIED.
        We are not doing behavioral weighting.
        If a domain is institutional, it's institutional.
        """
        weights = {
            "Institutional Sender": 25.0,
            "Student / Peer": 15.0,
            "External Academic Platform": 15.0,
            "External / Misc": 0.0,
        }
        return weights.get(self.classification, 0.0)


class DomainTrustScorer:
    """Pattern-based domain classifier.
    
    Maps sender domains to their role in student's academic life.
    Simple, deterministic, no behavioral complexity.
    """

    @staticmethod
    def extract_domain(sender: str) -> str:
        """Extract domain from email address.
        
        Args:
            sender: Full email (e.g., 'prof@charusat.ac.in' or 'Prof Name <prof@...>')
        
        Returns:
            Domain string lowercase (e.g., 'charusat.ac.in'), or empty string if invalid
        """
        match = re.search(r'[\w.+-]+@([\w.-]+\.[a-z]{2,})', sender.lower())
        return match.group(1) if match else ""

    @staticmethod
    def classify_domain(domain: str) -> str:
        """Classify a domain by its academic role (pattern-based fallback).
        
        This is the fallback when no DB entry and no user preference exists.
        Dynamic external platforms are controlled via `domains` table.
        
        Args:
            domain: Email domain (e.g., 'charusat.ac.in')
        
        Returns:
            One of:
            - 'Institutional Sender' → Faculty, admin (pattern match on INSTITUTIONAL_PATTERNS)
            - 'Student / Peer' → Student email (pattern match on STUDENT_PATTERNS)
            - 'External / Misc' → Everything else (fallback)
        
        Note: External Academic Platforms are in the DB, not here.
        """
        if not domain:
            return "External / Misc"
        
        domain = domain.lower()
        
        # 1. Institutional patterns (faculty, admin, official)
        if any(domain.endswith(p) for p in INSTITUTIONAL_PATTERNS):
            # Special case: student emails (.edu.in)
            if any(domain.endswith(p) for p in STUDENT_PATTERNS):
                return "Student / Peer"
            return "Institutional Sender"
        
        # 2. Everything else defaults to External / Misc
        # External Academic Platforms come from DB (Tier 2)
        return "External / Misc"

    @staticmethod
    def score_sender(
        sender: str,
        db=None,
        user_id: Optional[str] = None
    ) -> DomainProfile:
        """Classify a sender email with 3-tier fallback.
        
        Priority:
            1. User override (is_trusted / is_blocked)
            2. Global domain defaults (DB)
            3. Pattern-based fallback (code)
        
        Args:
            sender: Full email address
            db: Database session for lookups
            user_id: User ID for preference lookup
        
        Returns:
            DomainProfile with classification and source_weight
        """
        domain = DomainTrustScorer.extract_domain(sender)
        
        if not domain:
            return DomainProfile(domain="", classification="External / Misc")
        
        # ── Tier 1: User Override ──────────────────────────────────
        if db and user_id:
            user_pref = DomainTrustScorer._get_user_preference(db, user_id, domain)
            if user_pref:
                if user_pref.is_blocked:
                    return DomainProfile(domain=domain, classification="External / Misc")
                elif user_pref.is_trusted:
                    return DomainProfile(
                        domain=domain, classification="External Academic Platform"
                    )
        
        # ── Tier 2: Global Defaults ────────────────────────────────
        if db:
            domain_entry = DomainTrustScorer._get_domain_entry(db, domain)
            if domain_entry:
                classification = DomainTrustScorer._map_source_type(
                    domain_entry.source_type
                )
                return DomainProfile(domain=domain, classification=classification)
        
        # ── Tier 3: Pattern-Based Fallback ─────────────────────────
        classification = DomainTrustScorer.classify_domain(domain)
        
        return DomainProfile(domain=domain, classification=classification)

    @staticmethod
    def _get_user_preference(db, user_id: str, domain: str):
        """Get user's domain preference (if any).
        
        Args:
            db: Database session
            user_id: Firebase user ID
            domain: Email domain
        
        Returns:
            UserDomainPreference or None
        """
        try:
            from app.models.domain import UserDomainPreference

            return (
                db.query(UserDomainPreference)
                .filter(
                    UserDomainPreference.user_id == user_id,
                    UserDomainPreference.domain == domain,
                )
                .first()
            )
        except Exception as e:
            print(f"[DOMAIN] Error fetching user preference: {e}")
            return None

    @staticmethod
    def _get_domain_entry(db, domain: str):
        """Get global domain defaults (if any).
        
        Args:
            db: Database session
            domain: Email domain
        
        Returns:
            Domain or None
        """
        try:
            from app.models.domain import Domain

            return db.query(Domain).filter(Domain.domain == domain).first()
        except Exception as e:
            print(f"[DOMAIN] Error fetching domain entry: {e}")
            return None

    @staticmethod
    def _map_source_type(source_type: str) -> str:
        """Convert DB source_type to classification label.
        
        Args:
            source_type: From Domain table
                ('institution', 'student', 'external_academic', 'external_misc')
        
        Returns:
            Classification label for DomainProfile
        """
        mapping = {
            "institution": "Institutional Sender",
            "student": "Student / Peer",
            "external_academic": "External Academic Platform",
            "external_misc": "External / Misc",
        }
        return mapping.get(source_type, "External / Misc")
