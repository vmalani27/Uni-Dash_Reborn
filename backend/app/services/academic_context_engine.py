"""
Academic Context Engine - Deadline-aware intelligence for academic emails
"""

from datetime import datetime, timedelta
from typing import Optional


class AcademicContextEngine:
    """Engine for processing academic context and deadline intelligence."""

    @staticmethod
    def normalize_deadline(deadline: Optional[datetime]) -> Optional[datetime]:
        """
        Validate and normalize extracted deadlines.
        Rejects past deadlines and absurd future dates.
        """
        if not deadline:
            return None

        now = datetime.utcnow()

        # Reject past deadlines older than 1 day (allows for timezone issues)
        if deadline < now - timedelta(days=1):
            return None

        # Reject absurd future deadlines (> 1 year)
        if deadline > now + timedelta(days=365):
            return None

        return deadline

    @staticmethod
    def calculate_deadline_urgency(deadline: Optional[datetime]) -> Optional[float]:
        """
        Calculate urgency score based on deadline proximity.
        Returns None if no deadline, otherwise a score from 0-35.
        """
        if not deadline:
            return None

        now = datetime.utcnow()
        hours_remaining = (deadline - now).total_seconds() / 3600

        if hours_remaining <= 6:
            return 35.0  # Critical - within 6 hours
        elif hours_remaining <= 24:
            return 30.0  # Very High - within 24 hours
        elif hours_remaining <= 72:
            return 25.0  # High - within 3 days
        elif hours_remaining <= 168:
            return 15.0  # Medium - within 1 week
        else:
            return 5.0   # Low - more than 1 week

    @staticmethod
    def calculate_academic_score(
        deadline_urgency: Optional[float],
        ai_urgency: str,
        topic: str,
        source_trust: str,
        time_decay_factor: float = 1.0
    ) -> float:
        """
        Calculate final academic priority score combining all factors.

        Weights:
        - Deadline urgency: 40% (when available)
        - AI urgency: 20% (fallback when no deadline)
        - Topic importance: 20%
        - Source trust: 15%
        - Time decay: 5%
        """

        # Deadline-based urgency (highest priority when available)
        if deadline_urgency is not None:
            deadline_score = deadline_urgency * 0.4
        else:
            deadline_score = 0

        # AI urgency fallback (only when no deadline, capped at 60% of full weight)
        if deadline_urgency is None:
            ai_urgency_weights = {
                "Critical": 35,
                "High": 25,
                "Medium": 15,
                "Low": 8,
                "None": 0
            }
            ai_urgency_score = ai_urgency_weights.get(ai_urgency, 0) * 0.6 * 0.2  # Cap at 60% of 20% weight
        else:
            ai_urgency_score = 0

        # Topic importance
        topic_weights = {
            "Exam Notifications": 30,
            "Assignment or Submission": 28,
            "Administrative / Fees / Counselling": 20,
            "Timetable / Schedule Update": 18,
            "Certification / Courses": 15,
            "Internship / Placement Opportunities": 12,
            "Events / Hackathons": 8,
            "Important Announcements": 10,
            "General Information / Misc": 0
        }
        topic_score = topic_weights.get(topic, 0) * 0.2

        # Source trust
        source_weights = {
            "official": 25,
            "faculty": 20,
            "trusted": 15,
            "unknown": 0
        }
        source_score = source_weights.get(source_trust, 0) * 0.15

        # Time decay (recent emails get slight boost)
        time_score = time_decay_factor * 5 * 0.05

        # Final score
        total_score = deadline_score + ai_urgency_score + topic_score + source_score + time_score

        return round(total_score, 2)

    @staticmethod
    def normalize_topic(label_topic: str) -> str:
        """
        Normalize LLM-generated topic to your academic ontology.
        
        Categories:
        - ASSIGNMENT: Coursework, projects, submissions
        - EXAM: Exams, tests, assessments
        - ACADEMIC_ADMIN: Schedules, fees, counselling, admin announcements
        - OPPORTUNITY: Internships, placements, hackathons, certifications
        - INFORMATION: General info, announcements
        - OTHER: Everything else
        """
        if not label_topic:
            return "OTHER"
        
        label_topic = label_topic.lower()
        
        if "assignment" in label_topic or "submission" in label_topic:
            return "ASSIGNMENT"
        
        if "exam" in label_topic or "test" in label_topic or "assessment" in label_topic:
            return "EXAM"
        
        if any(x in label_topic for x in ["schedule", "timetable", "administrative", "fees", "counselling"]):
            return "ACADEMIC_ADMIN"
        
        if any(x in label_topic for x in ["internship", "placement", "hackathon", "certification", "course"]):
            return "OPPORTUNITY"
        
        if any(x in label_topic for x in ["announcement", "general information"]):
            return "INFORMATION"
        
        return "OTHER"
