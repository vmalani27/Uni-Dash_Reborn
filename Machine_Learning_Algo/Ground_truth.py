import os
import json
import pandas as pd
import requests
from datetime import datetime
import time

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = "llm_eval_subset_v1.csv"
OUTPUT_FILE = "evaluation_dataset_ground_truth.csv"

MODEL_NAME = "qwen2.5:7b-instruct-q4_k_m"
OLLAMA_URL = "http://192.168.31.2:11434/api/generate"

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
# System Prompt
# ----------------------------------------------------------

SYSTEM_PROMPT = f"""
You are an academic email assistant for a university student.

You will receive:
- SOURCE TRUST LEVEL
- EMAIL SUBJECT
- EMAIL BODY

Important rules:
- Do NOT infer authority based only on sender.
- Decide topic and urgency from language cues and deadlines.
- Output strictly valid JSON.

Allowed topic labels:
{LEVEL2_LABELS}

Urgency labels:
{URGENCY_LABELS}

Return JSON exactly as:
{{
  "summary": "<one-line student-facing summary>",
  "label_topic": "<one topic label>",
  "label_urgency": "<one urgency label>"
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

    start_time = time.time()

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

    latency = (time.time() - start_time) * 1000

    raw_output = response.json().get("response", "").strip()

    try:
        parsed = json.loads(raw_output)
        parsed["latency_ms"] = latency
        parsed["json_valid"] = True
        return parsed
    except json.JSONDecodeError:
        return {
            "summary": "",
            "label_topic": "General Information / Misc",
            "label_urgency": "None",
            "latency_ms": latency,
            "json_valid": False
        }

# ----------------------------------------------------------
# Semi-Assisted Ground Truth Builder
# ----------------------------------------------------------

def main():

    if os.path.exists(OUTPUT_FILE):
        df = pd.read_csv(OUTPUT_FILE)
        print("Resuming existing annotation session.")
    else:
        df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)
        df["model_topic"] = ""
        df["model_urgency"] = ""
        df["ground_truth_topic"] = ""
        df["ground_truth_urgency"] = ""
        df["summary"] = ""

    for idx, row in df.iterrows():

        if row.get("ground_truth_topic", "") != "":
            continue  # Skip already labeled rows

        print("\n" + "="*80)
        print(f"Email {idx+1}")
        print("SOURCE:", row["label_source"])
        print("SUBJECT:", row.get("subject", ""))
        print("BODY PREVIEW:\n", row.get("clean_text", "")[:500])

        # Run model
        result = classify_email(
            label_source=row["label_source"],
            subject=row.get("subject", ""),
            clean_text=row.get("clean_text", "")
        )

        model_topic = result["label_topic"]
        model_urgency = result["label_urgency"]

        print("\nModel Suggested Topic:", model_topic)
        print("Model Suggested Urgency:", model_urgency)

        print("\nAllowed Topics:")
        for t in LEVEL2_LABELS:
            print("-", t)

        topic_input = input("\nConfirm topic? (Enter=accept / type new label): ").strip()

        if topic_input == "":
            final_topic = model_topic
        else:
            final_topic = topic_input

        print("\nAllowed Urgency:")
        for u in URGENCY_LABELS:
            print("-", u)

        urgency_input = input("\nConfirm urgency? (Enter=accept / type new label): ").strip()

        if urgency_input == "":
            final_urgency = model_urgency
        else:
            final_urgency = urgency_input

        df.at[idx, "model_topic"] = model_topic
        df.at[idx, "model_urgency"] = model_urgency
        df.at[idx, "ground_truth_topic"] = final_topic
        df.at[idx, "ground_truth_urgency"] = final_urgency
        df.at[idx, "summary"] = result["summary"]

        df.to_csv(OUTPUT_FILE, index=False)
        print("Saved.\n")

    print("Ground truth labeling complete.")

if __name__ == "__main__":
    main()