import os
import pandas as pd
from datetime import datetime
import requests

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = r"D:\vanshmalanidata\Documents\GitHub\Uni-Dash_Reborn\Machine_Learning_Algo\output_20260103_222919\source_labeled_dataset.csv"
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

# ----------------------------------------------------------
# LLM Extraction Prompt
# ----------------------------------------------------------

def extract_obligation_markers(label_source, clean_text):
    """
    Calls Ollama (localhost:11434, model 'llama3') to extract obligation markers.
    Returns a dict with keys:
        has_required_action (bool)
        action_type (str)
        university_enforced (bool)
        consequence (str)
        exam_related (bool)
        schedule_changed (bool)
        optional_learning (bool)
        optional_participation (bool)
        deadline (str or None)
        academic_work_type (str)
    """
    prompt = f"""You are assisting with academic email topic extraction.\n\nContext:\nEach email has a known SOURCE (who sent it).\nYour task is to extract obligation markers, NOT to assign a topic label.\n\nAnswer ONLY the following questions, in the exact format below.\nDo NOT invent categories or labels.\n\nQuestions:\n1. Is there a required student action? (yes / no)\n2. What is the action verb? (pay / submit / attend / register / none)\n3. Is there a consequence if ignored? (yes / no / unclear)\n4. Is the action enforced by the university system? (yes / no)\n5. Is participation optional? (yes / no)\n6. Is there a deadline mentioned or implied? (text span or none)\n7. Is the action related to an exam process? (yes / no)\n8. Is there a change in schedule/date/time/location? (yes / no)\n9. Is this an optional learning opportunity? (yes / no)\n10. Is this an optional participation event? (yes / no)\n11. What is the academic work type? (ongoing_coursework / one_time_requirement / informational_context / optional_activity)\n\nInput:\nSOURCE: {label_source}\nEMAIL CONTENT:\n{clean_text}\n\nOutput format (strict):\n1. Required action: <yes/no>\n2. Action verb: <verb>\n3. Consequence: <yes/no/unclear>\n4. University enforced: <yes/no>\n5. Optional participation: <yes/no>\n6. Deadline: <text span/none>\n7. Exam related: <yes/no>\n8. Schedule changed: <yes/no>\n9. Optional learning: <yes/no>\n10. Optional participation event: <yes/no>\n11. Academic work type: <ongoing_coursework/one_time_requirement/informational_context/optional_activity>\n"""
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
        markers = {}
        for line in output.splitlines():
            if line.startswith("1. Required action:"):
                markers["has_required_action"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("2. Action verb:"):
                markers["action_type"] = line.split(":",1)[-1].strip().lower()
            elif line.startswith("3. Consequence:"):
                markers["consequence"] = line.split(":",1)[-1].strip().lower()
            elif line.startswith("4. University enforced:"):
                markers["university_enforced"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("5. Optional participation:"):
                markers["optional_participation"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("6. Deadline:"):
                markers["deadline"] = line.split(":",1)[-1].strip()
            elif line.startswith("7. Exam related:"):
                markers["exam_related"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("8. Schedule changed:"):
                markers["schedule_changed"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("9. Optional learning:"):
                markers["optional_learning"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("10. Optional participation event:"):
                markers["optional_participation_event"] = line.split(":",1)[-1].strip().lower() == "yes"
            elif line.startswith("11. Academic work type:"):
                markers["academic_work_type"] = line.split(":",1)[-1].strip().lower()
        return markers
    except Exception as e:
        print(f"[LLM ERROR] {e}")
        return {}

# ----------------------------------------------------------
# Deterministic Topic Decision
# ----------------------------------------------------------

def decide_topic(markers):
    # Institutional override: Faculty + submit/upload/prepare = Assignment or Submission
    label_source = markers.get("label_source", "").lower()
    action_type = markers.get("action_type", "")
    # Administrative override: all admin mails are university enforced
    is_admin = label_source in ["administration / office", "administration", "admin", "office"]
    university_enforced = markers.get("university_enforced") or is_admin
    if not markers.get("has_required_action"):
        return "General Information / Misc"
    # Faculty override
    if (
        label_source in ["faculty / academic staff", "faculty", "academic staff"]
        and action_type in ["submit", "upload", "prepare"]
    ):
        return "Assignment or Submission"
    if action_type == "submit":
        return "Assignment or Submission"
    if action_type in ["pay", "update", "verify"] and university_enforced:
        return "Administrative / Fees / Counselling"
    if action_type in ["appear", "register"] and markers.get("exam_related"):
        return "Exam Notifications"
    if markers.get("schedule_changed"):
        return "Timetable / Schedule Update"
    if markers.get("has_required_action") and university_enforced:
        return "Important Announcements"
    if markers.get("optional_learning"):
        return "Certification / Courses"
    if markers.get("optional_participation_event"):
        return "Events / Hackathons"
    return "General Information / Misc"

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

    # Group by label_source, cycle through sources for first 50 manual labels, then auto-label
    sources = df["label_source"].unique().tolist()
    source_indices = {src: df[(df["label_source"] == src) & (df["label_topic"].str.strip() == "")].index.tolist() for src in sources}
    manual_labelled = 0
    source_cycle = 0
    total_rows = len(df)
    labelled_rows = 0
    # Track which indices have been manually labelled
    manually_labelled_indices = set()
    # First, cycle through sources for first 50 manual labels
    while manual_labelled < 50 and sum(len(lst) for lst in source_indices.values()) > 0:
        src = sources[source_cycle % len(sources)]
        idx_list = source_indices[src]
        if idx_list:
            idx = idx_list.pop(0)
            row = df.loc[idx]
            print("\n--------------------------------------------------")
            print(f"Row index: {idx}")
            print(f"Source: {row.get('label_source')}")
            print("\nEmail preview:\n")
            print(row.get("clean_text", "")[:MAX_PREVIEW_CHARS])
            markers = extract_obligation_markers(row.get("label_source", ""), row.get("clean_text", ""))
            markers["label_source"] = row.get("label_source", "")
            topic = decide_topic(markers)
            print(f"\nExtracted markers: {markers}")
            print(f"Suggested topic: {topic}")
            ans = input("\nAccept suggestion? [Enter/y = yes | n = change | s = skip | q = quit]: ").strip().lower()
            if ans == "q":
                break
            elif ans == "s":
                continue
            elif ans in ["", "y"]:
                df.at[idx, "label_topic"] = topic
                print("Label accepted")
            else:
                print("Choose correct label:")
                for i, lab in enumerate(LEVEL2_LABELS, start=1):
                    print(f"{i}. {lab}")
                while True:
                    choice = input("Enter number or exact label: ").strip()
                    if choice.isdigit():
                        idx2 = int(choice)
                        if 1 <= idx2 <= len(LEVEL2_LABELS):
                            df.at[idx, "label_topic"] = LEVEL2_LABELS[idx2 - 1]
                            break
                    elif choice in LEVEL2_LABELS:
                        df.at[idx, "label_topic"] = choice
                        break
                    print("Invalid choice. Retry.")
                print("Updated")
            df.to_csv(output_csv, index=False, encoding="utf-8")
            manual_labelled += 1
            manually_labelled_indices.add(idx)
        source_cycle += 1
    # Now, auto-label the rest
    for idx, row in df.iterrows():
        if df.at[idx, "label_topic"].strip() or idx in manually_labelled_indices:
            continue
        markers = extract_obligation_markers(row.get("label_source", ""), row.get("clean_text", ""))
        markers["label_source"] = row.get("label_source", "")
        topic = decide_topic(markers)
        df.at[idx, "label_topic"] = topic
        if (labelled_rows + manual_labelled) % 100 == 0:
            print(f"Auto-labelled {labelled_rows + manual_labelled} / {total_rows}")
        df.to_csv(output_csv, index=False, encoding="utf-8")
        labelled_rows += 1
    df.to_csv(output_csv, index=False, encoding="utf-8")
    print("\nSession ended.")
    print(f"Output saved in: {output_dir}")

if __name__ == "__main__":
    main()
