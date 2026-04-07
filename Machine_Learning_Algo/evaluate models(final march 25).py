import os
import sys
import json
import time
import re
import logging
import requests
import pandas as pd
from datetime import datetime

# Force UTF-8 encoding for console output (fixes Windows emoji/unicode issues)
if sys.stdout.encoding != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    classification_report,
    confusion_matrix,
)

# For menu interaction
from typing import List

# ----------------------------------------------------------
# Logging setup
# ----------------------------------------------------------
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s | %(levelname)-8s | %(message)s',
    handlers=[
        logging.FileHandler('evaluation_inference.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

GROUND_TRUTH_FILE = "ground_truth_final.csv"
OUTPUT_BASE_DIR = "evaluation_results"

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

# The five models you are evaluating
MODELS = [
    "mistral:7b-instruct-q4_k_m",
    "qwen2.5:7b-instruct-q4_k_m",
    "gemma:7b-instruct-q4_k_m",
    "gpt-oss:120b-cloud",
    "gemini-3-flash-preview:latest",
]

# Small, controlled experiment matrix.
EXPERIMENT_CONFIGS = [
    {"name": "short_raw_nosource_single", "prompt": "short", "input": "raw", "source": False, "staged": False},
    {"name": "short_compact_nosource_single", "prompt": "short", "input": "compact", "source": False, "staged": False},
    {"name": "short_compact_nosource_staged", "prompt": "short", "input": "compact", "source": False, "staged": True},
    {"name": "short_compact_source_staged", "prompt": "short", "input": "compact", "source": True, "staged": True},
]

LEVEL2_LABELS = [
    "SUBMIT",
    "EXAM",
    "OPPORTUNITY",
    "ADMIN",
    "IGNORE",
]

SHORT_CLASSIFICATION_PROMPT = """
INPUT_FACTS: <paste Stage1 JSON>
INTENT_VIEW: <subject and first ~20 lines de-identified>

Choose exactly one label from [SUBMIT, EXAM, OPPORTUNITY, ADMIN, IGNORE].
Return ONLY JSON:
{"decision":"<LABEL>","confidence":<0-100>,"rationale":"<one short sentence with label keywords only>"}

Rules:
- Do not hallucinate dates, names, or attachments.
- Rationale must contain 1–3 keywords that justify the label (e.g., "due date; upload; assignment").
- If ambiguous, set confidence <= 60.

Examples (one line each):
  SUBMIT -> "Assignment due; upload link"
  EXAM -> "Exam schedule; practical/viva"
  ADMIN -> "Registration; mandatory; fee"
  OPPORTUNITY -> "Internship; workshop; optional"
  IGNORE -> "newsletter; advertisement"

Disambiguation:
- SUBMIT vs ADMIN: label SUBMIT only if is_submission==True AND text contains submit|upload|assignment|report|project OR has deadline. Otherwise ADMIN if mandatory|registration|fee|policy present.
- OPPORTUNITY vs IGNORE: OPPORTUNITY requires actionable optional offer (apply/register/attend). Pure newsletters/ads -> IGNORE.
- EXAM: any mention of exam/quiz/practical/viva/supplementary -> EXAM.

Return valid JSON only.
"""

LONG_CLASSIFICATION_PROMPT = f"""
INPUT: Full email text

Choose exactly one label from [SUBMIT, EXAM, OPPORTUNITY, ADMIN, IGNORE].
Return ONLY JSON:
{{"decision":"<LABEL>","confidence":<0-100>,"rationale":"<one short sentence with label keywords only>"}}

Definitions:
- SUBMIT: student must create and submit academic work (assignment, project, report, practical)
- EXAM: test, quiz, evaluation, exam, practical, viva
- OPPORTUNITY: optional career or learning activity (internship, workshop, hackathon)
- ADMIN: mandatory institutional process (registration, fees, attendance, enrollment)
- IGNORE: no meaningful academic action (newsletter, advertisement, spam)

Disambiguation Rules:
- SUBMIT vs ADMIN: label SUBMIT only if actual work submission (assignment/project/report/upload/due date). Otherwise ADMIN if mandatory|registration|fee|policy.
- OPPORTUNITY vs IGNORE: OPPORTUNITY requires actionable optional offer. Pure newsletters/ads -> IGNORE.
- EXAM: any mention of exam/quiz/practical/viva/supplementary -> EXAM.

Rules:
- Do not hallucinate dates, names, or attachments.
- Rationale: 1-3 keywords justifying the label (e.g., "Assignment; due date; upload").
- If ambiguous, set confidence <= 60.

Allowed labels: {LEVEL2_LABELS}

Return valid JSON only.
"""

EXTRACTION_PROMPT = """
Return ONLY this JSON about the email intent view:
{"action_required": true/false, "has_deadline": true/false, "deadline_text": "<YYYY-MM-DD or empty>", "is_exam": true/false, "is_submission": true/false, "is_mandatory": true/false, "is_opportunity": true/false}
Return valid JSON only. Do not explain, do not include any other text.
"""


def build_intent_view(subject, clean_text):
     """Compress noisy email content into an intent-first representation."""
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

# ----------------------------------------------------------
# JSON extraction utility
# ----------------------------------------------------------

def extract_json(text):
    """
    Robustly extract JSON from text that may contain surrounding content.
    Handles cases where LLM outputs text like "Sure! Here's the result:" followed by JSON.
    """
    try:
        # Try direct parse first (for clean JSON output)
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Extract JSON block using regex (handles markdown code blocks, surrounding text)
    match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    return None


def call_llm(model_name, prompt, timeout=90):
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
    latency_ms = round((time.time() - start) * 1000)
    raw = response.json().get("response", "").strip()
    parsed = extract_json(raw)
    return parsed, raw, latency_ms

# ----------------------------------------------------------
# Single email inference
# ----------------------------------------------------------

def run_inference(model_name, label_source, subject, clean_text, config):
    use_compact = config.get("input") == "compact"
    use_source = bool(config.get("source", False))
    use_staged = bool(config.get("staged", False))
    use_short_prompt = config.get("prompt", "short") == "short"

    intent_view = build_intent_view(subject, clean_text) if use_compact else (
        f"SUBJECT:\n{subject}\n\nEMAIL CONTENT:\n{clean_text}"
    )

    source_block = f"SOURCE TRUST LEVEL: {label_source}\n\n" if use_source else ""

    try:
        total_latency = 0
        facts = {}

        if use_staged:
            extraction_prompt = EXTRACTION_PROMPT + "\n\n" + source_block + intent_view
            parsed_facts, raw_facts, lat1 = call_llm(model_name, extraction_prompt, timeout=90)
            total_latency += lat1
            logger.info(f"[{model_name}] Stage1 raw output:\n{raw_facts}")

            if parsed_facts is None:
                logger.warning(f"[{model_name}] Stage1 JSON extraction failed; using empty facts")
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

            classifier_prompt = (
                (SHORT_CLASSIFICATION_PROMPT if use_short_prompt else LONG_CLASSIFICATION_PROMPT)
                + "\n\nINPUT FACTS JSON:\n"
                + json.dumps(facts, ensure_ascii=True)
                + "\n\n"
                + source_block
                + "INTENT VIEW:\n"
                + intent_view
            )
        else:
            classifier_prompt = (
                (SHORT_CLASSIFICATION_PROMPT if use_short_prompt else LONG_CLASSIFICATION_PROMPT)
                + "\n\n"
                + source_block
                + intent_view
            )

        parsed, raw, lat2 = call_llm(model_name, classifier_prompt, timeout=90)
        total_latency += lat2

        logger.info(f"[{model_name}] Stage2 raw output:\n{raw}")
        print(f"\n    >> Model Output: {raw[:150]}..." if len(raw) > 150 else f"\n    >> Model Output: {raw}")

        if parsed is None:
            logger.warning(f"[{model_name}] Failed to extract valid JSON from:\n{raw}")
            print(f"    [ERROR] JSON Extraction FAILED")
            print(f"    [--] Using default: IGNORE")
            return {
                "pred_decision": "IGNORE",
                "confidence": 0.0,
                "reasoning": "JSON extraction failed",
                "latency_ms": total_latency,
                "json_valid": False
            }

        decision = parsed.get("decision", "")
        confidence = parsed.get("confidence", 0.0)
        reasoning = parsed.get("reasoning", "")
        
        # Log extracted values
        logger.info(f"[{model_name}] Extracted - Decision: {decision}, Confidence: {confidence}, Reasoning: {reasoning[:50]}...")
        print(f"    [OK] Extracted Decision: {decision}")
        print(f"    [--] Confidence: {confidence}, Reasoning: {reasoning}")

        # Validate against allowed labels
        if decision not in LEVEL2_LABELS:
            logger.warning(f"[{model_name}] Invalid decision '{decision}', defaulting to 'IGNORE'")
            print(f"    [WARN] Invalid decision, using default")
            decision = "IGNORE"

        logger.info(f"[{model_name}] Success - Decision: {decision}, Latency: {total_latency}ms, JSON Valid: True")
        return {
            "pred_decision": decision,
            "confidence": confidence,
            "reasoning": reasoning,
            "latency_ms": total_latency,
            "json_valid": True,
        }

    except Exception as e:
        logger.error(f"[{model_name}] Inference failed: {str(e)}", exc_info=False)
        print(f"    [ERROR] {str(e)}")
        return {
            "pred_decision": "IGNORE",
            "confidence": 0.0,
            "reasoning": "Inference error",
            "latency_ms": 0,
            "json_valid": False,
        }


# ----------------------------------------------------------
# Evaluate one model against ground truth
# ----------------------------------------------------------

def evaluate_model(model_name, df, output_dir, config):
    logger.info(f"\n{'='*60}")
    logger.info(f"Starting evaluation: {model_name}")
    logger.info(f"{'='*60}")

    results = []

    for idx, row in df.iterrows():
        subject = row.get('subject','')[:50]
        print(f"  [{idx+1:3d}/{len(df)}] {subject:50s} ", end="", flush=True)
        logger.debug(f"Processing email {idx+1}/{len(df)}: {row.get('subject', 'N/A')[:60]}")

        res = run_inference(
            model_name=model_name,
            label_source=row["label_source"],
            subject=row.get("subject", ""),
            clean_text=row.get("clean_text", ""),
            config=config,
        )
        results.append(res)
        print("[OK]")

    print(f"\n  [OK] Inference complete for all {len(df)} emails.")
    logger.info(f"Inference complete for {model_name}. Processed {len(df)} emails.")

    # Build results dataframe
    res_df = df.copy()
    res_df["pred_decision"]  = [r["pred_decision"]  for r in results]
    res_df["pred_confidence"] = [r["confidence"]    for r in results]
    res_df["pred_reasoning"] = [r["reasoning"]     for r in results]
    res_df["latency_ms"]     = [r["latency_ms"]    for r in results]
    res_df["json_valid"]     = [r["json_valid"]    for r in results]

    # ----------------------------------------------------------
    # Metrics — Decision Classification
    # ----------------------------------------------------------
    y_true_decision = res_df["gt_decision"].tolist()
    y_pred_decision = res_df["pred_decision"].tolist()

    decision_accuracy  = accuracy_score(y_true_decision, y_pred_decision)
    decision_f1_macro  = f1_score(y_true_decision, y_pred_decision, average="macro", zero_division=0)
    decision_f1_weighted = f1_score(y_true_decision, y_pred_decision, average="weighted", zero_division=0)
    decision_precision = precision_score(y_true_decision, y_pred_decision, average="macro", zero_division=0)
    decision_recall    = recall_score(y_true_decision, y_pred_decision, average="macro", zero_division=0)

    # ----------------------------------------------------------
    # JSON + Latency
    # ----------------------------------------------------------
    json_success_rate = res_df["json_valid"].sum() / len(res_df) * 100
    avg_latency_ms    = res_df["latency_ms"].mean()

    # ----------------------------------------------------------
    # Print summary
    # ----------------------------------------------------------
    print(f"\n  --- Decision Classification Metrics ---")
    print(f"  [>] Accuracy (macro)     : {decision_accuracy:.4f}")
    print(f"  [>] F1-Score (macro)     : {decision_f1_macro:.4f}")
    print(f"  [>] F1-Score (weighted)  : {decision_f1_weighted:.4f}")
    print(f"  [>] Precision (macro)    : {decision_precision:.4f}")
    print(f"  [>] Recall (macro)       : {decision_recall:.4f}")

    print(f"\n  --- Reliability Metrics ---")
    print(f"  [OK] JSON Success Rate    : {json_success_rate:.1f}%")
    print(f"  [--] Avg Latency         : {avg_latency_ms:.0f} ms")
    
    # Log summary metrics
    logger.info(f"\n--- {model_name} FINAL METRICS ---")
    logger.info(f"Decision Accuracy: {decision_accuracy:.4f}")
    logger.info(f"Decision F1 (macro): {decision_f1_macro:.4f}")
    logger.info(f"Decision F1 (weighted): {decision_f1_weighted:.4f}")
    logger.info(f"Decision Precision: {decision_precision:.4f}")
    logger.info(f"Decision Recall: {decision_recall:.4f}")
    logger.info(f"JSON Success: {json_success_rate:.1f}%")
    logger.info(f"Avg Latency: {avg_latency_ms:.0f} ms")

    # ----------------------------------------------------------
    # Per-class reports
    # ----------------------------------------------------------
    decision_report = classification_report(y_true_decision, y_pred_decision, zero_division=0)

    # ----------------------------------------------------------
    # Confusion matrices
    # ----------------------------------------------------------
    decision_classes = sorted(set(y_true_decision + y_pred_decision))
    decision_cm = confusion_matrix(y_true_decision, y_pred_decision, labels=decision_classes)
    decision_cm_df = pd.DataFrame(decision_cm, index=decision_classes, columns=decision_classes)

    # ----------------------------------------------------------
    # Save per-model outputs
    # ----------------------------------------------------------
    safe_name = model_name.replace(":", "_").replace("/", "_")
    model_dir = os.path.join(output_dir, safe_name)
    os.makedirs(model_dir, exist_ok=True)

    config_name = config.get("name", "default")
    res_df.to_csv(os.path.join(model_dir, f"predictions__{config_name}.csv"), index=False)
    decision_cm_df.to_csv(os.path.join(model_dir, f"confusion_matrix_decision__{config_name}.csv"))

    with open(os.path.join(model_dir, f"classification_report_decision__{config_name}.txt"), "w") as f:
        f.write(decision_report)
    
    logger.info(f"Results saved to: {model_dir}")
    print(f"\n  [OK] Results saved to: {model_dir}")

    # Return summary metrics dict
    return {
        "model": model_name,
        "config": config.get("name", "default"),
        "decision_accuracy":        round(decision_accuracy, 4),
        "decision_f1_macro":        round(decision_f1_macro, 4),
        "decision_f1_weighted":     round(decision_f1_weighted, 4),
        "decision_precision_macro": round(decision_precision, 4),
        "decision_recall_macro":    round(decision_recall, 4),
        "json_success_pct":         round(json_success_rate, 1),
        "avg_latency_ms":           round(avg_latency_ms, 1),
    }

# ----------------------------------------------------------
# Menu utility functions
# ----------------------------------------------------------

def display_menu(available_models: List[str]) -> int:
    """Display menu and get user choice."""
    print(f"\n{'='*60}")
    print("MODEL EVALUATION MENU")
    print(f"{'='*60}")
    print(f"\nAvailable models ({len(available_models)}):\n")
    
    for i, model in enumerate(available_models, 1):
        print(f"  [{i}] {model}")
    
    print(f"  [0] Exit")
    print(f"\n{'-'*60}")
    
    while True:
        try:
            choice = int(input("Select model to evaluate (enter number): "))
            if 0 <= choice <= len(available_models):
                return choice
            else:
                print(f"Invalid choice. Please enter 0-{len(available_models)}")
        except ValueError:
            print("Invalid input. Please enter a number.")

def confirm_continue() -> bool:
    """Ask user if they want to continue."""
    while True:
        response = input("\nEvaluate another model? (y/n): ").strip().lower()
        if response in ['y', 'yes']:
            return True
        elif response in ['n', 'no']:
            return False
        else:
            print("Please enter 'y' or 'n'")

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------

def main():
    logger.info("="*60)
    logger.info("Starting Model Evaluation Pipeline")
    logger.info("="*60)
    print(f"\n{'='*60}")
    print("MODEL EVALUATION PIPELINE (INTERACTIVE)")
    print(f"{'='*60}")
    
    df = pd.read_csv(GROUND_TRUTH_FILE, dtype=str, keep_default_na=False)
    logger.info(f"Loaded ground truth: {len(df)} emails")
    print(f"\n[OK] Loaded ground truth: {len(df)} emails")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(OUTPUT_BASE_DIR, f"run_{timestamp}")
    os.makedirs(output_dir, exist_ok=True)
    logger.info(f"Output directory: {output_dir}")
    print(f"[OK] Output directory: {output_dir}")

    available_models = list(MODELS)
    all_metrics = []

    while available_models:
        choice = display_menu(available_models)
        
        if choice == 0:
            print(f"\nExiting evaluation...")
            break
        
        selected_model = available_models[choice - 1]
        logger.info(f"\nEvaluating model: {selected_model}")
        print(f"\n{'='*60}")
        print(f"Evaluating: {selected_model}")
        print(f"{'='*60}")
        
        print("\nRun mode:")
        print("  [1] Baseline config only (short_raw_nosource_single)")
        print("  [2] Full experiment matrix")
        mode = input("Choose run mode (1/2): ").strip()

        configs_to_run = [EXPERIMENT_CONFIGS[0]] if mode != "2" else EXPERIMENT_CONFIGS

        for cfg in configs_to_run:
            logger.info(f"Running config: {cfg['name']}")
            print(f"\n--- Config: {cfg['name']} ---")
            metrics = evaluate_model(selected_model, df, output_dir, cfg)
            all_metrics.append(metrics)
        
        # Remove evaluated model from list
        available_models.pop(choice - 1)
        logger.info(f"Model {selected_model} evaluation complete")
        print(f"\n[OK] Model evaluation complete!")
        
        if available_models:
            if not confirm_continue():
                break
        else:
            print(f"\n[OK] All models have been evaluated!")
            break

    # ----------------------------------------------------------
    # Summary comparison table (if any models were evaluated)
    # ----------------------------------------------------------
    if all_metrics:
        summary_df = pd.DataFrame(all_metrics)
        summary_path = os.path.join(output_dir, "summary_results.csv")
        summary_df.to_csv(summary_path, index=False)

        print(f"\n{'='*60}")
        print("FINAL COMPARISON TABLE (Evaluated Models)")
        print(f"{'='*60}")
        print(summary_df.sort_values(["model", "decision_f1_macro"], ascending=[True, False]).to_string(index=False))
        print(f"\n[OK] All results saved to: {output_dir}")
        
        logger.info(f"\n{'='*60}")
        logger.info("FINAL COMPARISON TABLE")
        logger.info(f"{'='*60}")
        logger.info(f"\n{summary_df.to_string(index=False)}")
        logger.info(f"\nAll results saved to: {output_dir}")
    else:
        print(f"\n[WARN] No models were evaluated.")
    
    logger.info("Evaluation pipeline complete!")

if __name__ == "__main__":
    main()