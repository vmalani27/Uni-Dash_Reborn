import json
import datetime
import os
from ollama import Client
from typing import Optional, Dict, Any

from app.ai.preprocessing import preprocess_email_for_llm
from app.models.gmail.gmail_message import GmailMessage
from app.services.domain_trust_scorer import DomainTrustScorer
from app.services.academic_context_engine import AcademicContextEngine


# Platform domains to skip processing (easy to extend)
PLATFORM_DOMAINS = {
    "google_classroom": "classroom.google.com",
}


def _is_platform_sender(domain_profile, sender: str, platform_key: str) -> bool:
    """Return True when the sender matches a configured platform domain.

    Checks the normalized domain produced by DomainTrustScorer first,
    then falls back to a simple substring check on the raw sender string.
    """
    platform_domain = PLATFORM_DOMAINS.get(platform_key)
    if not platform_domain:
        return False

    dp_domain = (domain_profile.domain or "").lower()
    sender_l = (sender or "").lower()

    if dp_domain and (dp_domain == platform_domain or dp_domain.endswith('.' + platform_domain)):
        return True

    if platform_domain in sender_l:
        return True

    return False


# Ollama configuration (kept unchanged)
OLLAMA_URL = os.getenv("OLLAMA_URL","127.0.0.1:11434/api/generate")
MODEL_20B = os.getenv("OLLAMA_MODEL_20B", "gpt-oss:20b-cloud")
MODEL_120B = os.getenv("OLLAMA_MODEL_120B", "gpt-oss:120b-cloud")

LEVEL2_LABELS = [
    "Timetable / Schedule Update",
    "Exam Notifications",
    "Assignment or Submission",
    "Certification / Courses",
    "Internship / Placement Opportunities",
    "Events / Hackathons",
    "Important Announcements",
    "Administrative / Fees / Counselling",
    "General Information / Misc",
]

URGENCY_LABELS = ["Critical", "High", "Medium", "Low", "None"]

SYSTEM_PROMPT = """You are an academic email classification engine.
Output ONLY a compact JSON object with these keys: summary, label_topic, label_urgency, deadline_iso, deadline_confidence.

REQUIRED JSON FORMAT (20B pass):
{{
    "summary": "brief 1-sentence summary",
    "label_topic": "one of the allowed topic labels",
    "label_urgency": "one of the allowed urgency labels",
    "deadline_iso": "ISO 8601 string or null",
    "deadline_confidence": "High | Medium | Low | None"
}}

ALLOWED TOPIC LABELS:
{topics}

ALLOWED URGENCY LABELS:
{urgencies}

CONTEXT:
Source Trust: {source}
Subject: {subject}
Received At: {received_at}

EMAIL BODY:
{content}
"""


class AIService:
    """Simple, clear implementation of the email processing flow.

    Public method:
      - process_email(message)

    Helper methods are small and do one job each.
    """

    @staticmethod
    def call_small_model(prompt: str) -> str:
        """Call the smaller model (20B) and return the raw text response."""
        print("[AI] Calling small model")
        return AIService._call_ollama(prompt, MODEL_20B)

    @staticmethod
    def call_large_model(prompt: str) -> str:
        """Call the larger model (120B) and return the raw text response."""
        print("[AI] Calling large model for extra details")
        return AIService._call_ollama(prompt, MODEL_120B)

    @staticmethod
    def parse_llm_response(llm_response: str) -> Dict[str, Any]:
        """Parse and validate JSON returned by the LLM.

        Raises ValueError if the response is not valid JSON or missing fields.
        """
        if not llm_response or not llm_response.strip():
            raise ValueError("LLM returned empty response")

        try:
            result = json.loads(llm_response)
        except json.JSONDecodeError as e:
            raise ValueError(f"LLM returned invalid JSON: {e}")

        # Validate required keys
        required = ["summary", "label_topic", "label_urgency"]
        if not all(k in result for k in required):
            raise ValueError(f"LLM response missing required fields: {required}")

        # Normalize fields
        if result.get("label_topic") not in LEVEL2_LABELS:
            print("[AI] LLM returned unknown topic label, using fallback")
            result["label_topic"] = "General Information / Misc"

        if result.get("label_urgency") not in URGENCY_LABELS:
            print("[AI] LLM returned unknown urgency label, using fallback")
            result["label_urgency"] = "None"

        # Normalize deadline field
        deadline_iso = result.get("deadline_iso")
        if deadline_iso in ["", "null", None]:
            result["deadline_iso"] = None

        # Provide a consistent deadline_confidence field
        if "deadline_confidence" not in result:
            result["deadline_confidence"] = "None"

        return result

    @staticmethod
    def update_message_fields(message: GmailMessage, domain_profile, result: Dict[str, Any], extra_details: Optional[Dict[str, Any]] = None) -> None:
        """Update `message` fields with parsed results and calculated score.

        This mutates the message object; caller should commit the DB session.
        """
        message.ai_label_source = domain_profile.classification
        message.ai_label_topic = result.get("label_topic")
        message.ai_label_urgency = result.get("label_urgency")
        message.ai_summary = result.get("summary")

        # Normalize topic to academic ontology
        message.normalized_topic = AcademicContextEngine.normalize_topic(result.get("label_topic", "General Information / Misc"))

        # Parse deadline into datetime if present
        if result.get("deadline_iso"):
            try:
                dt = datetime.datetime.fromisoformat(result["deadline_iso"].replace('Z', '+00:00'))
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=datetime.timezone.utc)
                message.deadline_iso = dt
            except Exception:
                print("[AI] Invalid deadline format; clearing deadline")
                message.deadline_iso = None
        else:
            message.deadline_iso = None

        message.deadline_confidence = result.get("deadline_confidence", "None")

        # Calculate academic score using the existing engine
        normalized_deadline = AcademicContextEngine.normalize_deadline(message.deadline_iso)
        deadline_urgency = AcademicContextEngine.calculate_deadline_urgency(normalized_deadline)

        score = AcademicContextEngine.calculate_academic_score(
            deadline_urgency=deadline_urgency,
            ai_urgency=result.get("label_urgency", "None"),
            topic=result.get("label_topic", "General Information / Misc"),
            source_weight=domain_profile.source_weight,
        )

        message.academic_score = int(score)
        message.ai_processed = True
        message.ai_status = "completed"

        # Attach extra details if available
        if extra_details:
            try:
                # Store as JSON string in a field if you have one; otherwise keep in memory
                message.ai_extra = json.dumps(extra_details)
            except Exception:
                # Best effort only
                pass

    @staticmethod
    def process_email(message: GmailMessage, batch_mode: bool = False) -> Dict[str, Any]:
        """Main entry: process a single message and update it with AI results.

        Flow:
          - clean email text
          - detect platform senders and skip if needed
          - call small model (20B)
          - parse result
          - call large model (120B) for extra details (optional)
          - update message fields and compute score

        If the LLM returns invalid JSON, this function will raise ValueError so
        the caller can retry later.
        """
        # Clean text for model input
        cleaned = preprocess_email_for_llm(subject=message.subject, body=message.body_text, sender=message.sender)
        cleaned_text = cleaned.get("clean_text", "")

        # Domain classification used for scoring and skip decisions
        domain_profile = DomainTrustScorer.score_sender(sender=message.sender)

        # Platform skip (Google Classroom etc.)
        if _is_platform_sender(domain_profile, message.sender, "google_classroom"):
            print(f"[AI] Skipping classroom email from {message.sender}")
            message.ai_processed = True
            message.ai_status = "completed"
            message.academic_score = 0
            return {
                "skipped_platform": True,
                "platform": "google_classroom",
            }

        # Build prompt for the small model
        prompt = SYSTEM_PROMPT.format(
            source=domain_profile.classification,
            subject=message.subject,
            content=cleaned_text,
            received_at=message.internal_date.isoformat() if message.internal_date else "",
            topics="\n- ".join(LEVEL2_LABELS),
            urgencies="\n- ".join(URGENCY_LABELS),
        )

        # Single level error handling: let errors bubble up after marking message failed
        try:
            print(f"[AI] Processing email {message.gmail_id}")

            message.ai_processed = False
            message.ai_status = "processing"

            # Small model call
            llm_response = AIService.call_small_model(prompt)

            # Parse the LLM JSON response (will raise on invalid JSON)
            result = AIService.parse_llm_response(llm_response)

            # Optionally call the large model to get extra details
            extra_details = None
            try:
                extra_prompt = (
                    "You are a deeper analysis engine. Given the email body and the short summary, "
                    "extract ONLY these keys as JSON: action_items (array), calendar_events (array), follow_up_chain (array)."
                    f"\n\nEMAIL BODY:\n{cleaned_text}\n\nSHORT_PARSE:\n{json.dumps({k: result.get(k) for k in ['summary','label_topic','label_urgency','deadline_iso']})}"
                )
                large_response = AIService.call_large_model(extra_prompt)
                # Parse large model response; if invalid JSON, raise and let caller retry
                extra_details = json.loads(large_response)
            except Exception as e:
                # If extra details fail, we do not stop processing — it's optional
                print(f"[AI] Large model failed or returned invalid JSON: {e}")
                extra_details = None

            # Update DB fields and compute score
            AIService.update_message_fields(message, domain_profile, result, extra_details)

            # Return a simple payload for callers
            return {
                "summary": message.ai_summary,
                "topic": message.ai_label_topic,
                "urgency": message.ai_label_urgency,
                "source": message.ai_label_source,
                "deadline_iso": message.deadline_iso.isoformat() if message.deadline_iso else None,
                "deadline_confidence": message.deadline_confidence,
                "academic_score": message.academic_score,
                "parsed_payload": result,
                "extra_details": extra_details,
            }

        except Exception as err:
            # Mark the message so it can be retried or inspected later
            print(f"[AI] Processing failed for {message.gmail_id}: {err}")
            message.ai_processed = False
            message.ai_status = "failed"
            # Re-raise so caller knows there was a failure
            raise

    @staticmethod
    def _call_ollama(prompt: str, model: str) -> str:
        """Call local Ollama and return the raw response string.

        This is a thin wrapper over the HTTP call; it does not attempt to
        recover malformed JSON. Caller must parse and validate.
        """
        print(f"[AI] Ollama -> {model}")

        # Use the Ollama Python client for remote inference
        client = Client(
            host="https://ollama.com",
            headers={"Authorization": "Bearer " + os.getenv("OLLAMA_API_KEY", "")},
        )

        # The client.generate method returns a dict with a 'response' field containing the generated text.
        result = client.generate(
            model=model,
            prompt=prompt,
            options={
                "temperature": 0.0,
                "top_p": 0.1,
                "num_predict": 2000,
            },
        )

        raw = result.get("response", "") or ""

        # Remove simple markdown fences only
        if raw.startswith("```json"):
            raw = raw[7:]
        if raw.startswith("```"):
            raw = raw[3:]
        if raw.endswith("```"):
            raw = raw[:-3]

        return raw.strip()

    # Backwards-compatible alias for older callers
    @staticmethod
    def run_email_inference(message: GmailMessage, **kwargs) -> Dict[str, Any]:
        """Compatibility wrapper used by older workers.

        Calls the new `process_email` implementation.
        """
        return AIService.process_email(message, **kwargs)
