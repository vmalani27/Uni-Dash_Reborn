# --------------------------------------------------------
# REGEX PATTERNS
# --------------------------------------------------------


import pandas as pd
import subprocess
import re
from html import unescape


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


# ========================================================
# CONFIG
# ========================================================

INPUT_FILE = "labeled_level1.csv"
OUTPUT_FILE = "labeled_level1.csv"
MODEL_NAME = "mistral"

LEVEL1_CATEGORIES = [
    "NPTEL / External Courses",
    "E-Gov / University Automation",
    "SGP / Project Related",
    "Internships / Placement Cell",
    "Exam Cell / Academic Office",
    "Events / Hackathons / Clubs",
    "Administrative",
    "Misc"
]

PREVIEW_CHARS = 300


def extract_domain(sender):
    if not isinstance(sender, str): return ""
    m = re.search(r"@([^ >]+)", sender)
    return m.group(1).lower() if m else ""

def regex_match(text, patterns):
    if not isinstance(text, str): return False
    t = text.lower()
    return any(re.search(p, t) for p in patterns)

def clean(s):
    return re.sub(r"\s+", " ", unescape(str(s))).strip()

def preview(t):
    t = t.replace("\n", " ")
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
    except:
        return "Misc"


# ========================================================
# LLM PROMPT
# ========================================================

LLM_PROMPT = """
Classify the SOURCE of this email into ONE and ONLY ONE of the following categories (return EXACTLY as written):

NPTEL / External Courses
E-Gov / University Automation
SGP / Project Related
Internships / Placement Cell
Exam Cell / Academic Office
Events / Hackathons / Clubs
Administrative
Misc

SENDER:
{sender}

CONTENT:
{content}

IMPORTANT:
Return ONLY the category name, exactly as written above. Do NOT return any explanation, subcategory, subject, or description. If you do, your answer will be ignored.
"""


# ========================================================
# PRE-RULE ENGINE (ADAPTED FOR SOURCE LABELS)
# ========================================================

def pre_rule(sender, text):
        # All gmail.com senders are Misc
    
    dom = extract_domain(sender)
    s = sender.lower()
    t = text.lower()

    print(f"  [pre] Domain = {dom}")

    # Ads / spam
    if dom == "gmail.com":
        return ("Misc", True, "gmail_misc")
    if any(d in dom for d in AD_DOMAINS):
        return ("Misc", True, "ad_domain")

    # Trusted external academic programs (NPTEL, Coursera)
    if dom in TRUSTED_PROGRAM_SENDERS or dom.endswith("nptel.ac.in"):
        return ("NPTEL / External Courses", True, "nptel_trusted")

    # External newsletters
    if regex_match(text, PAT_NEWS) and not dom.endswith("charusat.edu.in"):
        return ("Misc", True, "newsletter_external")

    # SGP identifiers
    if "sgp" in t or "weekly report" in t:
        return ("SGP / Project Related", True, "sgp_rule")

    # Exam Cell indicators
    if regex_match(text, PAT_EXAM):
        return ("Exam Cell / Academic Office", False, "exam_keyword")

    # Internship / placement
    if regex_match(text, PAT_PROGRAM) or "placement" in t or "internship" in t:
        return ("Internships / Placement Cell", False, "placement_rule")

    # Events
    if regex_match(text, PAT_EVENT):
        return ("Events / Hackathons / Clubs", False, "event_rule")

    # Administrative content (only for .charusat.ac.in senders)
    if dom.endswith("charusat.ac.in") and any(k in t for k in ["fee", "payment", "form", "hostel", "counselling"]):
        return ("Administrative", False, "admin_rule")

    # E-gov auto mails
    if dom.endswith("charusat.ac.in") and any(k in t for k in ["auto", "sy"
    "stem"]):
        return ("E-Gov / University Automation", True, "system_mail")

    return (None, False, "undecided")


# ========================================================
# POST-RULE ENGINE
# ========================================================

def post_rule(reason, sender, text, llm_out):
        # Newsletter keyword always overrides to Misc (highest priority)
    if regex_match(text, PAT_NEWS):
            return "Misc"
    dom = extract_domain(sender)
    t = text.lower()

    print(f"  [post] PreReason={reason}, LLM={llm_out}")

    # If LLM output isn't in Level 1, fallback to Misc
    if llm_out not in LEVEL1_CATEGORIES:
        return "Misc"

    # Spam overrides
    if reason == "external_program_spam" and llm_out == "Administrative":
        return "Misc"

    # .edu.in senders are students/clubs → NEVER Administrative
    if dom.endswith("charusat.edu.in"):
        if llm_out == "Administrative":
            return "Misc"   # downgrade safely
        return llm_out

    return llm_out


# ========================================================
# MAIN INTERACTIVE LOOP
# ========================================================
df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

df["label_source"] = (
    df["label_source"]
    .fillna("")
    .astype(str)
    .str.strip()
    .replace({"nan": ""})
)


# Find first unlabeled row
start_idx = None
for i, row in df.iterrows():
    if not row["label_source"]:
        print(row)
        start_idx = i
        break



print(start_idx)

def extract_valid_category(llm_guess, LEVEL1_CATEGORIES):
    """
    Returns the first valid category found in llm_guess, or 'Misc' if none match.
    """
    for cat in LEVEL1_CATEGORIES:
        if cat in llm_guess:
            return cat
    return "Misc"

for idx in range(start_idx, len(df)):
    row = df.iloc[idx]


    sender = row["from"]
    text = clean(row["clean_text"])

    print("\n----------------------------------")
    print(f"Row {idx}")
    print("Sender:", sender)
    print("Preview:", preview(text))
    print("----------------------------------")

    # 1. PRE-RULE
    pre_label, pre_conf, reason = pre_rule(sender, text)

    if pre_label:
        print(f"\n→ Pre-rule suggestion: {pre_label} (conf={pre_conf}, reason={reason})")
    else:
        print("\n→ No rule → LLM fallback\n")

    # 2. Decide whether to call LLM
    if pre_label and pre_conf:
        suggested = pre_label
    else:
        prompt = LLM_PROMPT.format(sender=sender, content=text)
        raw = call_ollama(prompt)
        llm_guess = raw.strip()
        llm_guess = extract_valid_category(llm_guess, LEVEL1_CATEGORIES)
        print("→ LLM guess:", llm_guess)

        suggested = post_rule(reason, sender, text, llm_guess)

    print("\n✓ FINAL SUGGESTED LABEL:", suggested)

    user = input("Enter label (ENTER=accept): ").strip()

    if user == "":
        final = suggested
    elif user in LEVEL1_CATEGORIES:
        final = user
    else:
        print("Invalid → using suggested")
        final = suggested

    df.loc[idx, "label_source"] = final
    print("✔ Saved:", final)

    df.to_csv(OUTPUT_FILE, index=False)

print("\nDONE. Saved to", OUTPUT_FILE)
