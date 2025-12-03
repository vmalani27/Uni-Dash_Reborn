"""
HYBRID EMAIL LABELING ENGINE (DEBUG + LOGGING VERSION)
------------------------------------------------------
CSV must contain:
    from, full_text, label
"""

import pandas as pd
import subprocess
import re
from html import unescape

# --------------------------------------------------------
# CONFIG
# --------------------------------------------------------

INPUT_FILE = "cleaned_dataset.csv"
OUTPUT_FILE = "labeled_dataset.csv"
MODEL_NAME = "mistral"

CATEGORIES = [
    "Assignment", "Test", "Exam", "Lecture",
    "Event", "Administrative", "Urgent", "Misc"
]

PREVIEW_CHARS = 300


# --------------------------------------------------------
# REGEX PATTERNS
# --------------------------------------------------------


# --------------------------------------------------------
# Regex-based academic semantic detection (NO substrings)
# Updated: Coursework, syllabus, timetable, etc. → Lecture
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

# Lecture: includes coursework, syllabus, timetable, class/lab info, etc.
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

def is_assignment(text): return regex_match(text, PAT_ASSIGN)
def is_test(text): return regex_match(text, PAT_TEST)
def is_exam(text): return regex_match(text, PAT_EXAM)
def is_lecture(text): return regex_match(text, PAT_LECTURE)
def is_urgent(text): return regex_match(text, PAT_URGENT)
def is_program(text): return regex_match(text, PAT_PROGRAM)
def is_newsletter(text): return regex_match(text, PAT_NEWS)
def is_event(text): return regex_match(text, PAT_EVENT)

def is_academic_keyword(text):
    return (
        is_assignment(text) or
        is_test(text) or
        is_exam(text) or
        is_lecture(text)
    )

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


def call_ollama(prompt):
    try:
        p = subprocess.run(
            ["ollama", "run", MODEL_NAME],
            input=prompt.encode(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=25
        )
        return p.stdout.decode().strip()
    except Exception as e:
        print("[ERROR] Ollama call failed:", e)
        return "Misc"


def extract_category(raw):
    raw = raw.strip()
    if raw in CATEGORIES:
        return raw
    for c in CATEGORIES:
        if re.search(rf"\b{c.lower()}\b", raw.lower()):
            return c
    return None


# --------------------------------------------------------
# LLM PROMPT
# --------------------------------------------------------

LLM_PROMPT = """
Classify the email into one of these categories exactly:
Assignment, Test, Exam, Lecture, Event, Administrative, Urgent, Misc.

SENDER:
{sender}

CONTENT:
{content}

Return ONLY the category name.
"""


# --------------------------------------------------------
# PRE-RULE ENGINE with LOGS
# --------------------------------------------------------

def pre_rule(sender, text):
    domain = extract_domain(sender)

    print(f"  [pre] Domain: {domain}")

    # Classroom
    if any(k in sender.lower() for k in CLASSROOM_KEYS):
        print("  [pre] Classroom detected → academic override")
        return (None, False, "classroom")

    # Ad domains
    if any(ad in domain for ad in AD_DOMAINS):
        print("  [pre] Ad domain matched")
        return ("Misc", True, "ad_domain")

    # External newsletter
    if not domain.endswith("charusat.ac.in") and regex_match(text, PAT_NEWS):
        if not regex_match(text, PAT_EVENT):
            print("  [pre] External newsletter matched")
            return ("Misc", True, "newsletter_external")

    # External program spam
    if regex_match(text, PAT_PROGRAM) and not (
        domain.endswith("charusat.ac.in") or
        domain.endswith("charusat.edu.in") or
        domain in TRUSTED_PROGRAM_SENDERS
    ):
        print("  [pre] External program spam detected")
        return ("Misc", True, "external_program_spam")

    # Trusted program sources
    if regex_match(text, PAT_PROGRAM) and (
        domain.endswith("charusat.ac.in") or
        domain in TRUSTED_PROGRAM_SENDERS
    ):
        print("  [pre] Trusted academic program detected")
        return ("Administrative", True, "program_trusted")

    # Events
    if regex_match(text, PAT_EVENT):
        print("  [pre] Event keyword matched")
        return ("Event", False, "event")
    # Course materials (syllabus, PFA, practical list)
    if regex_match(text, PAT_COURSE_DOC):
        print("  [pre] Course document detected → Administrative")
        return ("Administrative", True, "course_document")

    # Academic keywords
    if regex_match(text, PAT_ASSIGN):
        print("  [pre] Assignment keyword matched")
        return ("Assignment", False, "assignment")
    if regex_match(text, PAT_TEST):
        print("  [pre] Test keyword matched")
        return ("Test", False, "test")
    if regex_match(text, PAT_EXAM):
        print("  [pre] Exam keyword matched")
        return ("Exam", False, "exam")
    if regex_match(text, PAT_LECTURE):
        print("  [pre] Lecture keyword matched")
        return ("Lecture", False, "lecture")
    if regex_match(text, PAT_URGENT):
        print("  [pre] Urgent keyword matched")
        return ("Urgent", True, "urgent")

    print("  [pre] No rule matched → LLM needed")
    return (None, False, "undecided")


# --------------------------------------------------------
# POST-RULE ENGINE with LOGS
# --------------------------------------------------------

def post_rule(reason, sender, text, llm_out):
    domain = extract_domain(sender)

    print(f"  [post] Pre-reason: {reason}, LLM: {llm_out}, Domain: {domain}")

    # classroom override
    if reason == "classroom":
        if llm_out in ["Misc", "Event"]:
            print("  [post] Classroom override applied")
            if regex_match(text, PAT_ASSIGN): return "Assignment"
            if regex_match(text, PAT_TEST): return "Test"
            if regex_match(text, PAT_LECTURE): return "Lecture"
            return "Administrative"

    # external spam program
    if reason == "external_program_spam" and llm_out == "Administrative":
        print("  [post] Spam override → Misc")
        return "Misc"

    # student domain shouldn't be Administrative unless academic
    if domain.endswith("charusat.edu.in") and llm_out == "Administrative":
        print("  [post] .edu.in cannot be Administrative")
        return "Misc"

    # If LLM mislabels syllabus/practical as Assignment -> fix to Administrative
    if regex_match(text, PAT_COURSE_DOC) and llm_out == "Assignment":
        print("  [post] Syllabus/Practical override → Administrative")
        return "Administrative"

    # If LLM said Misc but academic signals exist
    if llm_out == "Misc":
        if regex_match(text, PAT_ASSIGN): return "Assignment"
        if regex_match(text, PAT_TEST): return "Test"
        if regex_match(text, PAT_EXAM): return "Exam"
        if regex_match(text, PAT_EVENT): return "Event"

    return llm_out


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

print("\nStarting labeling...\n")

for idx, row in df.iterrows():

    if labels[idx] != "":
        continue

    sender = row.get("from", "")
    content = clean(row.get("full_text", ""))

    print("\n----------------------------------")
    print(f"Row {idx}")
    print("----------------------------------")
    print("Sender:", sender)
    print("Preview:", preview(content))

    # PRE-RULE
    pre_label, pre_conf, pre_reason = pre_rule(sender, content)

    if pre_label:
        print(f"\n→ Rule-based suggestion: {pre_label} (conf={pre_conf})")
    else:
        print("\n→ Rule-based undecided → LLM needed")

    # If high confidence, skip LLM
    if pre_label and pre_conf:
        suggested = pre_label
    else:
        # LLM
        prompt = LLM_PROMPT.format(sender=sender, content=content)
        raw = call_ollama(prompt)
        llm_choice = extract_category(raw) or "Misc"

        print("\n→ LLM suggestion:", llm_choice)
        print("[DEBUG raw LLM output]:", raw)

        # POST RULE
        suggested = post_rule(pre_reason, sender, content, llm_choice)

    print("\n✓ Final suggested:", suggested)

    user = input("Your label (ENTER = accept): ").strip()
    final = suggested if user == "" else (user if user in CATEGORIES else suggested)

    labels[idx] = final
    df["label"] = labels
    df.to_csv(OUTPUT_FILE, index=False)

    print("✓ Saved:", final)

print("\nDONE.")
print("Saved to:", OUTPUT_FILE)
