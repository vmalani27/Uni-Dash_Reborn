"""
Academic Context Engine - Deadline-aware intelligence for academic emails

This engine handles:
1. Deadline validation and normalization
2. Academic score calculation (deterministic formula)
3. Topic normalization to academic ontology (direct mapping)
4. AcademicItem and FollowUp factory (object creation from LLM output)
"""

from datetime import datetime, timedelta, timezone
from typing import Optional
import re

# ── Direct Topic Mapping ────────────────────────────────────────
# Maps LLM-generated topic labels to academic ontology
# This is a direct lookup (no string matching heuristics)

TOPIC_TO_ENTITY = {
    "Exam Notifications": "EXAM",
    "Assignment or Submission": "ASSIGNMENT",
    "Certification / Courses": "OPPORTUNITY",
    "Internship / Placement Opportunities": "OPPORTUNITY",
    "Events / Hackathons": "OPPORTUNITY",
    "Timetable / Schedule Update": "ACADEMIC_ADMIN",
    "Administrative / Fees / Counselling": "ACADEMIC_ADMIN",
    "Important Announcements": "INFORMATION",
    "General Information / Misc": "INFORMATION",
}


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
        deadline_urgency: Optional[float],  # 0–35 from calculate_deadline_urgency
        ai_urgency: str,
        topic: str,
        source_weight: float,               # now 0–25 from DomainProfile.source_weight
        time_decay_factor: float = 1.0,
    ) -> float:
        """
        Score range: 0–100
        
        Components:
          Deadline urgency  → 0–35  (35% weight, highest)
          Topic importance  → 0–30  (30% weight)
          Source trust      → 0–25  (25% weight, now dynamic)
          AI urgency        → 0–7   (7%  weight, tiebreaker only)
          Time decay        → 0–3   (3%  weight)
        """

        # Hard zero for untrusted sources — no accumulation from other fields
        if source_weight == 0:
            return 0.0

        # ── Deadline (0–35) ─────────────────────────────────────────
        deadline_score = deadline_urgency if deadline_urgency is not None else 0.0

        # ── Topic (0–30) ─────────────────────────────────────────────
        topic_weights = {
            "Exam Notifications":               30,
            "Assignment or Submission":         27,
            "Administrative / Fees / Counselling": 20,
            "Timetable / Schedule Update":      18,
            "Certification / Courses":          14,
            "Important Announcements":          12,
            "Internship / Placement Opportunities": 10,
            "Events / Hackathons":              7,
            "General Information / Misc":       3,  # Changed from 0 to 3 — generic academic info still has value
        }
        topic_score = topic_weights.get(topic, 0)

        # ── Source (0–25) — now dynamic ──────────────────────────────
        # source_weight comes directly from DomainProfile.source_weight
        # so no multiplication needed

        # ── AI urgency tiebreaker (0–7) ──────────────────────────────
        # Only applies when no deadline — avoids double-counting
        ai_weights = {"Critical": 7, "High": 5, "Medium": 3, "Low": 1, "None": 0}
        ai_score = ai_weights.get(ai_urgency, 0) if deadline_urgency is None else 0

        # ── Time decay (0–3) ─────────────────────────────────────────
        time_score = round(time_decay_factor * 3, 2)

        total = deadline_score + topic_score + source_weight + ai_score + time_score
        return round(min(total, 100), 2)
    @staticmethod
    def normalize_topic(label_topic: str) -> str:
        """Normalize LLM topic label to academic ontology using direct mapping.
        
        This replaces fuzzy string matching with a deterministic lookup.
        The LLM is constrained to output one of 9 fixed labels, so mapping is exact.
        
        Args:
            label_topic: One of the 9 LLM topic labels
        
        Returns:
            One of: EXAM, ASSIGNMENT, ACADEMIC_ADMIN, OPPORTUNITY, INFORMATION, OTHER
        """
        if not label_topic:
            return "OTHER"
        
        return TOPIC_TO_ENTITY.get(label_topic, "OTHER")

    @staticmethod
    def clean_title(raw_title: str) -> str:
        """Clean email subject to a concise title.
        Removes common prefixes like 'Re:', 'Fwd:', and trims whitespace.
        """
        if not raw_title:
            return ""
        # Remove common email prefixes
        cleaned = re.sub(r'^(Re|Fwd|FW|FWD):\s*', '', raw_title, flags=re.IGNORECASE)
        # Collapse multiple spaces
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        return cleaned


    @staticmethod
    def process_academic_objects(message, parsed_data: dict, db) -> None:
        """
        Takes the parsed JSON output from the AI and builds AcademicItems and FollowUps
        if the email warrants it.
        """
        from app.models.academic_objects import AcademicItem
        from app.models.gmail.follow_up import FollowUp
        
        requires_action = parsed_data.get("requires_action", False)
        # We only create Academic Objects for important things (requires action or high score)
        if not requires_action and message.academic_score < 40 and message.normalized_topic not in ["EXAM", "ASSIGNMENT", "OPPORTUNITY"]:
            return

        # We'll check for an existing AcademicItem after extracting course metadata

        # Attempt to glean metadata from the calendar/action items
        calendar_events = parsed_data.get("calendar_events", [])
        
        location = None
        course_code = None
        due_date = message.deadline_iso
        
        if calendar_events:
            first_event = calendar_events[0]
            location = first_event.get("location")
            course_code = first_event.get("course_code")
            # Override due date with event date if available and no explicit deadline
            if not due_date and "date" in first_event:
                try:
                    due_date = datetime.fromisoformat(first_event["date"]).replace(tzinfo=timezone.utc)
                except ValueError:
                    pass
        
        # Better extraction of course codes via regex if missing
        if not course_code:
            import re
            course_code_match = re.search(r'\b([A-Z]{2,4}\s?[\d]{3,4})\b', message.subject, re.IGNORECASE)
            if course_code_match:
                course_code = course_code_match.group(0).upper()

        # Double check if an academic item already exists for this email or a similar one
        existing_item = db.query(AcademicItem).filter(
            (AcademicItem.source_email_id == message.gmail_id) |
            (
                (AcademicItem.uid == message.uid) & 
                (AcademicItem.title == AcademicContextEngine.clean_title(message.subject)) &
                (AcademicItem.entity_type == message.normalized_topic) &
                (AcademicItem.course_code == course_code)
            )
        ).first()
        if existing_item:
            return  # Already processed
                
        # Extract actions into description
        action_items = parsed_data.get("action_items", [])
        description_parts = []
        for action in action_items:
            action_text = action.get('action', '')
            by_date = action.get('by', '')
            if action_text:
                part = f"- {action_text}"
                if by_date:
                    part += f" (by {by_date})"
                description_parts.append(part)
                
        # Use extracted action items; do not use snippet
        description = "\n".join(description_parts) if description_parts else ""
        
        # Fallback description if empty — preserve full email body, not trimmed snippet
        if not description:
            # `message.body_text` contains the full extracted plain-text body
            description = message.body_text or ""

        # Clean title
        clean_title = AcademicContextEngine.clean_title(message.subject)

        # Create the Academic Item
        item = AcademicItem(
            source_email_id=message.gmail_id,
            uid=message.uid,
            entity_type=message.normalized_topic,
            title=clean_title,
            description=description,
            due_date=due_date,
            location=location,
            course_code=course_code,
            professor=None, # Will add professor extraction later
            academic_score=message.academic_score
        )
        
        db.add(item)
        
        # Create FollowUp Chain
        follow_up_chain = parsed_data.get("follow_up_chain", [])
        
        for f in follow_up_chain:
            days_before = f.get("trigger_days_before", 0)
            msg_text = f.get("message", "Reminder")
            
            if due_date:
                trigger_at = due_date - timedelta(days=days_before)
            elif message.internal_date:
                trigger_at = message.internal_date + timedelta(days=1)
            else:
                trigger_at = datetime.now(timezone.utc)
            
            follow_up = FollowUp(
                source_email_id=message.gmail_id, # Still uses gmail_id as foreign reference
                trigger_at=trigger_at,
                message=msg_text,
                delivered=False,
                dismissed=False
            )
            db.add(follow_up)
        
        # We don't commit here because the caller (`ai_service.py`) handles the transaction
        # to ensure everything is atomic.

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
        - subject, body_text
        - academic_score, normalized_topic
        
        Output: same notification + 'structured_insights' key
        """
        
        # Only enrich high-priority items unless explicitly requested
        academic_score = notification_data.get('academic_score', 0)
        should_enrich = use_llm or academic_score >= 70
        
        insights = AcademicContextEngine.extract_structured_insights(
            subject=notification_data.get('subject', ''),
            body_text=notification_data.get('body_text', ''),
            academic_score=academic_score,
            use_llm_enrichment=should_enrich,
            llm_client=llm_client,
        )
        
        return {
            **notification_data,
            'structured_insights': insights,
        }
