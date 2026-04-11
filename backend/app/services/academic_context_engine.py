"""
Academic Context Engine - Deadline-aware intelligence for academic emails

This engine handles:
1. Deadline validation and normalization
2. Academic score calculation (deterministic formula)
3. Topic normalization to academic ontology (direct mapping)
4. AcademicItem and FollowUp factory (object creation from LLM output)
"""

from datetime import datetime, timedelta, timezone
import json
from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional, Tuple
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

    VALID_LIFECYCLE_STATUSES = {
        "active",
        "completed",
        "missed",
        "ignored",
        "expired",
        "needs_review",
    }
    LEGACY_STATUS_ALIASES = {
        "dismissed": "ignored",
        "snoozed": "active",
    }
    _EVENT_STOPWORDS = {
        "the", "and", "for", "with", "from", "this", "that", "your", "you", "are",
        "fwd", "fw", "re", "reg", "regarding", "reminder", "please", "kindly",
        "dear", "students", "student", "all", "about", "into", "our", "update",
        "mail", "email", "subject", "message", "notification", "session", "class",
    }

    @staticmethod
    def _utc_now() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def _ensure_aware(value: Optional[datetime]) -> Optional[datetime]:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    @staticmethod
    def get_item_status(item: Any) -> str:
        status = getattr(item, "status", None)
        if status:
            normalized = str(status).strip().lower()
        elif getattr(item, "completed", False):
            normalized = "completed"
        elif getattr(item, "dismissed", False):
            normalized = "ignored"
        else:
            normalized = "active"

        normalized = AcademicContextEngine.LEGACY_STATUS_ALIASES.get(
            normalized,
            normalized,
        )

        if normalized not in AcademicContextEngine.VALID_LIFECYCLE_STATUSES:
            normalized = "active"
        return normalized

    @staticmethod
    def compute_effective_relevance(item: Any, now: Optional[datetime] = None) -> Dict[str, Any]:
        now = AcademicContextEngine._ensure_aware(now) or AcademicContextEngine._utc_now()
        created_at = AcademicContextEngine._ensure_aware(getattr(item, "created_at", None)) or now
        last_updated_at = AcademicContextEngine._ensure_aware(getattr(item, "last_updated_at", None)) or created_at
        due_date = AcademicContextEngine._ensure_aware(getattr(item, "due_date", None))
        snoozed_until = AcademicContextEngine._ensure_aware(getattr(item, "snoozed_until", None))
        base_score = float(getattr(item, "academic_score", 0) or 0)
        status = AcademicContextEngine.get_item_status(item)

        if status == "active" and snoozed_until and snoozed_until > now:
            return {
                "status": "active",
                "raw_academic_score": round(base_score, 2),
                "effective_score": 0.0,
                "decay_factor": 0.0,
                "age_days": 0.0,
                "urgency_boost": 0.0,
                "signal_boost": 0.0,
                "hidden": True,
            }

        if status == "active" and due_date is not None and due_date <= now:
            status = "expired"

        if status in {"completed", "missed", "expired", "ignored"}:
            return {
                "status": status,
                "raw_academic_score": round(base_score, 2),
                "effective_score": 0.0,
                "decay_factor": 0.0,
                "age_days": 0.0,
                "urgency_boost": 0.0,
                "signal_boost": 0.0,
                "hidden": True,
            }

        anchor = last_updated_at if last_updated_at >= created_at else created_at
        age_days = max(0.0, (now - anchor).total_seconds() / 86400.0)
        decay_factor = max(0.35, 1.0 - min(age_days, 30.0) * 0.03)

        urgency_boost = 0.0
        if due_date is not None:
            days_left = (due_date - now).total_seconds() / 86400.0
            if days_left <= 0:
                urgency_boost = 8.0 + min(abs(days_left) * 1.5, 12.0)
            else:
                urgency_boost = max(0.0, 12.0 - (days_left * 2.0))

        signal_boost = AcademicContextEngine._source_signal_boost(item)
        effective_score = (base_score * decay_factor) + urgency_boost + signal_boost

        if status == "needs_review":
            return {
                "status": status,
                "raw_academic_score": round(base_score, 2),
                "effective_score": round(max(0.0, min(100.0, effective_score * 0.6)), 2),
                "decay_factor": round(decay_factor * 0.6, 2),
                "age_days": round(age_days, 2),
                "urgency_boost": round(urgency_boost, 2),
                "signal_boost": round(signal_boost, 2),
                "hidden": False,
            }

        effective_score = max(0.0, min(100.0, effective_score))

        return {
            "status": status,
            "raw_academic_score": round(base_score, 2),
            "effective_score": round(effective_score, 2),
            "decay_factor": round(decay_factor, 2),
            "age_days": round(age_days, 2),
            "urgency_boost": round(urgency_boost, 2),
            "signal_boost": round(signal_boost, 2),
            "hidden": False,
        }

    @staticmethod
    def rank_academic_items(items: List[Any], now: Optional[datetime] = None) -> List[Tuple[Any, Dict[str, Any]]]:
        ranked: List[Tuple[Any, Dict[str, Any]]] = []
        for item in items:
            metrics = AcademicContextEngine.compute_effective_relevance(item, now=now)
            if metrics.get("hidden"):
                continue
            ranked.append((item, metrics))

        ranked.sort(
            key=lambda pair: (
                -pair[1]["effective_score"],
                AcademicContextEngine._ensure_aware(getattr(pair[0], "due_date", None)) or datetime.max.replace(tzinfo=timezone.utc),
                getattr(pair[0], "id", 0),
            )
        )
        return ranked

    @staticmethod
    def serialize_academic_item(item: Any, gmail_message: Any = None, metrics: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        metrics = metrics or AcademicContextEngine.compute_effective_relevance(item)
        serialized = {
            "id": item.id,
            "title": item.title,
            "entity_type": item.entity_type,
            "due_date": item.due_date.isoformat() if item.due_date else None,
            "course_code": item.course_code,
            "location": item.location,
            "source_email_id": item.source_email_id,
            "description": item.description,
            "academic_score": metrics["effective_score"],
            "raw_academic_score": metrics["raw_academic_score"],
            "effective_score": metrics["effective_score"],
            "decay_factor": metrics["decay_factor"],
            "age_days": metrics["age_days"],
            "urgency_boost": metrics["urgency_boost"],
            "signal_boost": metrics.get("signal_boost", 0.0),
            "source_count": getattr(item, "source_count", 1) or 1,
            "source_signals": AcademicContextEngine._load_source_signals(item),
            "merge_key": getattr(item, "merge_key", None),
            "status": metrics["status"],
            "completed": item.completed,
            "dismissed": item.dismissed,
            "created_at": item.created_at.isoformat() if item.created_at else None,
            "last_updated_at": item.last_updated_at.isoformat() if getattr(item, "last_updated_at", None) else None,
            "snoozed_until": item.snoozed_until.isoformat() if getattr(item, "snoozed_until", None) else None,
        }

        if gmail_message is not None:
            serialized.update({
                "ai_summary": gmail_message.ai_summary,
                "ai_label_topic": gmail_message.ai_label_topic,
                "ai_label_source": gmail_message.ai_label_source,
            })

        return serialized

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
    def _normalize_event_text(text: Optional[str]) -> str:
        if not text:
            return ""
        cleaned = AcademicContextEngine.clean_title(text)
        cleaned = cleaned.lower()
        cleaned = re.sub(r'[^a-z0-9\s]+', ' ', cleaned)
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        return cleaned

    @staticmethod
    def _extract_event_keywords(text: Optional[str]) -> set[str]:
        normalized = AcademicContextEngine._normalize_event_text(text)
        if not normalized:
            return set()
        return {
            token
            for token in normalized.split()
            if len(token) > 2 and token not in AcademicContextEngine._EVENT_STOPWORDS
        }

    @staticmethod
    def _event_title_similarity(first: Optional[str], second: Optional[str]) -> float:
        first_norm = AcademicContextEngine._normalize_event_text(first)
        second_norm = AcademicContextEngine._normalize_event_text(second)
        if not first_norm or not second_norm:
            return 0.0
        return SequenceMatcher(None, first_norm, second_norm).ratio()

    @staticmethod
    def _source_kind(subject: Optional[str], body_text: Optional[str]) -> str:
        combined = f"{subject or ''} {body_text or ''}".lower()
        if re.search(r'\b(fwd|fw|forwarded message|forwarded)\b', combined):
            return "forwarded"
        if re.search(r'\b(reminder|remind|last date|deadline approaching|final call|nudge)\b', combined):
            return "reminder"
        return "original"

    @staticmethod
    def _load_source_signals(item: Any) -> List[Dict[str, Any]]:
        raw_signals = getattr(item, "source_signals_json", None)
        if not raw_signals:
            return []
        try:
            parsed = json.loads(raw_signals)
            if isinstance(parsed, list):
                return [signal for signal in parsed if isinstance(signal, dict)]
        except Exception:
            pass
        return []

    @staticmethod
    def _build_source_signal(message: Any, kind: str, due_date: Optional[datetime], course_code: Optional[str]) -> Dict[str, Any]:
        return {
            "email_id": getattr(message, "gmail_id", None),
            "sender": getattr(message, "sender", None),
            "subject": getattr(message, "subject", None),
            "kind": kind,
            "internal_date": getattr(message, "internal_date", None).isoformat() if getattr(message, "internal_date", None) else None,
            "due_date": due_date.isoformat() if due_date else None,
            "course_code": course_code,
        }

    @staticmethod
    def _source_signal_boost(item: Any) -> float:
        signals = AcademicContextEngine._load_source_signals(item)
        if not signals:
            return 0.0

        source_count = max(1, int(getattr(item, "source_count", len(signals)) or len(signals)))
        boost = min(max(source_count - 1, 0), 5) * 2.0

        forwarded_count = sum(1 for signal in signals if signal.get("kind") == "forwarded")
        reminder_count = sum(1 for signal in signals if signal.get("kind") == "reminder")
        boost += min(forwarded_count, 3) * 1.0
        boost += min(reminder_count, 3) * 1.5
        return boost

    @staticmethod
    def find_matching_academic_item(db, message: Any, title: str, due_date: Optional[datetime], course_code: Optional[str], entity_type: str):
        from app.models.academic_objects import AcademicItem

        candidates = (
            db.query(AcademicItem)
            .filter(AcademicItem.uid == message.uid)
            .filter(AcademicItem.entity_type == entity_type)
            .all()
        )

        if not candidates:
            return None

        normalized_title = AcademicContextEngine._normalize_event_text(title)
        title_keywords = AcademicContextEngine._extract_event_keywords(title)
        due_day = due_date.date() if due_date else None
        normalized_course = (course_code or "").strip().upper() or None

        best_item = None
        best_score = 0.0

        for item in candidates:
            if getattr(item, "source_email_id", None) == getattr(message, "gmail_id", None):
                return item

            item_title = AcademicContextEngine._normalize_event_text(getattr(item, "title", ""))
            if not item_title or not normalized_title:
                continue

            item_due = AcademicContextEngine._ensure_aware(getattr(item, "due_date", None))
            item_due_day = item_due.date() if item_due else None
            item_course = (getattr(item, "course_code", None) or "").strip().upper() or None
            item_keywords = AcademicContextEngine._extract_event_keywords(getattr(item, "title", "")) | AcademicContextEngine._extract_event_keywords(getattr(item, "description", ""))

            title_similarity = SequenceMatcher(None, item_title, normalized_title).ratio()
            keyword_overlap = 0.0
            if item_keywords and title_keywords:
                keyword_overlap = len(item_keywords & title_keywords) / max(1, min(len(item_keywords), len(title_keywords)))

            same_due_day = bool(due_day and item_due_day and due_day == item_due_day)
            same_course = bool(normalized_course and item_course and normalized_course == item_course)

            # Strong gate: same deadline or same course, then title/keyword similarity.
            if same_due_day:
                score = (title_similarity * 0.7) + (keyword_overlap * 0.3)
            elif same_course:
                score = (title_similarity * 0.8) + (keyword_overlap * 0.2)
            else:
                continue

            if score >= 0.72 and score > best_score:
                best_item = item
                best_score = score

        return best_item

    @staticmethod
    def merge_academic_item_sources(item: Any, message: Any, due_date: Optional[datetime], course_code: Optional[str]) -> None:
        signals = AcademicContextEngine._load_source_signals(item)
        kind = AcademicContextEngine._source_kind(getattr(message, "subject", None), getattr(message, "body_text", None))
        signals.append(AcademicContextEngine._build_source_signal(message, kind, due_date, course_code))

        item.source_signals_json = json.dumps(signals, ensure_ascii=True)
        item.source_count = len(signals)
        item.last_updated_at = datetime.utcnow()

        if due_date and not getattr(item, "due_date", None):
            item.due_date = due_date
        if course_code and not getattr(item, "course_code", None):
            item.course_code = course_code

        existing_title = getattr(item, "title", "") or ""
        incoming_title = AcademicContextEngine.clean_title(getattr(message, "subject", ""))
        if len(incoming_title) > len(existing_title):
            item.title = incoming_title

        note = f"[{kind}] {getattr(message, 'subject', '')}".strip()
        description = getattr(item, "description", None) or ""
        if note and note not in description:
            item.description = (description + "\n\n" if description else "") + f"Related signal: {note}"

        base_score = float(getattr(item, "academic_score", 0) or 0)
        merged_score = max(base_score, float(getattr(message, "academic_score", 0) or 0))
        merged_score = min(100.0, merged_score + min(max(item.source_count - 1, 0), 5) * 2.0)
        item.academic_score = round(merged_score, 2)

        merge_key_bits = [
            AcademicContextEngine._normalize_event_text(item.title),
            (item.course_code or "").strip().upper(),
            (item.due_date.date().isoformat() if getattr(item, "due_date", None) else ""),
            item.entity_type or "",
        ]
        item.merge_key = "|".join(bit for bit in merge_key_bits if bit)


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

        clean_title = AcademicContextEngine.clean_title(message.subject)

        # Double check if an academic item already exists for this event or a similar one.
        existing_item = AcademicContextEngine.find_matching_academic_item(
            db=db,
            message=message,
            title=clean_title,
            due_date=due_date,
            course_code=course_code,
            entity_type=message.normalized_topic,
        )
        if existing_item:
            AcademicContextEngine.merge_academic_item_sources(
                existing_item,
                message=message,
                due_date=due_date,
                course_code=course_code,
            )
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
        # Create the Academic Item
        source_signal = AcademicContextEngine._build_source_signal(
            message,
            AcademicContextEngine._source_kind(message.subject, message.body_text),
            due_date,
            course_code,
        )
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
            academic_score=message.academic_score,
            status="active",
            source_count=1,
            source_signals_json=json.dumps([source_signal], ensure_ascii=True),
            merge_key="|".join(bit for bit in [
                AcademicContextEngine._normalize_event_text(clean_title),
                (course_code or "").strip().upper(),
                (due_date.date().isoformat() if due_date else ""),
                message.normalized_topic or "",
            ] if bit),
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
            client = Client(host='https://ollama.com')
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
