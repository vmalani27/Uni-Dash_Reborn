
import os
import pandas as pd
from collections import defaultdict
from datetime import datetime
import requests
# ----------------------------------------------------------
# Helpers
# ----------------------------------------------------------

def llm_label_suggestion(label_source, clean_text):
    """
    Calls Ollama (localhost:11434, model 'gemma3') to get a topic label suggestion.
    Returns (label, reason) or (None, None) on failure.
    """
    prompt = f"""You are assisting with academic email labeling.

Context:
Each email already has a known SOURCE (who sent it).
Your task is to help decide the TOPIC (what the email is about).

You MUST choose exactly ONE topic label from the list below.
You are NOT allowed to invent new labels or merge labels.
If none fit perfectly, choose the closest one.

Allowed Topic Labels:
1. Timetable / Schedule Update
2. Exam Notifications
3. Assignment or Submission
4. Certification / Courses
5. Internship / Placement Opportunities
6. Events / Hackathons
7. Important Announcements
8. Administrative / Fees / Counselling
9. General Information / Misc

Guidelines:
- Topic is based on INTENT, not sender.
- Source is provided only as context, not as a rule.
- If the email requires student action or compliance, prefer \"Important Announcements\".
- If the email is promotional or optional with no academic consequence, prefer \"General Information / Misc\".
- Do NOT assume new categories like \"International Opportunities\".
- Do NOT explain platform features or invent abstractions.

Input:
SOURCE: {label_source}
EMAIL CONTENT:
{clean_text}

Output format (strict):
Chosen label: <one label from the list>
Reason (1–2 lines max): <brief justification based on student action and urgency>"""
    try:
        response = requests.post(
            "http://127.0.0.1:11434/api/generate",
            json={
                "model": "llama3",
                "prompt": prompt,
                "stream": False
            },
            timeout=30
        )
        response.raise_for_status()
        result = response.json()
        output = result.get("response", "")
        # Parse output
        label = None
        reason = None
        for line in output.splitlines():
            if line.lower().startswith("chosen label:"):
                label = line.split(":", 1)[-1].strip()
            if line.lower().startswith("reason"):
                reason = line.split(":", 1)[-1].strip()
        return label, reason
    except Exception as e:
        print(f"[LLM ERROR] {e}")
        return None, None

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = r"level2_annotation_runs\run_20251230_235118\level2_labeled.csv"
BASE_OUTPUT_DIR = "level2_annotation_runs"
MAX_PREVIEW_CHARS = 500

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

TOPIC_KEYWORDS = {
    "Timetable / Schedule Update": ["timetable", "schedule", "rescheduled"],
    "Exam Notifications": ["exam", "midsem", "endsem", "hall ticket", "seating"],
    "Assignment or Submission": ["submit", "submission", "assignment", "project", "sgp"],
    "Certification / Courses": ["nptel", "coursera", "aws", "cisco", "certification"],
    "Internship / Placement Opportunities": ["internship", "placement", "job", "apply"],
    "Events / Hackathons": ["event", "workshop", "seminar", "hackathon"],
    "Important Announcements": ["important", "urgent", "mandatory", "last date"],
    "Administrative / Fees / Counselling": ["fees", "hostel", "counselling", "refund"],
}

LEVEL1_BIAS = {
    "Administration / Office": {
        "Administrative / Fees / Counselling": 0.5,
        "Exam Notifications": 0.3,
    },
    "Student / Club": {
        "Events / Hackathons": 0.4,
    },
    "External Course Provider": {
        "Certification / Courses": 0.6,
    },
}

# ----------------------------------------------------------
# Helpers
# ----------------------------------------------------------

def infer_level2_topic(text, source):
    text = (text or "").lower()
    scores = defaultdict(float)

    for topic, kws in TOPIC_KEYWORDS.items():
        for kw in kws:
            if kw in text:
                scores[topic] += 1.0

    for topic, bias in LEVEL1_BIAS.get(source, {}).items():
        scores[topic] += bias

    if not scores or max(scores.values()) == 0:
        return "General Information / Misc"

    return max(scores, key=scores.get)


def choose_label():
    print("\nChoose correct label:")
    for i, lab in enumerate(LEVEL2_LABELS, start=1):
        print(f"{i}. {lab}")
    while True:
        choice = input("Enter number or exact label: ").strip()
        if choice.isdigit():
            idx = int(choice)
            if 1 <= idx <= len(LEVEL2_LABELS):
                return LEVEL2_LABELS[idx - 1]
        elif choice in LEVEL2_LABELS:
            return choice
        print("Invalid choice. Retry.")


def write_readme(output_dir, df):
    total = len(df)
    labeled = df["label_topic"].astype(bool).sum()
    remaining = total - labeled

    readme_path = os.path.join(output_dir, "README.txt")
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write("Level-2 Semi-Assisted Labeling Run\n\n")
        f.write(f"Timestamp folder: {output_dir}\n")
        f.write(f"Total rows: {total}\n")
        f.write(f"Labeled rows: {labeled}\n")
        f.write(f"Remaining unlabeled rows: {remaining}\n")

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------

def main():
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

    if "label_topic" not in df.columns:
        df["label_topic"] = ""

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(BASE_OUTPUT_DIR, f"run_{timestamp}")
    os.makedirs(output_dir, exist_ok=True)

    output_csv = os.path.join(output_dir, "level2_labeled.csv")


    for idx, row in df.iterrows():
        if df.at[idx, "label_topic"].strip():
            continue

        suggestion = infer_level2_topic(
            row.get("clean_text", ""),
            row.get("label_source", "")
        )

        # LLM suggestion
        llm_label, llm_reason = llm_label_suggestion(row.get("label_source", ""), row.get("clean_text", ""))

        print("\n--------------------------------------------------")
        print(f"Row index: {idx}")
        print(f"Source: {row.get('label_source')}")
        print(f"Rule-based suggestion: {suggestion}")
        if llm_label:
            print(f"LLM suggestion: {llm_label}")
            if llm_reason:
                print(f"LLM reason: {llm_reason}")
        print("\nEmail preview:\n")
        print(row.get("clean_text", "")[:MAX_PREVIEW_CHARS])

        ans = input("\nAccept suggestion? [Enter/y = yes | n = change | l = LLM | s = skip | q = quit]: ").strip().lower()

        if ans == "q":
            break
        elif ans == "s":
            continue
        elif ans == "l" and llm_label:
            df.at[idx, "label_topic"] = llm_label
            print("LLM label accepted")
        elif ans in ["", "y"]:
            df.at[idx, "label_topic"] = suggestion
            print("Rule-based label accepted")
        else:
            new_label = choose_label()
            df.at[idx, "label_topic"] = new_label
            print("Updated")

        df.to_csv(output_csv, index=False, encoding="utf-8")
        write_readme(output_dir, df)

    df.to_csv(output_csv, index=False, encoding="utf-8")
    write_readme(output_dir, df)

    print("\nSession ended.")
    print(f"Output saved in: {output_dir}")

if __name__ == "__main__":
    main()
