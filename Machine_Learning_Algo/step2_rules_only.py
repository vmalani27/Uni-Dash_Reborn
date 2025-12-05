"""
RULE-ONLY EMAIL LABELING ENGINE (NO LLM)
----------------------------------------
CSV must contain:
    from, full_text, label
"""

import pandas as pd
import re
from html import unescape

# --------------------------------------------------------
# CONFIG
# --------------------------------------------------------

INPUT_FILE = "active_learning_batch.csv"
OUTPUT_FILE = "semi_labeled_dataset_rules_only.csv"

CATEGORIES = [
    "Assignment", "Test", "Exam", "Lecture",
    "Event", "Administrative", "Urgent", "Misc"
]

PREVIEW_CHARS = 300

# --------------------------------------------------------
# REGEX PATTERNS
# --------------------------------------------------------

PAT_ASSIGN = [
    r"\bassignment\b",
    r"\bassignments\b",
    r"\bhomework\b",
    r"\bsubmit\b",
    r"\bsubmission\b",
    r"\bsubmit by\b",
    r"\bdue\b",
    r"\bdue by\b",
    r"\bdeadline\b",
    r"\bturn in\b",
    r"\bupload\b"
]

PAT_TEST = [
    r"\bquiz\b",
    r"\bquizzes\b",
    r"\bviva\b",
    r"\bunit test\b",
    r"\bclass test\b",
    r"\binternal test\b",
]

PAT_EXAM = [
    r"\bexam\b",
    r"\bexamination\b",
    r"\bmid[- ]?sem\b",
    r"\bend[- ]?sem\b",
    r"\bms/es\b",
    r"\bseating plan\b",
    r"\bhall ticket\b",
    r"\bexam timetable\b",
    r"\btimetable\b",
    r"\bexam schedule\b",
    r"\bschedule\b",
]

PAT_LECTURE = [
    r"\bclass\b",
    r"\blecture\b",
    r"\brescheduled\b",
    r"\bcancelled\b",
    r"\bpresentation session\b",
    r"\bpractical session\b",
    r"\btheory class\b",
    r"\blab session\b",
    r"\bsyllabus\b",
    r"\bunit plan\b",
    r"\bweekly schedule\b",
    r"\bteaching plan\b",
    r"\bpractical list\b",
    r"\broom changed\b",
    r"\bclass updates?\b",
    r"\bclass cancellation\b",
    r"\bfaculty announcement\b",
    r"\bsemester plan\b",
    r"\blecture notes?\b",
    r"\bclass schedule\b",
    r"\blab schedule\b",
    r"\bunit test schedule\b",
    r"\bsubject plan\b",
    r"\bsubject outline\b"
]

PAT_URGENT = [
    r"\burgent\b",
    r"\bimmediate action\b",
    r"\blast date\b",
    r"\btoday only\b",
    r"\bimportant update\b",
]

PAT_PROGRAM = [
    r"\bacademy\b",
    r"\bbatch\b",
    r"\bprogram\b",
    r"\bcertificate\b",
    r"\bcertification\b",
    r"\benroll\b",
    r"\benrollment\b",
    r"\bjoining\b",
    r"\bworkshop series\b",
    r"\bseries\b"
]

PAT_NEWS = [
    r"\bunsubscribe\b",
    r"\bnewsletter\b",
    r"\bpromo\b",
    r"\bpricing\b",
    r"\boffer\b",
    r"\bsale\b",
    r"\bbilling\b",
    r"\bdiscount\b",
]

PAT_EVENT = [
    r"\bctf\b",
    r"\bcapture the flag\b",
    r"\bhackathon\b",
    r"\bworkshop\b",
    r"\bwebinar\b",
    r"\bseminar\b",
    r"\bcompetition\b",
    r"\bchallenge\b",
    r"\bguest lecture\b",
    r"\btech talk\b",
    r"\bboot ?camp\b",
    r"\bhands[- ]on\b",
    r"\btraining\b",
    r"\bcoding contest\b",
    r"\bhack ?day\b",
]

AD_DOMAINS = ["pinterest.com", "read.ai", "mailchimp.com", "sendgrid.net"]
TRUSTED_PROGRAM_SENDERS = ["nptel.iitm.ac.in", "coursera.org"]
CLASSROOM_KEYS = ["classroom.google.com", "no-reply@classroom"]
PAT_COURSE_DOC = [
    r"\bsyllabus\b",
    r"\bpfa\b",
    r"\bpractical list\b",
    r"\bpractical\b",
    r"\bmaterials\b",
    r"\bdocs?\b",
    r"\bread the attached\b"
]

# --------------------------------------------------------
# HELPERS
# --------------------------------------------------------

def extract_domain(sender):
    if not isinstance(sender, str):
        return ""
    m = re.search(r"@([^ >]+)", sender)
    return m.group(1).lower() if m else ""

def regex_match(text, patterns):
    if not isinstance(text, str):
        return False
    t = text.lower()
    return any(re.search(p, t) for p in patterns)

def clean(s):
    if not isinstance(s, str):
        return ""
    s = unescape(s)
    return re.sub(r"\s+", " ", s).strip()

def preview(text):
    if not isinstance(text, str):
        return ""
    t = text.replace("\n", " ")
    return t[:PREVIEW_CHARS] + (" ...[truncated]" if len(t) > PREVIEW_CHARS else "")

# --------------------------------------------------------
# RULE-ONLY ENGINE
# --------------------------------------------------------

def rule_label(sender, text):
    domain = extract_domain(sender)

    # Classroom
    if any(k in sender.lower() for k in CLASSROOM_KEYS):
        return "Administrative"

    # Ad domains
    if any(ad in domain for ad in AD_DOMAINS):
        return "Misc"

    # External newsletter
    if not domain.endswith("charusat.ac.in") and regex_match(text, PAT_NEWS):
        if not regex_match(text, PAT_EVENT):
            return "Misc"

    # External program spam
    if regex_match(text, PAT_PROGRAM) and not (
        domain.endswith("charusat.ac.in") or
        domain.endswith("charusat.edu.in") or
        domain in TRUSTED_PROGRAM_SENDERS
    ):
        return "Misc"

    # Trusted program sources
    if regex_match(text, PAT_PROGRAM) and (
        domain.endswith("charusat.ac.in") or
        domain in TRUSTED_PROGRAM_SENDERS
    ):
        return "Administrative"

    # Events
    if regex_match(text, PAT_EVENT):
        return "Event"
    # Course materials (syllabus, PFA, practical list)
    if regex_match(text, PAT_COURSE_DOC):
        return "Administrative"

    # Semester-wide or long-term timetables → Administrative
    if regex_match(text, [
        r"\bsemester timetable\b",
        r"\bfull semester\b",
        r"\bcomplete timetable\b",
        r"\bterm timetable\b",
        r"\bsemester schedule\b",
        r"\bacademic calendar\b",
        r"\bsemester plan\b"
    ]):
        return "Administrative"

    # Academic keywords
    if regex_match(text, PAT_ASSIGN):
        return "Assignment"
    if regex_match(text, PAT_TEST):
        return "Test"
    if regex_match(text, PAT_EXAM):
        return "Exam"
    if regex_match(text, PAT_LECTURE):
        return "Lecture"
    if regex_match(text, PAT_URGENT):
        return "Urgent"

    return "Misc"

# --------------------------------------------------------
# MAIN LOOP
# --------------------------------------------------------

df = pd.read_csv(INPUT_FILE)

df["label"] = (
    df["label"]
    .astype(str)
    .replace(["nan", "None", "NaN", "null"], "")
    .fillna("")
)

df = df.reset_index(drop=True)
labels = df["label"].tolist()

print("\nStarting rule-only labeling...\n")

# Find the first row with an empty label and start from there
start_idx = 0
for i, label in enumerate(labels):
    if label == "":
        start_idx = i
        break
else:
    print("All rows already labeled. Exiting.")
    exit(0)

for idx, row in df.iloc[start_idx:].iterrows():
    real_idx = start_idx + idx if hasattr(df.iloc[start_idx:], 'index') else idx
    if labels[real_idx] != "":
        continue

    sender = row.get("from", "")
    content = clean(row.get("full_text", ""))

    print("\n----------------------------------")
    print(f"Row {real_idx}")
    print("----------------------------------")
    print("Sender:", sender)
    print("Preview:", preview(content))

    # RULE ENGINE
    suggested = rule_label(sender, content)
    print("\n✓ Rule-only suggested:", suggested)

    user = input("Your label (ENTER = accept): ").strip()
    final = suggested if user == "" else (user if user in CATEGORIES else suggested)

    labels[real_idx] = final
    df["label"] = labels
    df.to_csv(OUTPUT_FILE, index=False)

    print("✓ Saved:", final)

print("\nDONE.")
print("Saved to:", OUTPUT_FILE)
