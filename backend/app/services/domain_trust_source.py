# app/services/domain_trust_scorer.py

import re
from dataclasses import dataclass, field
from typing import Optional

# ── Static knowledge ────────────────────────────────────────────

# TLDs that are structurally institutional
INSTITUTIONAL_TLDS = {".ac.in", ".edu", ".edu.in", ".ac.uk", ".edu.au"}

# Known platform domains — trusted but not institutional
TRUSTED_PLATFORMS = {
    # Placement / hiring
    "xobin.com", "hackerrank.com", "hackerearth.com",
    "unstop.com", "internshala.com", "naukri.com",
    # Learning
    "coursera.org", "nptel.ac.in", "swayam.gov.in",
    # Communication infrastructure your university actually uses
    "classroom.google.com", "meet.google.com",
}

# Keywords that appear in institutional domains
INSTITUTIONAL_KEYWORDS = [
    "university", "college", "institute", "school",
    "charusat", "iit", "nit", "bits",   # ← add your university name here
    "ac", "edu", "tnp", "placement",
]


@dataclass
class DomainProfile:
    domain: str
    static_score: float       # 0.0–1.0 from rules alone
    behavioural_score: float  # 0.0–1.0 from email history
    user_score: float         # 0.0–1.0 from student interaction
    email_count: int = 0
    deadline_hit_rate: float = 0.0   # % of emails from this domain with a deadline
    high_score_rate: float = 0.0     # % of emails with academic_score > 15

    @property
    def trust_score(self) -> float:
        # Weighted combination — static is highest weight initially,
        # behavioural grows as we see more emails from this domain
        weight_static = max(0.5, 1.0 - (self.email_count / 20))  # decays as data grows
        weight_behavioural = 1.0 - weight_static
        
        combined = (
            self.static_score * weight_static +
            self.behavioural_score * weight_behavioural
        )
        # User signals can only boost, never penalise
        boost = self.user_score * 0.1
        return min(1.0, round(combined + boost, 3))

    @property
    def label(self) -> str:
        s = self.trust_score
        if s >= 0.75:
            return "Institutional Sender"
        elif s >= 0.45:
            return "Trusted External"
        elif s >= 0.2:
            return "Low Trust"
        else:
            return "External / Misc"

    @property
    def source_weight(self) -> float:
        """Direct input into calculate_academic_score — replaces hardcoded dict."""
        return round(self.trust_score * 25, 2)  # maps 0.0–1.0 → 0–25


class DomainTrustScorer:

    @staticmethod
    def extract_domain(sender: str) -> str:
        """Pull domain from any sender string format."""
        match = re.search(r'[\w.+-]+@([\w.-]+\.[a-z]{2,})', sender.lower())
        return match.group(1) if match else ""

    @staticmethod
    def compute_static_score(domain: str) -> float:
        if not domain:
            return 0.0

        # TLD check — strongest static signal
        for tld in INSTITUTIONAL_TLDS:
            if domain.endswith(tld):
                return 1.0

        # Known trusted platform
        if domain in TRUSTED_PLATFORMS:
            return 0.6

        # Keyword in domain
        for kw in INSTITUTIONAL_KEYWORDS:
            if kw in domain:
                return 0.8

        # Subdomain of a known platform (e.g. mail.xobin.com)
        parts = domain.split(".")
        for i in range(len(parts) - 1):
            candidate = ".".join(parts[i:])
            if candidate in TRUSTED_PLATFORMS:
                return 0.55

        return 0.05  # unknown domain — not zero, just low

    @staticmethod
    def compute_behavioural_score(
        email_count: int,
        deadline_hit_rate: float,
        high_score_rate: float,
    ) -> float:
        """
        Score based on what we've historically seen from this domain.
        - deadline_hit_rate: how often emails from here have a real deadline
        - high_score_rate: how often they score > 15 (genuinely important)
        """
        if email_count < 3:
            return 0.0  # not enough data yet, don't trust behavioural

        # Weighted average of both rates
        score = (deadline_hit_rate * 0.5) + (high_score_rate * 0.5)
        
        # Frequency bonus — domains that send often are likely subscribed/institutional
        freq_bonus = min(0.1, email_count / 100)
        
        return min(1.0, round(score + freq_bonus, 3))

    @staticmethod
    def score_sender(
        sender: str,
        # Behavioural data from DB (pass None if not yet computed)
        email_count: int = 0,
        deadline_hit_rate: float = 0.0,
        high_score_rate: float = 0.0,
        # User signal (0.0–1.0, how much the student interacts with this domain)
        user_engagement: float = 0.0,
    ) -> DomainProfile:
        domain = DomainTrustScorer.extract_domain(sender)
        static = DomainTrustScorer.compute_static_score(domain)
        behavioural = DomainTrustScorer.compute_behavioural_score(
            email_count, deadline_hit_rate, high_score_rate
        )
        return DomainProfile(
            domain=domain,
            static_score=static,
            behavioural_score=behavioural,
            user_score=user_engagement,
            email_count=email_count,
            deadline_hit_rate=deadline_hit_rate,
            high_score_rate=high_score_rate,
        )