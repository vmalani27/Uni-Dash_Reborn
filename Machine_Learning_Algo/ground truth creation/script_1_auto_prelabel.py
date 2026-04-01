"""
PHASE 1: Auto Pre-Label ALL emails with Falcon3 7B
================================
Goal: Generate model predictions for all 1522 emails
Output: auto_labeled_full.csv with pred_topic only
Note: This is NOT ground truth — just model predictions
"""

import os
import json
import logging
import re
import pandas as pd
import requests
import time

# ----------------------------------------------------------
# Logging setup
# ----------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)-8s | %(message)s',
    handlers=[
        logging.FileHandler('prelabel_inference.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = "source_labeled_dataset.csv"      
OUTPUT_FILE = "auto_labeled_full.csv"

MODEL_NAME = "llama3:latest"
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

USE_COMPACT_INTENT_VIEW = True
USE_TWO_STAGE = True
USE_SOURCE_CONTEXT = False

LEVEL2_LABELS = [
    "SUBMIT",
    "EXAM",
    "OPPORTUNITY",
    "ADMIN",
    "IGNORE",
]

# ----------------------------------------------------------
# Prompt templates (small-model friendly)
# ----------------------------------------------------------

EXTRACTION_PROMPT = """
Extract key facts from this email intent view.

Return ONLY JSON:
{
  "action_required": true/false,
  "has_deadline": true/false,
  "is_exam": true/false,
  "is_submission": true/false,
  "is_mandatory": true/false,
  "is_opportunity": true/false
}
"""

SHORT_CLASSIFICATION_PROMPT = """
Classify the email into ONE category:

SUBMIT: student must create and submit academic work
EXAM: test, quiz, evaluation
OPPORTUNITY: optional career or learning activity
ADMIN: mandatory institutional process
IGNORE: no meaningful academic action

Rules:
- Only ONE label
- SUBMIT only if actual academic work submission
- EXAM only if evaluation
- ADMIN = mandatory process
- OPPORTUNITY = optional

Return ONLY JSON:
{
  "decision": "<SUBMIT|EXAM|OPPORTUNITY|ADMIN|IGNORE>",
  "confidence": <0-100>,
  "reasoning": "<one sentence>"
}
"""

LEGACY_LONG_PROMPT = f"""
You are an AI system that classifies academic emails into exactly one category.

You must choose ONLY ONE category from: SUBMIT, EXAM, OPPORTUNITY, ADMIN, IGNORE

DEFINITIONS:
- SUBMIT: complete and submit academic work
- EXAM: evaluations/tests/quizzes
- OPPORTUNITY: optional growth opportunities
- ADMIN: mandatory institutional process
- IGNORE: no meaningful academic action

Allowed labels: {LEVEL2_LABELS}

Return ONLY JSON:
{{
  "decision": "<SUBMIT|EXAM|OPPORTUNITY|ADMIN|IGNORE>",
  "confidence": <0-100>,
  "reasoning": "<one sentence>"
}}
"""


def build_intent_view(subject, clean_text):
     """Compress noisy email content into a concise intent-centric view."""
     text = clean_text or ""

     # Remove common signature starters.
     text = re.split(r'(?i)\b(thanks|regards|sincerely|best regards|with regards)\b', text)[0]

     # Remove forwarded/reply thread markers.
     text = re.split(r'(?i)(forwarded message|from:|sent:|on .* wrote:)', text)[0]

     # Remove unsubscribe/footer noise lines.
     text = re.sub(r'(?im)^.*unsubscribe.*$', '', text)
     text = re.sub(r'(?im)^.*privacy policy.*$', '', text)
     text = re.sub(r'(?im)^.*terms .*$', '', text)

     # Keep first ~20 non-empty lines.
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
# ----------------------------------------------------------
# JSON extraction utility
# ----------------------------------------------------------

def extract_json(text):
    """
    Robustly extract JSON from text that may contain surrounding content.
    Handles cases where LLM outputs text-wrapped JSON with escaped characters.
    """
    try:
        # Try direct parse first (for clean JSON output)
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Strategy 1: Find first { and last } and try to parse
    start = text.find('{')
    if start != -1:
        # Search for closing brace from the end
        end = text.rfind('}')
        if end > start:
            candidate = text[start:end+1]
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass
    
    # Strategy 2: Try regex with better boundary matching
    # Look for {...} patterns, allowing for nested structures
    match = re.search(r'\{(?:[^{}]|(?:\{[^{}]*\}))*\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass
    
    # Strategy 3: Try line-by-line if it's multi-line JSON
    try:
        lines = text.split('\n')
        for i, line in enumerate(lines):
            if '{' in line:
                # Try to find complete JSON starting from this line
                candidate = '\n'.join(lines[i:])
                result = json.loads(candidate)
                return result
    except (json.JSONDecodeError, ValueError):
        pass

    return None


def call_llm(model_name, prompt, timeout=60):
    """Call Ollama once and return parsed JSON, raw output, and latency."""
    start = time.time()
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": model_name,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": 0, "top_p": 0.1},
        },
        timeout=timeout,
    )
    latency = round((time.time() - start) * 1000)
    raw = response.json().get("response", "").strip()
    parsed = extract_json(raw)
    return parsed, raw, latency

# ----------------------------------------------------------
# LLM Call
# ----------------------------------------------------------

def get_model_prediction(label_source, subject, clean_text):
    """Two-stage inference with optional source context and compact input."""
    intent_view = build_intent_view(subject, clean_text) if USE_COMPACT_INTENT_VIEW else (
        f"SUBJECT:\n{subject}\n\nEMAIL CONTENT:\n{clean_text}"
    )

    source_block = ""
    if USE_SOURCE_CONTEXT:
        source_block = f"SOURCE TRUST LEVEL: {label_source}\n\n"

    try:
        total_latency = 0
        facts = {}

        if USE_TWO_STAGE:
            extraction_prompt = EXTRACTION_PROMPT + "\n\n" + source_block + intent_view
            parsed_facts, raw_facts, lat1 = call_llm(MODEL_NAME, extraction_prompt, timeout=60)
            total_latency += lat1
            logger.debug(f"Stage1 raw output: {raw_facts}")

            if parsed_facts is None:
                logger.warning(f"Stage1 extraction failed; defaulting empty facts. Raw: {raw_facts[:160]}")
                facts = {
                    "action_required": False,
                    "has_deadline": False,
                    "is_exam": False,
                    "is_submission": False,
                    "is_mandatory": False,
                    "is_opportunity": False,
                }
            else:
                facts = parsed_facts

            classification_prompt = (
                SHORT_CLASSIFICATION_PROMPT
                + "\n\nINPUT FACTS JSON:\n"
                + json.dumps(facts, ensure_ascii=True)
                + "\n\n"
                + source_block
                + "\nINTENT VIEW:\n"
                + intent_view
            )
        else:
            classification_prompt = LEGACY_LONG_PROMPT + "\n\n" + source_block + intent_view

        parsed, raw, lat2 = call_llm(MODEL_NAME, classification_prompt, timeout=60)
        total_latency += lat2

        logger.debug(f"Stage2 raw output: {raw}")

        if parsed is None:
            logger.warning(f"Failed to extract JSON from: {raw[:100]}")
            return {
                "reasoning": "",
                "decision": "IGNORE",
                "latency_ms": total_latency,
                "json_valid": False,
                "confidence": 0,
            }

        parsed["latency_ms"] = total_latency
        parsed["json_valid"] = True
        logger.debug(
            f"Extracted - Decision: {parsed.get('decision')}, Reasoning: {parsed.get('reasoning', '')[:50]}..."
        )
        return parsed
    except Exception as e:
        logger.error(f"Inference failed: {str(e)}")
        return {
            "reasoning": "",
            "decision": "IGNORE",
            "latency_ms": 0,
            "json_valid": False,
            "confidence": 0
        }

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------

def main():
    logger.info("="*80)
    logger.info("Starting Phase 1: Auto Pre-Label All Emails")
    logger.info("="*80)
    
    # Load input
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)
    logger.info(f"Loaded input file: {INPUT_FILE} ({len(df)} emails)")
    print(f"Loaded input file: {INPUT_FILE} ({len(df)} emails)")
    
    # Check if we're resuming
    if os.path.exists(OUTPUT_FILE):
        df_out = pd.read_csv(OUTPUT_FILE, dtype=str, keep_default_na=False)
        logger.info(f"Resuming from existing {OUTPUT_FILE}")
        print(f"Resuming from existing {OUTPUT_FILE}")
        start_idx = len(df_out)
    else:
        df_out = df.copy()
        df_out["pred_decision"] = ""
        df_out["pred_reasoning"] = ""
        df_out["pred_confidence"] = ""
        df_out["pred_json_valid"] = ""
        df_out["pred_latency_ms"] = ""

        start_idx = 0
        logger.info("Starting new pre-labeling session")
    
    total = len(df)
    already_done = (df_out["pred_decision"] != "").sum()
    remaining = total - already_done
    logger.info(f"Progress - Total: {total} | Done: {already_done} | Remaining: {remaining}")
    print(f"\nTotal: {total} | Done: {already_done} | Remaining: {remaining}\n")
    
    for idx in range(start_idx, total):
        row = df.iloc[idx]
        
        # Skip if already labeled
        if df_out.at[idx, "pred_decision"] != "":
            continue
        
        if (idx + 1) % 50 == 0:
            logger.info(f"Progress: {idx + 1}/{total}")
            print(f"Progress: {idx + 1}/{total}")
        
        logger.debug(f"Processing email {idx + 1}/{total}: {row.get('subject', 'N/A')[:60]}")
        
        # Get prediction
        result = get_model_prediction(
            label_source=row["label_source"],
            subject=row.get("subject", ""),
            clean_text=row.get("clean_text", "")
        )
        
        pred_decision = result.get("decision", "IGNORE")
        
        # Validate against allowed labels
        if pred_decision not in LEVEL2_LABELS:
            logger.warning(f"Invalid decision '{pred_decision}' at index {idx}, defaulting to 'IGNORE'")
            pred_decision = "IGNORE"
        
        # Store predictions
        df_out.at[idx, "pred_decision"] = pred_decision
        df_out.at[idx, "pred_reasoning"] = result.get("reasoning", "")
        df_out.at[idx, "pred_confidence"] = str(result.get("confidence", 0))
        df_out.at[idx, "pred_json_valid"] = str(result.get("json_valid", False))
        df_out.at[idx, "pred_latency_ms"] = str(result.get("latency_ms", 0))
        
        logger.debug(f"Stored - Decision: {pred_decision}, Valid: {result.get('json_valid')}, Latency: {result.get('latency_ms')}ms")
        
        # Save every 10 items
        if (idx + 1) % 10 == 0:
            df_out.to_csv(OUTPUT_FILE, index=False)
            logger.debug(f"Checkpoint saved at index {idx + 1}")
    
    # Final save
    df_out.to_csv(OUTPUT_FILE, index=False)
    logger.info(f"Final output saved: {OUTPUT_FILE}")
    
    # Compute stats
    json_valid_count = (df_out['pred_json_valid'] == 'True').sum()
    avg_latency = df_out['pred_latency_ms'].astype(int).mean()
    
    print("\n" + "="*80)
    print(f"Pre-labeling complete. Output: {OUTPUT_FILE}")
    
    print("\n--- PREDICTION DISTRIBUTION ---")
    print("\nDecision distribution:")
    print(df_out["pred_decision"].value_counts())
    print("\nSource distribution:")
    print(df_out["label_source"].value_counts())
    
    print(f"\nJSON valid: {json_valid_count}/{total}")
    print(f"Avg latency: {avg_latency:.0f}ms")
    
    # Log summary statistics
    logger.info("\n" + "="*80)
    logger.info("Pre-labeling Complete - Summary Statistics")
    logger.info("="*80)
    logger.info(f"\nDecision Distribution:\n{df_out['pred_decision'].value_counts().to_string()}")
    logger.info(f"\nSource Distribution:\n{df_out['label_source'].value_counts().to_string()}")
    logger.info(f"\nJSON Valid: {json_valid_count}/{total} ({json_valid_count/total*100:.1f}%)")
    logger.info(f"Average Latency: {avg_latency:.0f}ms")
    logger.info(f"Output saved: {OUTPUT_FILE}")
    logger.info("Phase 1 complete! [5-Class Schema: SUBMIT, EXAM, OPPORTUNITY, ADMIN, IGNORE]")

if __name__ == "__main__":
    main()
