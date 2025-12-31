import os
import pandas as pd
from collections import defaultdict
from datetime import datetime

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = "../output_20251230_134415/semi_assisted_labelling.csv"
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

        print("\n--------------------------------------------------")
        print(f"Row index: {idx}")
        print(f"Source: {row.get('label_source')}")
        print(f"Suggested label_topic: {suggestion}")
        print("\nEmail preview:\n")
        print(row.get("clean_text", "")[:MAX_PREVIEW_CHARS])

        ans = input("\nAccept suggestion? [Enter/y = yes | n = change | s = skip | q = quit]: ").strip().lower()

        if ans == "q":
            break
        elif ans == "s":
            continue
        elif ans in ["", "y"]:
            df.at[idx, "label_topic"] = suggestion
            print("Accepted")
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
