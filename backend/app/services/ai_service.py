import requests
import json
import datetime
import os
from app.ai.preprocessing import preprocess_email_for_llm
from app.models.gmail.gmail_message import GmailMessage
from app.services.level1_classifier import Level1Classifier
from app.services.academic_context_engine import AcademicContextEngine


OLLAMA_URL = os.getenv("OLLAMA_URL", "http://192.168.31.2:11434/api/generate")
MODEL_NAME = os.getenv("OLLAMA_MODEL", "phi3:mini")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_API_KEY = os.getenv("openrouter_api_key", "")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "qwen/qwen-2.5-vl-7b-instruct")

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

BATCH_SYSTEM_PROMPT = """You are an academic email classifier. 
Output MUST be a strictly valid JSON ARRAY of objects. Each object corresponds to an email and must contain specific fields.

REQUIRED JSON FORMAT PER ITEM:
{{
  "email_id": "the original ID provided",
  "summary": "brief 1-sentence summary",
  "label_topic": "one of the allowed topic labels",
  "label_urgency": "one of the allowed urgency labels",
  "deadline_iso": "ISO 8601 or null",
  "deadline_confidence": "High | Medium | Low | None"
}}

ALLOWED TOPIC LABELS:
{topics}

ALLOWED URGENCY LABELS:
{urgencies}

DEADLINE RULES:
- Use EMAIL RECEIVED AT as reference.
- If no deadline exists or uncertain, return null.

EMAILS TO PROCESS:
{emails_block}
"""


class AIService:
    """Service class for AI-powered email inference and classification."""

    @staticmethod
    def run_email_inference(message: GmailMessage, batch_mode: bool = False):
        """
        Run AI inference on a single GmailMessage.
        Updates the message with AI results. The caller is responsible for committing to DB.
        """

        # --- Level 1 classification ---
        features = preprocess_email_for_llm(
            subject=message.subject,
            body=message.body_text,
            sender=message.sender,
        )

        label_source = Level1Classifier.classify_source(features["sender_email"])

        # Trust-Based Filtering (NEW): Skip if External / Misc
        if label_source == "External / Misc":
            print(f"[AI SERVICE] Skipping non-academic/misc email: {message.gmail_id}")
            message.ai_label_source = label_source
            message.ai_summary = "Non-academic or mixed source - skipped AI."
            message.ai_label_topic = "General Information / Misc"
            message.ai_label_urgency = "None"
            message.normalized_topic = "INFORMATION"
            message.academic_score = 0
            message.ai_processed = True
            message.ai_status = "completed"
            # The caller is responsible for committing to DB, so db.commit() is omitted here.
            return {
                "summary": message.ai_summary,
                "topic": message.ai_label_topic,
                "urgency": message.ai_label_urgency,
                "source": message.ai_label_source,
                "deadline_iso": None,
                "deadline_confidence": "None",
                "academic_score": 0
            }

        try:
            print(f"[AI SERVICE] Starting inference for gmail_id={message.gmail_id}")
            message.ai_processed = False
            message.ai_status = "processing"
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
                    json_match = re.search(r'\{[^{}]*("summary")[^{}]*\}', raw_output, re.DOTALL)
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

            message.ai_processed = False
            message.ai_status = "failed"

            raise

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
        message.ai_status = "completed"


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
        try:
            return AIService._local_inference(prompt)
    
        except requests.exceptions.ConnectionError as e:
            print(f"[AI SERVICE] Local GPU connection failed, fallback triggered: {e}")
            return AIService._openrouter_inference(prompt)
    
        except requests.exceptions.Timeout as e:
            print(f"[AI SERVICE] Local GPU timeout, fallback triggered: {e}")
            return AIService._openrouter_inference(prompt)
    @staticmethod
    def _openrouter_inference(prompt: str) -> str:
        if not OPENROUTER_API_KEY:
            raise ValueError("OpenRouter API key is missing")

        print(f"[AI SERVICE] Attempting OpenRouter Inference with model {OPENROUTER_MODEL}")

        response = requests.post(
            OPENROUTER_URL,
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "HTTP-Referer": "https://uni-dash.local",
                "X-Title": "Uni-Dash Reborn"
            },
            json={
                "model": OPENROUTER_MODEL,
                "messages": [{"role": "user", "content": prompt}]
            },
            timeout=(5, 30)
        )

        if response.status_code != 200:
            print("[AI SERVICE] OpenRouter error:", response.status_code, response.text)
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
        Processes a list of GmailMessages as a single batch to maximize throughput.
        Uses Level 0 filtering to skip trivial emails and Level 1 for trust context.
        """
        if not messages:
            return []

        from app.ai.preprocessing import is_trivial_email

        to_process = []
        results = {}

        # 1. First Pass: Fast Filtering
        for msg in messages:
            # Level 0 Check
            if is_trivial_email(msg.subject, msg.body_text):
                print(f"[AI BATCH] Skipping trivial email: {msg.gmail_id}")
                msg.ai_summary = "Trivial/Automated notification - skipped AI."
                msg.ai_label_topic = "General Information / Misc"
                msg.ai_label_urgency = "None"
                msg.normalized_topic = "INFORMATION"
                msg.academic_score = 0
                msg.ai_processed = True
                msg.ai_status = "completed"
                results[msg.gmail_id] = {"status": "skipped"}
                continue

            # Prepare for LLM
            features = preprocess_email_for_llm(
                subject=msg.subject,
                body=msg.body_text,
                sender=msg.sender,
            )
            label_source = Level1Classifier.classify_source(features["sender_email"])
            
            # Trust-Based Filtering (NEW): Skip if External / Misc
            if label_source == "External / Misc":
                print(f"[AI BATCH] Skipping non-academic/misc email: {msg.gmail_id}")
                msg.ai_label_source = label_source
                msg.ai_summary = "Non-academic or mixed source - skipped AI."
                msg.ai_label_topic = "General Information / Misc"
                msg.ai_label_urgency = "None"
                msg.normalized_topic = "INFORMATION"
                msg.academic_score = 0
                msg.ai_processed = True
                msg.ai_status = "completed"
                results[msg.gmail_id] = {"status": "skipped_trust"}
                continue
            
            to_process.append({
                "id": msg.gmail_id,
                "text": features["clean_text"],
                "subject": msg.subject,
                "source": label_source,
                "received_at": msg.internal_date.isoformat() if msg.internal_date else "",
                "msg_obj": msg  # Keep reference for post-processing
            })

        if not to_process:
            db.commit()
            return results

        # 2. Level 2: Batch LLM Inference
        emails_block = ""
        for item in to_process:
            emails_block += f"\n---\nID: {item['id']}\nRECEIVED: {item['received_at']}\nSOURCE: {item['source']}\nSUBJECT: {item['subject']}\nCONTENT: {item['text']}\n---\n"

        prompt = BATCH_SYSTEM_PROMPT.format(
            topics="\n- ".join(LEVEL2_LABELS),
            urgencies="\n- ".join(URGENCY_LABELS),
            emails_block=emails_block
        )

        try:
            raw_output = AIService._hybrid_inference(prompt)
            # Basic scrubbing of potential Markdown
            if "```json" in raw_output:
                raw_output = re.search(r'\[.*\]', raw_output, re.DOTALL).group()
            
            parsed_batch = json.loads(raw_output)
            if not isinstance(parsed_batch, list):
                if isinstance(parsed_batch, dict):
                    parsed_batch = [parsed_batch]
                else:
                    raise ValueError("LLM did not return a list")

            # Map results back to messages
            parsed_map = {item.get("email_id"): item for item in parsed_batch}

            for item in to_process:
                msg = item["msg_obj"]
                gid = item["id"]
                data = parsed_map.get(gid)

                if not data:
                    print(f"[AI BATCH] Missing AI data for {gid}")
                    msg.ai_status = "failed"
                    continue

                # Apply data (reusing similar logic to single mode)
                msg.ai_label_source = item["source"]
                msg.ai_label_topic = data.get("label_topic", "General Information / Misc")
                msg.ai_label_urgency = data.get("label_urgency", "None")
                msg.ai_summary = data.get("summary", "No summary provided")
                
                msg.normalized_topic = AcademicContextEngine.normalize_topic(msg.ai_label_topic)
                
                # Deadline logic
                if data.get("deadline_iso"):
                    try:
                        msg.deadline_iso = datetime.datetime.fromisoformat(data["deadline_iso"].replace('Z', '+00:00'))
                    except:
                        msg.deadline_iso = None
                
                msg.deadline_confidence = data.get("deadline_confidence", "None")
                
                # Scoring
                norm_deadline = AcademicContextEngine.normalize_deadline(msg.deadline_iso)
                deadline_urgency = AcademicContextEngine.calculate_deadline_urgency(norm_deadline)
                msg.academic_score = int(AcademicContextEngine.calculate_academic_score(
                    deadline_urgency=deadline_urgency,
                    ai_urgency=msg.ai_label_urgency,
                    topic=msg.ai_label_topic,
                    source_trust=item["source"]
                ))
                
                msg.ai_processed = True
                msg.ai_status = "completed"
                results[gid] = {"status": "success"}

        except Exception as e:
            print(f"[AI BATCH] Batch inference catastrophic failure: {e}")
            for item in to_process:
                item["msg_obj"].ai_status = "failed"
            db.rollback()
            raise

        db.commit()
        return results