import requests
import json
import datetime
import os
from app.ai.preprocessing import preprocess_email_for_llm
from app.models.gmail.gmail_message import GmailMessage
from app.services.level1_classifier import Level1Classifier
from app.services.academic_context_engine import AcademicContextEngine

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://192.168.31.2:11434/api/generate")
MODEL_NAME = os.getenv("OLLAMA_MODEL", "qwen2.5:7b-instruct-q4_k_m")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_API_KEY = os.getenv("openrouter_api_key", "")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "mistralai/mistral-7b-instruct")

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

SYSTEM_PROMPT = """Output must be strictly valid JSON. The response must start with {{ and end with }}.
If you include anything outside JSON, the response is invalid.

Analyze the email below and return structured JSON.

SOURCE TRUST LEVEL: {source}
EMAIL RECEIVED AT (ISO 8601): {received_at}
SUBJECT: {subject}
CONTENT: {content}

REQUIRED JSON FORMAT:
{{
  "summary": "brief summary text",
  "label_topic": "topic name",
  "label_urgency": "urgency level",
  "deadline_iso": "ISO 8601 datetime or null",
  "deadline_confidence": "High | Medium | Low | None"
}}

DEADLINE EXTRACTION RULES:
- If a specific deadline is mentioned (e.g., "11 AM tomorrow", "by 25 Jan 2026", "next Monday at 3 PM"),
  convert it to ISO 8601 format using EMAIL RECEIVED AT as reference.
- If only relative time is mentioned ("within 2 days"), compute exact datetime.
- If no deadline exists, return null.
- If uncertain, return null.
- Do NOT guess.

"label_topic" must be EXACTLY one of:
- Timetable / Schedule Update
- Exam Notifications
- Assignment or Submission
- Certification / Courses
- Internship / Placement Opportunities
- Events / Hackathons
- Important Announcements
- Administrative / Fees / Counselling
- General Information / Misc

"label_urgency" must be EXACTLY one of:
- Critical
- High
- Medium
- Low
- None
"""


class AIService:
    """Service class for AI-powered email inference and classification."""

    @staticmethod
    def run_email_inference(message: GmailMessage, db, batch_mode: bool = False):
        """
        Run AI inference on a single GmailMessage.
        Updates the message with AI results and commits to DB.
        """

        # --- Level 1 classification ---
        features = preprocess_email_for_llm(
            subject=message.subject,
            body=message.body_text,
            sender=message.sender,
        )

        label_source = Level1Classifier.classify_source(features["sender_email"])

        prompt = f"""SOURCE TRUST LEVEL: {label_source}
SUBJECT: {message.subject}
CONTENT: {features["clean_text"]}"""

        try:
            full_prompt = SYSTEM_PROMPT.format(
                source=label_source,
                subject=message.subject,
                content=features["clean_text"],
                received_at=message.internal_date.isoformat() if message.internal_date else ""
            )
            
            raw_output = AIService._hybrid_inference(full_prompt, batch_mode)

            # Check if response is valid JSON
            if not raw_output or not raw_output.strip():
                print(f"[AI SERVICE] Empty response from Ollama")
                parsed = {
                    "summary": "AI service returned empty response",
                    "label_topic": "General Information / Misc",
                    "label_urgency": "None"
                }
            else:
                try:
                    parsed = json.loads(raw_output)
                    print(f"[AI SERVICE] Successfully parsed AI response: {parsed}")
                    
                    # Validate required fields
                    required_fields = ["summary", "label_topic", "label_urgency"]
                    if not all(field in parsed for field in required_fields):
                        raise ValueError(f"Missing required fields. Expected: {required_fields}, got: {list(parsed.keys())}")
                    
                    # Validate topic label
                    if parsed["label_topic"] not in LEVEL2_LABELS:
                        print(f"[AI SERVICE] Invalid topic label '{parsed['label_topic']}', using fallback")
                        parsed["label_topic"] = "General Information / Misc"
                    
                    # Validate urgency label
                    if parsed["label_urgency"] not in URGENCY_LABELS:
                        print(f"[AI SERVICE] Invalid urgency label '{parsed['label_urgency']}', using fallback")
                        parsed["label_urgency"] = "None"
                    
                    # Parse deadline fields
                    deadline_iso = parsed.get("deadline_iso")
                    deadline_confidence = parsed.get("deadline_confidence", "None")
                    
                    # Normalize null-like values
                    if deadline_iso in ["null", "", None]:
                        deadline_iso = None
                    
                    parsed["deadline_iso"] = deadline_iso
                    parsed["deadline_confidence"] = deadline_confidence
                        
                except (json.JSONDecodeError, ValueError) as json_error:
                    print(f"[AI SERVICE] JSON parsing/validation failed: {json_error}")
                    print(f"[AI SERVICE] Raw response was: {repr(raw_output[:500])}")
                    
                    # Try to extract JSON from the response if it's wrapped in text
                    import re
                    json_match = re.search(r'\{[^{}]*\{[^{}]*\}[^{}]*\}|\{[^{}]*\}', raw_output, re.DOTALL)
                    if json_match:
                        try:
                            candidate = json_match.group()
                            parsed = json.loads(candidate)
                            print(f"[AI SERVICE] Successfully extracted JSON: {parsed}")
                            
                            # Validate extracted JSON
                            if not all(field in parsed for field in ["summary", "label_topic", "label_urgency"]):
                                raise ValueError("Extracted JSON missing required fields")
                                
                        except (json.JSONDecodeError, ValueError):
                            parsed = {
                                "summary": f"AI response parsing failed: {str(json_error)[:100]}",
                                "label_topic": "General Information / Misc",
                                "label_urgency": "None"
                            }
                    else:
                        parsed = {
                            "summary": f"AI response not valid JSON: {raw_output[:100]}...",
                            "label_topic": "General Information / Misc",
                            "label_urgency": "None"
                        }

        except requests.exceptions.ConnectionError as e:
            print(f"[AI SERVICE] Connection error to Ollama: {e}")
            print(f"[AI SERVICE] Make sure Ollama is running at {OLLAMA_URL}")
            # Re-raise so email stays ai_processed=False and gets retried
            raise

        except requests.exceptions.Timeout as e:
            print(f"[AI SERVICE] Timeout connecting to Ollama: {e}")
            # Re-raise so email stays ai_processed=False and gets retried
            raise

        except Exception as e:
            print(f"[AI SERVICE] Inference failed for message {message.gmail_id}: {e}")
            print(f"[AI SERVICE] Full error details: {type(e).__name__}: {str(e)}")
            parsed = {
                "summary": "",
                "label_topic": "General Information / Misc",
                "label_urgency": "None"
            }

        # --- Store results ---
        message.ai_label_source = label_source
        message.ai_label_topic = parsed.get("label_topic")
        message.ai_label_urgency = parsed.get("label_urgency")
        message.ai_summary = parsed.get("summary")
        
        # Normalize topic to academic ontology
        message.normalized_topic = AcademicContextEngine.normalize_topic(
            parsed.get("label_topic", "General Information / Misc")
        )
        
        # Store deadline information with robust validation
        if parsed.get("deadline_iso"):
            try:
                dt = datetime.datetime.fromisoformat(parsed["deadline_iso"].replace('Z', '+00:00'))
                # Assume UTC if timezone missing
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=datetime.timezone.utc)
                message.deadline_iso = dt
            except ValueError:
                print(f"[AI SERVICE] Invalid ISO format for deadline: {parsed['deadline_iso']}")
                message.deadline_iso = None
        else:
            message.deadline_iso = None
            
        message.deadline_confidence = parsed.get("deadline_confidence", "None")
        
        # Calculate academic intelligence score
        normalized_deadline = AcademicContextEngine.normalize_deadline(message.deadline_iso)
        deadline_urgency = AcademicContextEngine.calculate_deadline_urgency(normalized_deadline)
        
        academic_score = AcademicContextEngine.calculate_academic_score(
            deadline_urgency=deadline_urgency,
            ai_urgency=parsed.get("label_urgency", "None"),
            topic=parsed.get("label_topic", "General Information / Misc"),
            source_trust=label_source
        )
        
        message.academic_score = int(academic_score)
        message.ai_processed = True

        db.commit()

        return {
            "summary": message.ai_summary,
            "topic": message.ai_label_topic,
            "urgency": message.ai_label_urgency,
            "source": message.ai_label_source,
            "deadline_iso": message.deadline_iso.isoformat() if message.deadline_iso else None,
            "deadline_confidence": message.deadline_confidence,
            "academic_score": message.academic_score
        }

    @staticmethod
    def _hybrid_inference(prompt: str, batch_mode: bool = False) -> str:
        """
        Runs API first for lightweight processing, falling back to local.
        Always uses local for batch processing tasks.
        """
        try:
            if batch_mode:
                return AIService._local_inference(prompt)
            else:
                return AIService._openrouter_inference(prompt)
        except Exception as e:
            print(f"[AI SERVICE] Primary inference failed, falling back to local: {e}")
            return AIService._local_inference(prompt)

    @staticmethod
    def _openrouter_inference(prompt: str) -> str:
        """Runs inference via OpenRouter API for lightweight, real-time requests."""
        if not OPENROUTER_API_KEY:
            raise ValueError("OpenRouter API key is missing")

        print(f"[AI SERVICE] Attempting OpenRouter Inference with model {OPENROUTER_MODEL}")
        response = requests.post(
            OPENROUTER_URL,
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "HTTP-Referer": "https://uni-dash.local",  # Required by OpenRouter
                "X-Title": "Uni-Dash Reborn"
            },
            json={
                "model": OPENROUTER_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.0,
                "top_p": 0.1,
                "response_format": {"type": "json_object"}  # Help enforce JSON
            },
            timeout=(5, 30)
        )
        response.raise_for_status()
        output = response.json()["choices"][0]["message"]["content"].strip()
        
        # Strip markdown logic
        if output.startswith("```json"):
            output = output[7:]
        if output.startswith("```"):
            output = output[3:]
        if output.endswith("```"):
            output = output[:-3]
        return output.strip()

    @staticmethod
    def _local_inference(prompt: str) -> str:
        """Runs batched or fallback inference on local Ollama server."""
        print(f"[AI SERVICE] Connecting to Ollama at: {OLLAMA_URL} with model: {MODEL_NAME}")
        response = requests.post(
            OLLAMA_URL,
            json={
                "model": MODEL_NAME,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.0,
                    "top_p": 0.1,
                    "num_predict": 256
                }
            },
            timeout=(5, 60)
        )
        response.raise_for_status()
        raw_output = response.json().get("response", "").strip()
        
        # Strip markdown code blocks
        if raw_output.startswith("```json"):
            raw_output = raw_output[7:]
        if raw_output.startswith("```"):
            raw_output = raw_output[3:]
        if raw_output.endswith("```"):
            raw_output = raw_output[:-3]
        return raw_output.strip()

    @staticmethod
    def run_batch_email_inference(messages: list[GmailMessage], db):
        """
        Process a batch array of Gmail messages using local inference.
        This sends them individually in a loop using the same deterministic logic
        but flags batch_mode=True to enforce local inference usage.
        (Future improvement: batching multiple emails into a single prompt for throughput limit if needed).
        """
        results = []
        for message in messages:
            print(f"[AI SERVICE BATCH] Processing message {message.gmail_id}")
            res = AIService.run_email_inference(message, db, batch_mode=True)
            results.append(res)
        return results