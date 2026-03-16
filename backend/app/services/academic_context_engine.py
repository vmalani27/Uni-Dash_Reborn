"""
Academic Context Engine - Deadline-aware intelligence for academic emails
"""

from datetime import datetime, timedelta, timezone
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

        now = datetime.now(timezone.utc)

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

        now = datetime.now(timezone.utc)
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

    @staticmethod
    def extract_structured_insights(
        subject: str,
        body_text: str,
        academic_score: float,
        use_llm_enrichment: bool = False,
        llm_client=None
    ) -> dict:
        """
        Extract structured insights from high-priority emails:
        - Instructor name/email
        - Course code
        - Deadline
        - Action items (what student needs to do)
        - Submission requirements (if assignment)
        
        If academic_score >= 70 and use_llm_enrichment=True, uses small LLM for semantic extraction.
        Falls back to regex/pattern-based extraction otherwise.
        
        Returns:
        {
            'instructor_name': str | None,
            'instructor_email': str | None,
            'course_code': str | None,
            'course_name': str | None,
            'action_items': [str],  # e.g., ['Submit assignment', 'Review lecture slides']
            'submission_required': bool,
            'submission_format': str | None,  # e.g., 'PDF', 'Code + Report'
            'confidence': float,  # 0.0-1.0
            'enriched_by_llm': bool,
        }
        """
        
        # For high-priority emails, try LLM enrichment first
        high_priority = academic_score >= 70
        
        if high_priority and use_llm_enrichment and llm_client:
            try:
                return AcademicContextEngine._extract_with_llm(
                    subject, body_text, llm_client
                )
            except Exception as e:
                print(f"LLM enrichment failed, falling back to pattern matching: {e}")
        
        # Fallback to pattern-based extraction
        return AcademicContextEngine._extract_with_patterns(subject, body_text)

    @staticmethod
    def _extract_with_patterns(subject: str, body_text: str) -> dict:
        """
        Pattern-based extraction using regex and keyword matching.
        Fast, reliable, but less semantic.
        """
        import re
        
        combined_text = f"{subject}\n{body_text}".lower()
        
        # Extract course code: CS101, MATH-201, CSC 151, etc.
        course_code_match = re.search(r'\b([A-Z]{2,4}\s?[\d]{3,4})\b', subject, re.IGNORECASE)
        course_code = course_code_match.group(0).upper() if course_code_match else None
        
        # Extract instructor email
        instructor_email = None
        email_match = re.search(r'from:\s*(.+?)\s*<([^>]+@[^>]+)>', combined_text)
        if email_match:
            instructor_email = email_match.group(2)
        
        # Common action keywords
        action_keywords = {
            'submit': 'Submit your work',
            'upload': 'Upload your submission',
            'complete': 'Complete the task',
            'attend': 'Attend the exam/class',
            'review': 'Review the materials',
            'prepare': 'Prepare for the exam',
            'download': 'Download the resources',
            'read': 'Read the assigned material',
            'register': 'Register for the exam',
        }
        
        action_items = []
        for keyword, action in action_keywords.items():
            if keyword in combined_text:
                action_items.append(action)
        
        # Check for submission requirement keywords
        submission_required = any(x in combined_text for x in ['submit', 'upload', 'hand in', 'send', 'assignment'])
        
        submission_format = None
        format_patterns = {
            'pdf': 'PDF',
            'word': 'DOC/DOCX',
            'code': 'Code',
            'zip': 'ZIP Archive',
            'excel': 'Excel',
        }
        for pattern, fmt in format_patterns.items():
            if pattern in combined_text:
                submission_format = fmt
                break
        
        return {
            'instructor_name': None,  # Would need name extraction from email
            'instructor_email': instructor_email,
            'course_code': course_code,
            'course_name': None,
            'action_items': list(set(action_items)) if action_items else ['Review email content'],
            'submission_required': submission_required,
            'submission_format': submission_format,
            'confidence': 0.6 if action_items else 0.4,
            'enriched_by_llm': False,
        }

    @staticmethod
    def _extract_with_llm(subject: str, body_text: str, llm_client) -> dict:
        """
        Use small LLM (Ollama/Gemma/Mistral) to extract structured insights.
        
        Requires:
        - llm_client: Ollama client or similar with generate() method
        - Model: gemma:7b-instruct, mistral:instruct, or similar
        
        Example usage:
            from ollama import Client
            client = Client(host='http://localhost:11434')
            insights = engine._extract_with_llm(subject, body, client)
        """
        
        prompt = f"""
You are an academic email analyzer. Extract structured information from this email.

SUBJECT: {subject}
BODY: {body_text[:1000]}

Return ONLY valid JSON (no markdown, no extra text):
{{
    "instructor_name": "Name if identifiable, else null",
    "instructor_email": "Email if present, else null",
    "course_code": "e.g., CS101, MATH-201, else null",
    "course_name": "Full course name if mentioned, else null",
    "action_items": ["What the student must do", "Another action"],
    "submission_required": true/false,
    "submission_format": "PDF, Code, etc., or null",
    "key_deadline": "ISO format deadline if mentioned, else null"
}}
"""
        
        try:
            response = llm_client.generate(
                model='gemma:7b-instruct',  # or mistral:instruct, neural-chat, etc.
                prompt=prompt,
                stream=False,
                temperature=0.2,  # Low temp for deterministic extraction
            )
            
            import json
            json_text = response.get('response', '{}')
            
            # Extract JSON from response (LLM may add extra text)
            import re
            json_match = re.search(r'\{[^{}]*\}', json_text, re.DOTALL)
            if json_match:
                parsed = json.loads(json_match.group(0))
            else:
                parsed = {}
            
            # Validate and sanitize
            return {
                'instructor_name': parsed.get('instructor_name'),
                'instructor_email': parsed.get('instructor_email'),
                'course_code': parsed.get('course_code'),
                'course_name': parsed.get('course_name'),
                'action_items': parsed.get('action_items', []),
                'submission_required': parsed.get('submission_required', False),
                'submission_format': parsed.get('submission_format'),
                'confidence': 0.85,  # LLM extraction generally high confidence
                'enriched_by_llm': True,
            }
        
        except Exception as e:
            raise Exception(f"LLM extraction failed: {str(e)}")

    @staticmethod
    def enrich_notification_with_insights(
        notification_data: dict,
        use_llm: bool = False,
        llm_client=None
    ) -> dict:
        """
        Enhance a notification with structured insights.
        
        Input notification_data should have:
        - subject, body_text (or snippet)
        - academic_score, normalized_topic
        
        Output: same notification + 'structured_insights' key
        """
        
        # Only enrich high-priority items unless explicitly requested
        academic_score = notification_data.get('academic_score', 0)
        should_enrich = use_llm or academic_score >= 70
        
        insights = AcademicContextEngine.extract_structured_insights(
            subject=notification_data.get('subject', ''),
            body_text=notification_data.get('body_text', notification_data.get('snippet', '')),
            academic_score=academic_score,
            use_llm_enrichment=should_enrich,
            llm_client=llm_client,
        )
        
        return {
            **notification_data,
            'structured_insights': insights,
        }
