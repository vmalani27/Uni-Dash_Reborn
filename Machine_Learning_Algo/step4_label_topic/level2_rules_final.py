import os
import json
import pandas as pd
import requests
from datetime import datetime

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = "llm_eval_subset_v1.csv"   # output of Level-1
OUTPUT_BASE_DIR = "level2_llm_runs"

MODEL_NAME = "qwen2.5:7b-instruct-q4_k_m"
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

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

# ----------------------------------------------------------
# System Prompt (CORE INTELLIGENCE)
# ----------------------------------------------------------

SYSTEM_PROMPT = f"""
You are an academic email assistant for a university student.

You will receive:
- SOURCE TRUST LEVEL (who sent the email)
- EMAIL SUBJECT
- EMAIL BODY

Important rules:
- Emails may be forwarded by faculty on behalf of administrative offices.
- Do NOT infer authority based only on sender.
- Decide topic and urgency from language, enforcement cues, deadlines, and tone.
- Output must be strictly valid JSON.
- Do NOT add explanations outside JSON.

Allowed topic labels:
{LEVEL2_LABELS}

Urgency definitions:
- Critical: deadline today or tomorrow; penalties if missed
- High: deadline within a few days; important action required
- Medium: relevant academic info, no immediate deadline
- Low: optional events or learning opportunities
- None: newsletters, promotions, routine info

Return JSON in this exact format:
{{
  "summary": "<one-line student-facing summary>",
  "label_topic": "<one of the allowed topic labels>",
  "label_urgency": "<one of the urgency labels>"
}}
"""

# ----------------------------------------------------------
# LLM Call
# ----------------------------------------------------------

def classify_email(label_source, subject, clean_text):
    prompt = f"""
SOURCE TRUST LEVEL: {label_source}
SUBJECT: {subject}

EMAIL CONTENT:
{clean_text}
"""

    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL_NAME,
            "prompt": SYSTEM_PROMPT + "\n" + prompt,
            "stream": False,
            "options": {
                "temperature": 0,
                "top_p": 0.1
            }
        },
        timeout=60
    )

    response.raise_for_status()
    raw_output = response.json().get("response", "").strip()

    try:
        parsed = json.loads(raw_output)
        return parsed
    except json.JSONDecodeError:
        return {
            "summary": "",
            "label_topic": "General Information / Misc",
            "label_urgency": "None"
        }

# ----------------------------------------------------------
# Main Pipeline
# ----------------------------------------------------------

def main():
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

    df["summary"] = ""
    df["label_topic"] = ""
    df["label_urgency"] = ""

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(OUTPUT_BASE_DIR, f"run_{timestamp}")
    os.makedirs(output_dir, exist_ok=True)

    output_file = os.path.join(output_dir, "level2_labeled.csv")

    for idx, row in df.iterrows():
        result = classify_email(
            label_source=row["label_source"],
            subject=row.get("subject", ""),
            clean_text=row.get("clean_text", "")
        )

        df.at[idx, "summary"] = result.get("summary", "")
        df.at[idx, "label_topic"] = result.get("label_topic", "")
        df.at[idx, "label_urgency"] = result.get("label_urgency", "")

        if idx % 50 == 0:
            print(f"Processed {idx} emails")

    df.to_csv(output_file, index=False, encoding="utf-8")
    print(f"\nSaved output to: {output_file}")

if __name__ == "__main__":
    main()
