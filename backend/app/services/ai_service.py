import datetime
import json
import logging
import re
from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional, Tuple

from app.ai.preprocessing import preprocess_email_for_llm
from app.models.ai_layer import AcademicEntity, EntitySourceMap, ExtractedSignal
from app.models.gmail.gmail_message import GmailMessage
from app.services.domain_trust_scorer import DomainTrustScorer
from app.services.ollama_runtime import (
    get_inference_client,
    get_inference_mode,
    get_inference_model,
    initialize_ollama_runtime,
)
from app.utils.pipeline_csv_logger import append_csv_row, utc_timestamp

logger = logging.getLogger(__name__)

AI_CSV_FIELDS = [
    "timestamp",
    "uid",
    "gmail_id",
    "stage",
    "title",
    "intent",
    "type_candidates",
    "confidence",
    "entity_id",
    "entity_created",
    "raw_llm_present",
    "error",
]


PLATFORM_DOMAINS = {
    "google_classroom": "classroom.google.com",
}

ENTITY_TYPES = ["ASSIGNMENT", "EXAM", "OPPORTUNITY", "ACADEMIC_ADMIN", "INFORMATION"]
LEVEL2_LABELS = ["ASSIGNMENT", "EXAM", "OPPORTUNITY", "ACADEMIC_ADMIN", "INFORMATION", "IGNORE"]
INTENT_ALIASES = {
    "submit": "ASSIGNMENT",
    "turn in": "ASSIGNMENT",
    "register": "OPPORTUNITY",
    "apply": "OPPORTUNITY",
    "attend": "OPPORTUNITY",
    "join": "OPPORTUNITY",
    "read": "ACADEMIC_ADMIN",
    "review": "ACADEMIC_ADMIN",
    "pay": "ACADEMIC_ADMIN",
}

ENTITY_MATCH_STOPWORDS = {
    "the", "and", "for", "with", "from", "this", "that", "your", "you", "are",
    "into", "our", "new", "latest", "alert", "update", "announcement", "mail",
    "email", "subject", "message", "reminder", "about", "opportunity", "job",
    "internship", "application", "apply", "submission", "submission", "drive",
}

SYSTEM_PROMPT = """
You are a strict academic email signal extractor.
You MUST extract structured data with ZERO hallucination and STRICT semantic correctness.

OUTPUT SCHEMA (STRICT):
Return ONLY valid JSON:
{{
    "title": string,
    "summary": string,
    "intent": string,
    "type_candidates": [string from ASSIGNMENT, EXAM, OPPORTUNITY, ACADEMIC_ADMIN, INFORMATION],
    "deadline": {{ "text": string, "iso": string }} | null,
    "event_date": {{ "text": string, "iso": string }} | null,
    "other_dates": [ {{ "text": string, "iso": string }} ],
    "entities": [string],
    "confidence": float
}}

CRITICAL SEMANTIC RULES:

DEADLINE (VERY IMPORTANT):
- A deadline is the LAST DATE to submit / apply / register, must be explicitly stated.
- Valid: "Last date to apply is April 30", "Submit before 5 PM tomorrow"
- INVALID (NEVER USE): email received date, announcement date, event date, inferred or guessed dates
- If unsure → return null

EVENT DATE:
- Date when event occurs, NOT a submission deadline

OTHER DATES:
- Any remaining dates, DO NOT mark them as deadline

EXTRACTION RULES:
- NEVER guess missing fields
- NEVER convert timestamps into semantic fields
- NEVER promote random dates to deadline
- If multiple dates exist: choose ONE best deadline OR null
- Prefer null over incorrect

CONFIDENCE:
- 0.9+ → explicit clear statement
- 0.6–0.8 → somewhat clear
- <0.5 → unreliable → prefer null fields

FAILURE PREVENTION:
- DO NOT assign deadline if unclear
- DO NOT output multiple deadlines
- DO NOT use fallback assumptions

PRINCIPLE:
Incorrect deadline = system failure
Missing deadline = acceptable

Now extract from the email.

CONTEXT:
Source Trust: {source}
Subject: {subject}
Received At: {received_at}

EMAIL BODY:
{content}
"""

SURFACE_EXTRACTION_PROMPT = """
Return ONLY this JSON about the email intent view:
{"action_required": true/false, "has_deadline": true/false, "deadline_text": "<YYYY-MM-DD or empty>", "is_exam": true/false, "is_submission": true/false, "is_mandatory": true/false, "is_opportunity": true/false}
Return valid JSON only. Do not explain, do not include any other text.
"""

SURFACE_CLASSIFICATION_PROMPT = """
You are an academic email classification assistant.

You will receive:
- SOURCE TRUST LEVEL
- EMAIL SUBJECT
- EMAIL BODY

Your task:
1. Classify the email into ONE topic
2. Generate a short student-facing summary

CRITICAL RULES:
- TOPIC = PRIMARY INTENT, not keywords.
- If action is required, prefer ACADEMIC_ADMIN over INFORMATION.
- If the content is pure newsletter, advertisement, or spam, choose IGNORE.
- If content is noisy but intent is clear, classify normally.
- If content is missing or meaningless, choose IGNORE.

Allowed topic labels:
["ASSIGNMENT", "EXAM", "OPPORTUNITY", "ACADEMIC_ADMIN", "INFORMATION", "IGNORE"]

Return ONLY valid JSON in this exact format:
{
  "summary": "<one-line student-facing summary>",
  "label_topic": "<one topic label>"
}
"""

GATE_CLASSIFICATION_PROMPT = """
You are a strict academic email gatekeeper.

Decide whether this email is worth expensive academic extraction.

Return ONLY valid JSON:
{
  "should_process": true/false,
  "label": "<ASSIGNMENT|EXAM|OPPORTUNITY|ACADEMIC_ADMIN|INFORMATION|IGNORE>",
  "reason": "<short reason>",
  "confidence": <0.0 to 1.0>
}

Rules:
- Process only if the email has clear academic intent or requires an academic action.
- Reject marketing, newsletters, promotions, surveys, generic platform noise, security alerts, sign-in notices, OTPs, receipts, and account verification emails.
- Classroom/LMS/institutional mail should still be rejected unless it contains an assignment, exam, deadline, submission, registration, attendance, fee, mandatory action, or similar academic task.
- If the content is noisy and no academic action is clear, reject it.
- If unsure, reject it.
"""


def _is_platform_sender(domain_profile, sender: str, platform_key: str) -> bool:
    platform_domain = PLATFORM_DOMAINS.get(platform_key)
    if not platform_domain:
        return False

    dp_domain = (getattr(domain_profile, "domain", "") or "").lower()
    sender_l = (sender or "").lower()

    if dp_domain and (dp_domain == platform_domain or dp_domain.endswith("." + platform_domain)):
        return True
    if platform_domain in sender_l:
        return True
    return False


def _utc_now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


def _ensure_aware(value: Optional[datetime.datetime]) -> Optional[datetime.datetime]:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=datetime.timezone.utc)
    return value.astimezone(datetime.timezone.utc)


def _clean_text(text: Optional[str]) -> str:
    if not text:
        return ""
    cleaned = re.sub(r"^(re|fwd|fw):\s*", "", text, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def _normalize_entity_type(value: Any, fallback_text: str = "") -> str:
    candidate = str(value or "").strip().upper()
    if candidate in ENTITY_TYPES:
        return candidate

    text = (fallback_text or "").lower()
    for needle, entity_type in INTENT_ALIASES.items():
        if needle in text:
            return entity_type

    if any(word in text for word in ["exam", "quiz", "practical", "viva", "midterm", "final", "test"]):
        return "EXAM"
    if any(word in text for word in ["assignment", "submit", "homework", "project", "upload", "turn in"]):
        return "ASSIGNMENT"
    if any(word in text for word in ["internship", "placement", "opportunity", "job", "career", "contest", "competition"]):
        return "OPPORTUNITY"
    if any(word in text for word in ["announcement", "admin", "fees", "counselling", "counseling", "timetable", "schedule", "mandatory", "notice"]):
        return "ACADEMIC_ADMIN"
    if any(word in text for word in ["newsletter", "information", "info", "update", "event", "hackathon", "seminar", "webinar", "workshop"]):
        return "INFORMATION"
    return "INFORMATION"


def _extract_entities_from_text(subject: str, body_text: str) -> List[str]:
    combined = f"{subject or ''} {body_text or ''}"
    entities: List[str] = []
    for pattern in [r"\b[A-Z]{2,5}\s?\d{3,4}\b", r"\b[A-Z]{2,5}-\d{3,4}\b"]:
        entities.extend(re.findall(pattern, combined))
    if subject:
        entities.append(_clean_text(subject))
    return [item for item in dict.fromkeys(e.strip() for e in entities if e and e.strip())][:5]


def _normalize_match_signature(text: str) -> Tuple[str, List[str]]:
    cleaned = _clean_text(text).lower()
    cleaned = re.sub(r"[^a-z0-9]+", " ", cleaned)
    tokens = [
        token for token in cleaned.split()
        if len(token) > 2 and token not in ENTITY_MATCH_STOPWORDS
    ]
    if not tokens:
        return "", []
    return " ".join(tokens[:10]), tokens


def _sender_domain(sender: str) -> str:
    value = (sender or "").strip().lower()
    if "@" not in value:
        return value
    return value.split("@", 1)[-1]


def _mail_log_context(message: GmailMessage) -> str:
    subject = _clean_text(getattr(message, "subject", "") or "")
    if len(subject) > 80:
        subject = subject[:77] + "..."
    return f"uid={getattr(message, 'uid', '')[:8]} gmail_id={getattr(message, 'gmail_id', '')} subject={subject!r}"


def _build_intent_view(subject: str, clean_text: str) -> str:
    text = clean_text or ""
    text = re.split(r'(?i)\b(thanks|regards|sincerely|best regards|with regards)\b', text)[0]
    text = re.split(r'(?i)(forwarded message|from:|sent:|on .* wrote:)', text)[0]
    text = re.sub(r'(?im)^.*unsubscribe.*$', '', text)
    text = re.sub(r'(?im)^.*privacy policy.*$', '', text)
    text = re.sub(r'(?im)^.*terms .*$', '', text)

    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    text = "\n".join(lines[:20])

    action_keywords = []
    patterns = [
        r"submit",
        r"exam",
        r"quiz",
        r"deadline",
        r"register",
        r"apply",
        r"attendance",
        r"mandatory",
        r"fee",
        r"assignment",
    ]

    for p in patterns:
        if re.search(p, text, re.IGNORECASE) or re.search(p, subject or "", re.IGNORECASE):
            action_keywords.append(p.upper())

    return (
        "SUBJECT:\n"
        f"{subject or ''}\n\n"
        "CONTENT:\n"
        f"{text}\n\n"
        "DETECTED SIGNALS:\n"
        f"{', '.join(action_keywords) if action_keywords else 'NONE'}"
    )


class AIService:
    @staticmethod
    def extract_json_from_text(text: str) -> Optional[Dict[str, Any]]:
        if not text or not text.strip():
            return None

        text = text.strip()
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass

        json_blocks = re.findall(r"```(?:json)?\s*([\s\S]*?)\s*```", text)
        for block in json_blocks:
            try:
                return json.loads(block.strip())
            except json.JSONDecodeError:
                continue

        json_pattern = r"\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}"
        matches_list: List[Tuple[int, Dict[str, Any]]] = []
        for match in re.finditer(json_pattern, text):
            json_str = match.group(0)
            try:
                obj = json.loads(json_str)
                matches_list.append((len(json_str), obj))
            except json.JSONDecodeError:
                continue

        if matches_list:
            matches_list.sort(reverse=True)
            return matches_list[0][1]
        return None

    @staticmethod
    def call_small_model(prompt: str) -> str:
        logger.info("[AI] Calling small model")
        return AIService._call_inference(prompt, get_inference_model("small"))

    @staticmethod
    def call_large_model(prompt: str) -> str:
        logger.info("[AI] Calling large model")
        return AIService._call_inference(prompt, get_inference_model("large"))

    @staticmethod
    def initialize_inference_backend() -> None:
        state = initialize_ollama_runtime()
        mode = get_inference_mode().value
        if mode == "ollama_cloud":
            logger.info("[AI] Cloud inference locked to Ollama at %s", state.base_url)
        elif mode == "openrouter":
            logger.info("[AI] Cloud inference locked to OpenRouter at %s", state.base_url)
        else:
            logger.warning("[AI] Cloud inference unavailable: %s", state.probe_error)

    @staticmethod
    def parse_llm_response(llm_response: str) -> Dict[str, Any]:
        extracted = AIService.extract_json_from_text(llm_response)
        if extracted is None:
            raise ValueError("Failed to parse JSON from LLM response")
        return extracted

    @staticmethod
    def _call_inference(prompt: str, model: str) -> str:
        logger.info("[AI] Inference -> %s", model)
        client = get_inference_client()
        result = client.generate(
            model=model,
            prompt=prompt,
            options={
                "temperature": 0.0,
                "top_p": 0.1,
                "num_predict": 1200,
            },
        )
        raw = (result.get("response", "") or "").strip()
        if not raw:
            raise ValueError(f"Model {model} returned empty response")
        if raw.startswith("```json"):
            raw = raw[7:]
        if raw.startswith("```"):
            raw = raw[3:]
        if raw.endswith("```"):
            raw = raw[:-3]
        raw = raw.strip()
        if not raw:
            raise ValueError(f"Model {model} returned only markdown fences")
        return raw

    @staticmethod
    def _surface_level1_label(domain_profile) -> str:
        return getattr(domain_profile, "classification", "External / Misc") or "External / Misc"

    @staticmethod
    def _gate_prompt(message: GmailMessage, domain_profile, intent_view: str) -> str:
        return (
            GATE_CLASSIFICATION_PROMPT
            + "\n\nSOURCE TRUST LEVEL: "
            + AIService._surface_level1_label(domain_profile)
            + "\nSUBJECT: "
            + (message.subject or "")
            + "\n\nEMAIL BODY:\n"
            + intent_view
        )

    @staticmethod
    def _gate_heuristic_decision(message: GmailMessage, domain_profile, intent_view: str) -> Dict[str, Any]:
        text = f"{message.subject or ''}\n{message.body_text or ''}\n{intent_view}".lower()
        level1 = AIService._surface_level1_label(domain_profile)

        noisy_markers = [
            "newsletter", "unsubscribe", "sale", "discount", "promo", "promotion",
            "marketing", "survey", "digest", "summary", "weekly summary", "marketing email",
            "security alert", "sign in", "signin", "log in", "login", "verification",
            "verify your email", "one-time code", "otp", "password", "password reset",
            "receipt", "invoice", "billing", "transaction", "shipping", "delivery",
            "calendar invite", "meeting", "social", "github sign in", "google sign in",
        ]
        academic_markers = [
            "assignment", "submit", "submission", "exam", "quiz", "deadline",
            "register", "registration", "apply", "application", "attendance",
            "mandatory", "fee", "timetable", "schedule", "project", "classroom",
            "lms", "moodle", "canvas", "blackboard", "lecture", "internship",
            "opportunity", "placement", "hackathon", "workshop", "campus drive",
            "result", "marks", "grade", "counselling", "notice",
        ]

        if any(marker in text for marker in noisy_markers) and not any(marker in text for marker in academic_markers):
            return {"should_process": False, "label": "IGNORE", "reason": "non-academic noise", "confidence": 0.95}

        if level1 == "External / Misc":
            if any(marker in text for marker in academic_markers):
                return {"should_process": True, "label": "INFORMATION", "reason": "external but academically relevant", "confidence": 0.75}
            return {"should_process": False, "label": "IGNORE", "reason": "external non-academic mail", "confidence": 0.9}

        if any(marker in text for marker in academic_markers):
            return {"should_process": True, "label": "INFORMATION", "reason": "academic action detected", "confidence": 0.8}

        return {"should_process": False, "label": "IGNORE", "reason": "no clear academic action", "confidence": 0.8}

    @staticmethod
    def classify_email_gate(message: GmailMessage, domain_profile, cleaned_text: str, use_llm: bool = True) -> Dict[str, Any]:
        intent_view = AIService._surface_intent_view(message, cleaned_text)

        if use_llm:
            try:
                raw_gate = AIService.call_small_model(
                    AIService._gate_prompt(message, domain_profile, intent_view)
                )
                parsed = AIService.extract_json_from_text(raw_gate) or {}
                should_process = bool(parsed.get("should_process", False))
                label = str(parsed.get("label") or "IGNORE").strip().upper()
                if label not in {"ASSIGNMENT", "EXAM", "OPPORTUNITY", "ACADEMIC_ADMIN", "INFORMATION", "IGNORE"}:
                    label = "IGNORE"
                confidence = float(parsed.get("confidence") or (0.85 if should_process else 0.9))
                if confidence > 1.0:
                    confidence = confidence / 100.0
                return {
                    "should_process": should_process,
                    "label": label,
                    "reason": str(parsed.get("reason") or "").strip() or ("academic intent detected" if should_process else "non-academic mail"),
                    "confidence": max(0.0, min(1.0, confidence)),
                    "raw": raw_gate,
                }
            except Exception as exc:
                logger.warning("[AI] gate_llm_failed %s error=%s", _mail_log_context(message), exc)

        gate = AIService._gate_heuristic_decision(message, domain_profile, intent_view)
        gate["raw"] = None
        return gate

    @staticmethod
    def _surface_intent_view(message: GmailMessage, cleaned_text: str) -> str:
        return _build_intent_view(message.subject or "", cleaned_text)

    @staticmethod
    def _surface_extraction_prompt(message: GmailMessage, domain_profile, intent_view: str) -> str:
        return (
            SURFACE_EXTRACTION_PROMPT
            + "\n\n"
            + f"SOURCE TRUST LEVEL: {AIService._surface_level1_label(domain_profile)}\n"
            + f"SUBJECT: {message.subject or ''}\n\n"
            + intent_view
        )

    @staticmethod
    def _surface_classification_prompt(
        message: GmailMessage,
        domain_profile,
        intent_view: str,
        facts: Dict[str, Any],
    ) -> str:
        return (
            SURFACE_CLASSIFICATION_PROMPT
            + "\n\nINPUT_FACTS JSON:\n"
            + json.dumps(facts, ensure_ascii=True)
            + "\n\nSOURCE TRUST LEVEL: "
            + AIService._surface_level1_label(domain_profile)
            + "\nSUBJECT: "
            + (message.subject or "")
            + "\n\nEMAIL BODY:\n"
            + intent_view
        )

    @staticmethod
    def _default_surface_facts() -> Dict[str, Any]:
        return {
            "action_required": False,
            "has_deadline": False,
            "deadline_text": "",
            "is_exam": False,
            "is_submission": False,
            "is_mandatory": False,
            "is_opportunity": False,
        }

    @staticmethod
    def _surface_heuristic_decision(message: GmailMessage, domain_profile, intent_view: str, facts: Dict[str, Any]) -> Dict[str, Any]:
        text = f"{message.subject or ''}\n{message.body_text or ''}\n{intent_view}".lower()
        level1 = AIService._surface_level1_label(domain_profile)

        if any(word in text for word in ["unsubscribe", "newsletter", "sale", "discount", "advertisement", "promo"]) and not facts.get("action_required"):
            return {"decision": "IGNORE", "confidence": 0.9, "reasoning": "newsletter or advertisement", "label_topic": "IGNORE"}

        if any(word in text for word in ["exam", "quiz", "practical", "viva", "supplementary"]):
            return {"decision": "EXAM", "confidence": 0.95, "reasoning": "exam-related content", "label_topic": "EXAM"}

        if facts.get("is_submission") or any(word in text for word in ["assignment", "submit", "upload", "report", "project"]):
            return {"decision": "SUBMIT", "confidence": 0.9, "reasoning": "submission or assignment request", "label_topic": "ASSIGNMENT"}

        if facts.get("is_opportunity") or any(word in text for word in ["internship", "hackathon", "workshop", "career", "placement", "opportunity"]):
            return {"decision": "OPPORTUNITY", "confidence": 0.85, "reasoning": "career or learning opportunity", "label_topic": "OPPORTUNITY"}

        if facts.get("is_mandatory") or any(word in text for word in ["mandatory", "registration", "fee", "policy", "attendance", "enrollment"]):
            return {"decision": "ACADEMIC_ADMIN", "confidence": 0.8, "reasoning": "mandatory institutional process", "label_topic": "ACADEMIC_ADMIN"}

        if level1 in {"Institutional Sender", "External Academic Platform"} and facts.get("action_required"):
            return {"decision": "ACADEMIC_ADMIN", "confidence": 0.65, "reasoning": "action required from academic source", "label_topic": "ACADEMIC_ADMIN"}

        return {"decision": "IGNORE", "confidence": 0.55, "reasoning": "no meaningful academic action", "label_topic": "INFORMATION"}

    @staticmethod
    def _surface_decision_to_entity_type(decision: str, fallback_text: str = "") -> str:
        decision = (decision or "").strip().upper()
        if decision == "SUBMIT":
            return "ASSIGNMENT"
        if decision == "EXAM":
            return "EXAM"
        if decision == "OPPORTUNITY":
            return "OPPORTUNITY"
        if decision == "ACADEMIC_ADMIN":
            return "ACADEMIC_ADMIN"
        if decision == "INFORMATION":
            return "INFORMATION"
        return _normalize_entity_type(None, fallback_text)

    @staticmethod
    def classify_email_surface(message: GmailMessage, domain_profile, cleaned_text: str, use_llm: bool = True) -> Dict[str, Any]:
        intent_view = AIService._surface_intent_view(message, cleaned_text)
        facts = AIService._default_surface_facts()
        raw_stage1 = None
        raw_stage2 = None

        if use_llm:
            try:
                raw_stage1 = AIService.call_small_model(
                    AIService._surface_extraction_prompt(message, domain_profile, intent_view)
                )
                parsed_stage1 = AIService.extract_json_from_text(raw_stage1) or {}
                if isinstance(parsed_stage1, dict):
                    for key in facts.keys():
                        facts[key] = bool(parsed_stage1.get(key, facts[key]))
            except Exception as exc:
                logger.warning("[AI] Surface stage1 failed for %s: %s", message.gmail_id, exc)

            try:
                raw_stage2 = AIService.call_small_model(
                    AIService._surface_classification_prompt(message, domain_profile, intent_view, facts)
                )
                parsed_stage2 = AIService.extract_json_from_text(raw_stage2) or {}
                label_topic = str(parsed_stage2.get("label_topic") or "").strip()
                summary = str(parsed_stage2.get("summary") or "").strip()
                decision = AIService._decision_from_topic(label_topic, message, domain_profile, cleaned_text, facts)
                if decision == "IGNORE" and label_topic:
                    confidence = float(parsed_stage2.get("confidence") or facts.get("confidence") or 0.75)
                    if confidence > 1.0:
                        confidence = confidence / 100.0
                    return {
                        "decision": "IGNORE",
                        "confidence": 0.2,
                        "reasoning": "ignored by topic classifier",
                        "label_topic": label_topic,
                        "summary": summary,
                        "raw_stage1": raw_stage1,
                        "raw_stage2": raw_stage2,
                        "facts": facts,
                    }
                confidence = float(parsed_stage2.get("confidence") or facts.get("confidence") or 0.75)
                if confidence > 1.0:
                    confidence = confidence / 100.0
                return {
                    "decision": decision,
                    "confidence": confidence,
                    "reasoning": summary or label_topic or "classified",
                    "label_topic": label_topic,
                    "summary": summary,
                    "raw_stage1": raw_stage1,
                    "raw_stage2": raw_stage2,
                    "facts": facts,
                }
            except Exception as exc:
                logger.warning("[AI] Surface stage2 failed for %s: %s", message.gmail_id, exc)

        fallback = AIService._surface_heuristic_decision(message, domain_profile, intent_view, facts)
        fallback["raw_stage1"] = raw_stage1
        fallback["raw_stage2"] = raw_stage2
        fallback["facts"] = facts
        return fallback

    @staticmethod
    def _decision_from_topic(
        label_topic: str,
        message: GmailMessage,
        domain_profile,
        cleaned_text: str,
        facts: Dict[str, Any],
    ) -> str:
        topic = (label_topic or "").strip().upper()

        if topic == "ASSIGNMENT":
            return "SUBMIT"
        if topic == "EXAM":
            return "EXAM"
        if topic == "OPPORTUNITY":
            return "OPPORTUNITY"
        if topic == "ACADEMIC_ADMIN":
            return "ACADEMIC_ADMIN"
        if topic in {"INFORMATION", "IGNORE"}:
            return "IGNORE"
        return AIService._surface_heuristic_decision(message, domain_profile, cleaned_text, facts)["decision"]

    @staticmethod
    def _fallback_signal(message: GmailMessage, domain_profile) -> Dict[str, Any]:
        subject = _clean_text(message.subject)
        body = message.body_text or ""
        entity_type = _normalize_entity_type(None, f"{subject}\n{body}")
        title = subject or "Untitled academic email"
        summary = (message.snippet or body or subject or "").strip()
        if len(summary) > 240:
            summary = summary[:237] + "..."
        return {
            "title": title,
            "summary": summary,
            "intent": "read" if entity_type in {"ACADEMIC_ADMIN", "INFORMATION"} else "submit",
            "type_candidates": [entity_type],
            "deadline": None,
            "event_date": None,
            "other_dates": [],
            "entities": _extract_entities_from_text(subject, body),
            "confidence": 0.15,
            "raw_llm_output": None,
        }

    @staticmethod
    def _build_prompt(message: GmailMessage, domain_profile, cleaned_text: str) -> str:
        return SYSTEM_PROMPT.format(
            source=getattr(domain_profile, "classification", "unknown"),
            subject=message.subject or "",
            content=cleaned_text or "",
            received_at=message.internal_date.isoformat() if message.internal_date else "",
        )

    @staticmethod
    def _normalize_signal(message: GmailMessage, domain_profile, raw_output: Optional[Dict[str, Any]], cleaned_text: str) -> Dict[str, Any]:
        signal = raw_output or {}
        subject = _clean_text(message.subject)
        body = message.body_text or ""
        fallback_text = f"{subject}\n{cleaned_text}\n{body}"

        title = str(signal.get("title") or subject or "Academic email").strip()
        summary = str(signal.get("summary") or message.snippet or subject or "").strip()
        if len(summary) > 320:
            summary = summary[:317] + "..."

        intent = str(signal.get("intent") or "").strip().lower()
        if intent not in {"submit", "register", "attend", "read", "pay", "apply"}:
            intent = "read" if "announcement" in fallback_text.lower() else "submit"

        type_candidates = signal.get("type_candidates")
        if not isinstance(type_candidates, list):
            type_candidates = []
        normalized_candidates = []
        for candidate in type_candidates:
            normalized_candidates.append(_normalize_entity_type(candidate, fallback_text))
        if not normalized_candidates:
            normalized_candidates = [_normalize_entity_type(None, fallback_text)]

        # New explicit date fields
        deadline = signal.get("deadline")
        if not (isinstance(deadline, dict) and deadline.get("iso")):
            deadline = None
        event_date = signal.get("event_date")
        if not (isinstance(event_date, dict) and event_date.get("iso")):
            event_date = None
        other_dates = signal.get("other_dates")
        if not isinstance(other_dates, list):
            other_dates = []
        normalized_other_dates = []
        for item in other_dates:
            if isinstance(item, dict) and item.get("iso"):
                normalized_other_dates.append({
                    "text": item.get("text"),
                    "iso": item.get("iso")
                })

        entities = signal.get("entities")
        if not isinstance(entities, list):
            entities = []
        normalized_entities = [str(entity).strip() for entity in entities if str(entity).strip()]
        if not normalized_entities:
            normalized_entities = _extract_entities_from_text(subject, body)

        confidence = signal.get("confidence", 0.15)
        try:
            confidence = float(confidence)
        except Exception:
            confidence = 0.15
        confidence = max(0.0, min(1.0, confidence))

        return {
            "title": title,
            "summary": summary,
            "intent": intent,
            "type_candidates": normalized_candidates[:3],
            "deadline": deadline,
            "event_date": event_date,
            "other_dates": normalized_other_dates[:5],
            "entities": normalized_entities[:5],
            "confidence": confidence,
            "raw_llm_output": signal,
        }

    @staticmethod
    def _parse_deadline_from_signal(signal: Dict[str, Any], message: Optional[GmailMessage] = None) -> Optional[datetime.datetime]:
        deadline = signal.get("deadline")
        if not (isinstance(deadline, dict) and deadline.get("iso")):
            return None
        try:
            parsed = datetime.datetime.fromisoformat(str(deadline.get("iso")).replace("Z", "+00:00"))
            parsed = _ensure_aware(parsed)
        except Exception:
            return None

        if message and getattr(message, "internal_date", None):
            internal_date = _ensure_aware(message.internal_date)
            if internal_date and abs((parsed - internal_date).total_seconds()) < 60:
                return None
        return parsed

    @staticmethod
    def _render_signal_payload(signal: Dict[str, Any], raw_llm_output: Optional[str]) -> Dict[str, Any]:
        payload = dict(signal)
        payload["raw_llm_output"] = raw_llm_output
        return payload

    @staticmethod
    def _store_extracted_signal(db, message: GmailMessage, signal: Dict[str, Any], raw_llm_output: Optional[str]) -> ExtractedSignal:
        ctx = _mail_log_context(message)
        extracted_dates = []
        deadline = signal.get("deadline")
        if isinstance(deadline, dict) and deadline.get("iso"):
            extracted_dates.append({**deadline, "kind": "deadline"})
        event_date = signal.get("event_date")
        if isinstance(event_date, dict) and event_date.get("iso"):
            extracted_dates.append({**event_date, "kind": "event_date"})
        other_dates = signal.get("other_dates")
        if isinstance(other_dates, list):
            for item in other_dates:
                if isinstance(item, dict) and item.get("iso"):
                    extracted_dates.append({**item, "kind": item.get("kind") or "other"})
        signal_row = ExtractedSignal(
            source_email_id=message.gmail_id,
            uid=message.uid,
            raw_llm_output=AIService._render_signal_payload(signal, raw_llm_output),
            extracted_dates=extracted_dates,
            extracted_entities=signal.get("entities") or [],
            intent=signal.get("intent"),
            type_candidates=signal.get("type_candidates") or [],
            confidence=float(signal.get("confidence") or 0.0),
        )
        db.add(signal_row)
        db.flush()
        logger.info("[AI] signal_saved %s signal_id=%s intent=%s confidence=%.2f", ctx, signal_row.id, signal_row.intent, signal_row.confidence or 0.0)
        return signal_row

    @staticmethod
    def _entity_similarity(
        entity: AcademicEntity,
        title: str,
        entity_type: str,
        deadline: Optional[datetime.datetime],
        sender: str,
        entity_source_senders: List[str],
    ) -> float:
        if not entity.entity_type or entity.entity_type != entity_type:
            return 0.0

        entity_sig, _ = _normalize_match_signature(entity.canonical_title)
        title_sig, _ = _normalize_match_signature(title)
        if not entity_sig or not title_sig:
            return 0.0

        title_similarity = SequenceMatcher(None, entity_sig, title_sig).ratio()
        if title_similarity < 0.78:
            return 0.0

        sender_l = (sender or "").strip().lower()
        sender_domain = _sender_domain(sender)
        sender_score = 0.0
        if sender_l:
            for existing_sender in entity_source_senders:
                existing_sender_l = (existing_sender or "").strip().lower()
                if not existing_sender_l:
                    continue
                if existing_sender_l == sender_l:
                    sender_score = 0.18
                    break
                if _sender_domain(existing_sender_l) == sender_domain:
                    sender_score = max(sender_score, 0.1)

        deadline_score = 0.0
        if deadline and entity.best_deadline:
            delta_days = abs((_ensure_aware(entity.best_deadline) - _ensure_aware(deadline)).total_seconds()) / 86400.0
            deadline_window = 2.5 if entity_type in {"ASSIGNMENT", "EXAM", "ACADEMIC_ADMIN"} else 7.0
            if delta_days > deadline_window:
                return 0.0
            deadline_score = max(0.0, 0.18 - min(delta_days, deadline_window) * 0.03)
        elif deadline or entity.best_deadline:
            if entity_type in {"ASSIGNMENT", "EXAM", "ACADEMIC_ADMIN"}:
                return 0.0
            deadline_score = 0.05

        score = (title_similarity * 0.72) + deadline_score + sender_score
        return min(score, 1.0)

    @staticmethod
    def _candidate_source_senders(db, entity_ids: List[int]) -> Dict[int, List[str]]:
        if not entity_ids:
            return {}
        rows = (
            db.query(EntitySourceMap.entity_id, GmailMessage.sender)
            .join(GmailMessage, GmailMessage.gmail_id == EntitySourceMap.source_email_id)
            .filter(EntitySourceMap.entity_id.in_(entity_ids))
            .all()
        )
        mapped: Dict[int, List[str]] = {}
        for entity_id, sender in rows:
            mapped.setdefault(entity_id, []).append(sender or "")
        return mapped

    @staticmethod
    def _upsert_academic_entity(db, message: GmailMessage, signal: Dict[str, Any], signal_row: ExtractedSignal) -> Tuple[AcademicEntity, bool]:
        ctx = _mail_log_context(message)
        title = signal.get("title") or _clean_text(message.subject) or "Academic email"
        entity_type = _normalize_entity_type(signal.get("type_candidates", [None])[0], f"{title} {signal.get('summary', '')}")
        deadline = AIService._parse_deadline_from_signal(signal, message=message)
        confidence = float(signal.get("confidence") or 0.0)
        sender = message.sender or ""

        candidates = db.query(AcademicEntity).filter(AcademicEntity.uid == message.uid).all()
        sender_map = AIService._candidate_source_senders(db, [entity.id for entity in candidates])

        best_entity = None
        best_score = 0.0
        for entity in candidates:
            if (getattr(entity, "origin", "system") or "system").lower() == "manual":
                continue
            if entity.entity_type != entity_type:
                continue
            entity_score = AIService._entity_similarity(
                entity,
                title=title,
                entity_type=entity_type,
                deadline=deadline,
                sender=sender,
                entity_source_senders=sender_map.get(entity.id, []),
            )
            if entity_score >= 0.82 and entity_score > best_score:
                best_score = entity_score
                best_entity = entity

        created = False
        if best_entity is None:
            best_entity = AcademicEntity(
                uid=message.uid,
                origin="system",
                canonical_title=title,
                summary=str(signal.get("summary") or "").strip() or None,
                entity_type=entity_type,
                best_deadline=deadline,
                confidence_score=confidence,
            )
            db.add(best_entity)
            db.flush()
            created = True
            logger.info("[AI] entity_created %s entity_id=%s title=%s type=%s", ctx, best_entity.id, best_entity.canonical_title, best_entity.entity_type)
        else:
            if not getattr(best_entity, "origin", None):
                best_entity.origin = "system"
            existing_sig, _ = _normalize_match_signature(best_entity.canonical_title or "")
            new_sig, _ = _normalize_match_signature(title)
            sig_similarity = SequenceMatcher(None, existing_sig, new_sig).ratio() if existing_sig and new_sig else 0.0
            if title and len(title) > len(best_entity.canonical_title or "") and sig_similarity >= 0.9:
                best_entity.canonical_title = title
            if signal.get("summary") and not getattr(best_entity, "summary", None):
                best_entity.summary = str(signal.get("summary") or "").strip() or None
            if deadline:
                existing_deadline = _ensure_aware(best_entity.best_deadline)
                if existing_deadline is None and sig_similarity >= 0.85:
                    best_entity.best_deadline = deadline
                else:
                    delta_existing = abs((existing_deadline - _utc_now()).total_seconds())
                    delta_new = abs((deadline - _utc_now()).total_seconds())
                    if sig_similarity >= 0.9 and (delta_new < delta_existing or deadline < existing_deadline):
                        best_entity.best_deadline = deadline
            best_entity.confidence_score = round(min(1.0, max(best_entity.confidence_score or 0.0, confidence, best_score)), 3)
            logger.info("[AI] entity_matched %s entity_id=%s score=%.2f title=%s", ctx, best_entity.id, best_score, best_entity.canonical_title)

        map_exists = (
            db.query(EntitySourceMap.id)
            .filter(
                EntitySourceMap.entity_id == best_entity.id,
                EntitySourceMap.source_email_id == message.gmail_id,
            )
            .first()
        )
        if not map_exists:
            db.add(EntitySourceMap(entity_id=best_entity.id, source_email_id=message.gmail_id))
            logger.info("[AI] source_linked %s entity_id=%s", ctx, best_entity.id)

        return best_entity, created

    @staticmethod
    def process_email(message: GmailMessage, db=None, batch_mode: bool = False, use_llm: bool = True) -> Dict[str, Any]:
        ctx = _mail_log_context(message)
        logger.info("[AI] start %s batch_mode=%s use_llm=%s", ctx, batch_mode, use_llm)
        cleaned = preprocess_email_for_llm(
            subject=message.subject,
            body=message.body_text,
            sender=message.sender,
        )
        cleaned_text = cleaned.get("clean_text", "") if isinstance(cleaned, dict) else ""
        logger.info("[AI] preprocessed %s cleaned_len=%s", ctx, len(cleaned_text))
        domain_profile = DomainTrustScorer.score_sender(sender=message.sender, db=db, user_id=message.uid)
        logger.info(
            "[AI] trust %s classification=%s weight=%s",
            ctx,
            getattr(domain_profile, "classification", None),
            getattr(domain_profile, "source_weight", None),
        )

        gate_result = AIService.classify_email_gate(
            message=message,
            domain_profile=domain_profile,
            cleaned_text=cleaned_text,
            use_llm=use_llm,
        )
        logger.info(
            "[AI] gate %s should_process=%s label=%s confidence=%s reason=%s",
            ctx,
            gate_result.get("should_process"),
            gate_result.get("label"),
            gate_result.get("confidence"),
            gate_result.get("reason"),
        )
        if not gate_result.get("should_process"):
            message.ai_summary = gate_result.get("reason") or "Skipped by academic gate"
            message.ai_label_topic = "IGNORE"
            message.ai_label_urgency = "read"
            message.ai_label_source = getattr(domain_profile, "classification", None)
            message.normalized_topic = "IGNORE"
            message.deadline_iso = None
            message.deadline_confidence = None
            message.ai_processed = True
            message.ai_status = "completed"
            if db is not None:
                db.flush()
                append_csv_row(
                    "ai_signal_log.csv",
                    {
                        "timestamp": utc_timestamp(),
                        "uid": message.uid,
                        "gmail_id": message.gmail_id,
                        "stage": "gated_out",
                        "title": message.subject or "",
                        "intent": "",
                        "type_candidates": [gate_result.get("label") or "IGNORE"],
                        "confidence": gate_result.get("confidence"),
                        "entity_id": "",
                        "entity_created": False,
                        "raw_llm_present": bool(use_llm),
                        "error": "",
                    },
                    AI_CSV_FIELDS,
                )
            logger.info("[AI] gate_skip %s", ctx)
            return {
                "decision": "IGNORE",
                "skipped_by_gate": True,
                "gate": gate_result,
                "summary": message.ai_summary,
                "confidence": 0.0,
                "raw_llm_output": None,
                "entity_id": None,
                "entity_created": False,
            }

        surface_result = AIService.classify_email_surface(
            message=message,
            domain_profile=domain_profile,
            cleaned_text=cleaned_text,
            use_llm=use_llm,
        )
        surface_decision = str(surface_result.get("decision") or "").upper()
        surface_label_topic = str(surface_result.get("label_topic") or "").strip()
        logger.info("[AI] surface %s decision=%s topic=%s confidence=%s", ctx, surface_decision, surface_label_topic, surface_result.get("confidence"))

        if surface_decision == "IGNORE":
            fallback = AIService._fallback_signal(message, domain_profile)
            fallback["summary"] = surface_result.get("summary") or fallback.get("summary")
            fallback["title"] = fallback.get("title") or _clean_text(message.subject) or "Academic email"
            fallback["intent"] = "read"
            fallback["type_candidates"] = ["INFORMATION"]
            logger.info("[AI] ignore %s fallback_type=%s", ctx, fallback.get("type_candidates"))
            if db is not None:
                signal_row = AIService._store_extracted_signal(
                    db,
                    message,
                    {
                        **fallback,
                        "surface_decision": surface_decision,
                        "surface_label_topic": surface_label_topic,
                        "surface_reasoning": surface_result.get("reasoning"),
                        "source_trust_level": getattr(domain_profile, "classification", "External / Misc"),
                    },
                    raw_llm_output=json.dumps(
                        {
                            "surface_result": surface_result,
                            "surface_ignored": True,
                        },
                        ensure_ascii=True,
                    ),
                )
                message.ai_summary = fallback.get("summary")
                message.ai_label_topic = "IGNORE"
                message.ai_label_source = getattr(domain_profile, "classification", None)
                message.normalized_topic = "IGNORE"
                message.ai_processed = True
                message.ai_status = "completed"
                db.flush()
                append_csv_row(
                    "ai_signal_log.csv",
                    {
                        "timestamp": utc_timestamp(),
                        "uid": message.uid,
                        "gmail_id": message.gmail_id,
                        "stage": "ignored",
                        "title": fallback.get("title"),
                        "intent": fallback.get("intent"),
                        "type_candidates": fallback.get("type_candidates"),
                        "confidence": fallback.get("confidence"),
                        "entity_id": "",
                        "entity_created": False,
                        "raw_llm_present": bool(use_llm),
                        "error": "",
                    },
                    AI_CSV_FIELDS,
                )
                return {
                    "signal_id": signal_row.id,
                    "entity_id": None,
                    "entity_created": False,
                    "decision": "IGNORE",
                    "summary": fallback.get("summary"),
                    "confidence": fallback.get("confidence"),
                    "raw_llm_output": surface_result,
                }

        prompt = AIService._build_prompt(message, domain_profile, cleaned_text)
        logger.info("[AI] prompt_built %s prompt_chars=%s", ctx, len(prompt))

        raw_llm_output = None
        parsed_output: Optional[Dict[str, Any]] = None
        if use_llm:
            try:
                raw_llm_output = AIService.call_small_model(prompt)
                logger.info("[AI] raw_output %s chars=%s", ctx, len(raw_llm_output))
                parsed_output = AIService.extract_json_from_text(raw_llm_output)
                logger.info("[AI] parsed_output %s parsed=%s", ctx, bool(parsed_output))
            except Exception as exc:
                logger.warning("[AI] llm_failed %s error=%s", ctx, exc)

        signal = AIService._normalize_signal(message, domain_profile, parsed_output, cleaned_text)
        if surface_decision and surface_decision != "IGNORE":
            surface_entity_type = AIService._surface_decision_to_entity_type(surface_decision, f"{message.subject or ''} {cleaned_text}")
            signal["type_candidates"] = [surface_entity_type] + [candidate for candidate in signal.get("type_candidates", []) if candidate != surface_entity_type]
            if surface_result.get("summary"):
                signal["summary"] = surface_result["summary"]
            signal["surface_decision"] = surface_decision
            signal["surface_label_topic"] = surface_label_topic
            signal["surface_reasoning"] = surface_result.get("reasoning")
            signal["source_trust_level"] = getattr(domain_profile, "classification", "External / Misc")
        logger.info(
            "[AI] normalized %s type_candidates=%s intent=%s confidence=%.2f",
            ctx,
            signal.get("type_candidates"),
            signal.get("intent"),
            float(signal.get("confidence") or 0.0),
        )
        if parsed_output is None and not raw_llm_output:
            logger.info("[AI] fallback_minimal %s", ctx)

        if db is None:
            logger.info("[AI] end %s db=None", ctx)
            return {
                "signal": signal,
                "raw_llm_output": raw_llm_output,
            }

        try:
            message.ai_status = "processing"
            message.ai_processed = False
            logger.info("[AI] persist_signal %s", ctx)
            signal_row = AIService._store_extracted_signal(db, message, signal, raw_llm_output)
            logger.info("[AI] upsert_entity %s signal_id=%s", ctx, signal_row.id)
            entity, created = AIService._upsert_academic_entity(db, message, signal, signal_row)
            message.ai_summary = signal.get("summary")
            message.ai_label_topic = entity.entity_type
            message.ai_label_urgency = signal.get("intent")
            message.ai_label_source = getattr(domain_profile, "classification", None)
            message.deadline_iso = AIService._parse_deadline_from_signal(signal, message=message)
            message.deadline_confidence = str(signal.get("confidence")) if signal.get("confidence") is not None else None
            message.normalized_topic = entity.entity_type
            message.ai_processed = True
            message.ai_status = "completed"

            db.flush()
            append_csv_row(
                "ai_signal_log.csv",
                {
                    "timestamp": utc_timestamp(),
                    "uid": message.uid,
                    "gmail_id": message.gmail_id,
                    "stage": "processed",
                    "title": entity.canonical_title,
                    "intent": signal.get("intent"),
                    "type_candidates": signal.get("type_candidates"),
                    "confidence": signal.get("confidence"),
                    "entity_id": entity.id,
                    "entity_created": created,
                    "raw_llm_present": bool(raw_llm_output),
                    "error": "",
                },
                AI_CSV_FIELDS,
            )
            logger.info(
                "[AI] done %s entity_id=%s created=%s deadline=%s type=%s",
                ctx,
                entity.id,
                created,
                entity.best_deadline.isoformat() if entity.best_deadline else None,
                entity.entity_type,
            )
            return {
                "signal_id": signal_row.id,
                "entity_id": entity.id,
                "entity_created": created,
                "title": entity.canonical_title,
                "type": entity.entity_type,
                "deadline": entity.best_deadline.isoformat() if entity.best_deadline else None,
                "summary": signal.get("summary"),
                "confidence": signal.get("confidence"),
                "raw_llm_output": raw_llm_output,
            }
        except Exception as err:
            logger.exception("[AI] failed %s", ctx)
            message.ai_processed = False
            message.ai_status = "failed"
            if hasattr(message, "retry_count"):
                message.retry_count = (message.retry_count or 0) + 1
                message.last_error = str(err)
                backoff_m = [30, 120, 360, 720, 1440]
                idx = min(message.retry_count - 1, len(backoff_m) - 1)
                message.next_retry_at = datetime.datetime.utcnow() + datetime.timedelta(minutes=backoff_m[idx])
            append_csv_row(
                "ai_signal_log.csv",
                {
                    "timestamp": utc_timestamp(),
                    "uid": message.uid,
                    "gmail_id": message.gmail_id,
                    "stage": "error",
                    "title": message.subject or "",
                    "intent": "",
                    "type_candidates": "",
                    "confidence": "",
                    "entity_id": "",
                    "entity_created": False,
                    "raw_llm_present": bool(raw_llm_output),
                    "error": str(err),
                },
                AI_CSV_FIELDS,
            )
            raise

    @staticmethod
    def initialize_ollama_backend() -> None:
        AIService.initialize_inference_backend()

    @staticmethod
    def _call_ollama(prompt: str, model: str) -> str:
        return AIService._call_inference(prompt, model)

    @staticmethod
    def run_email_inference(message: GmailMessage, **kwargs) -> Dict[str, Any]:
        return AIService.process_email(message, **kwargs)
