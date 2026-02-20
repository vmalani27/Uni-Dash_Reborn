"""
Level 1 Classifier for Email Source Classification
Determines institutional trust tier based purely on sender domain.
"""

from typing import Optional


class Level1Classifier:
    """
    Rule-based classifier for determining institutional trust level.
    This does NOT detect spam or infer intent.
    """

    EXTERNAL_ACADEMIC_DOMAINS = {
        "nptel.iitm.ac.in",
        "nptel.ac.in",
        "coursera.org",
        "edx.org",
    }

    @classmethod
    def classify_source(cls, sender_email: str, sender_name: Optional[str] = None) -> str:
        """
        Classify email source into institutional trust tier.

        Returns:
            - "Institutional Sender"
            - "Student / Peer"
            - "External Academic Platform"
            - "External / Misc"
        """

        if not sender_email:
            return "External / Misc"

        sender_email = sender_email.lower().strip()

        try:
            sender_domain = sender_email.split("@")[1]
        except IndexError:
            return "External / Misc"

        sender_domain = sender_domain.strip()

        # External academic platforms
        if sender_domain in cls.EXTERNAL_ACADEMIC_DOMAINS:
            return "External Academic Platform"

        # Institutional authority
        if sender_domain.endswith("charusat.ac.in"):
            return "Institutional Sender"

        # Peer-level sender
        if sender_domain.endswith("charusat.edu.in"):
            return "Student / Peer"

        # Default fallback
        return "External / Misc"


# Convenience wrapper
def classify_email_source(sender_email: str, sender_name: Optional[str] = None) -> str:
    return Level1Classifier.classify_source(sender_email, sender_name)
