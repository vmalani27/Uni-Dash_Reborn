import re
import pandas as pd
from html import unescape

INPUT_FILE = "unlabeled_dataset.csv"
OUTPUT_FILE = "labeled_level1_labeled.csv"

# ---------------------------------------
# Helpers
# ---------------------------------------

def clean_text(s):
    return re.sub(r"\s+", " ", unescape(str(s))).strip().lower()

def extract_domain(sender):
    if not isinstance(sender, str):
        return ""
    m = re.search(r"@([^ >]+)", sender)
    return m.group(1).lower() if m else ""


# ---------------------------------------
# Keyword patterns
# ---------------------------------------

EXAM_PATTERNS = [
    r"exam timetable", r"exam schedule", r"hall ticket", r"exam form",
    r"seating", r"\bcie\b", r"mid\s*sem", r"end\s*sem",
    r"reassessment", r"rechecking", r"revaluation",
    r"supplementary", r"remedial", r"marks", r"result", r"grade"
]

SGP_PATTERNS = [
    r"\bsgp\b", r"student group project", r"weekly report",
    r"project", r"project viva", r"project presentation",
    r"guide allocation", r"definition submission"
]

EVENT_PATTERNS = [
    r"\bctf\b", r"hackathon", r"workshop", r"webinar", r"seminar",
    r"competition", r"challenge", r"guest lecture", r"tech talk",
    r"boot ?camp", r"hands[- ]on", r"datathon",
    r"nss unit", r"ieee", r"organised"
]

ADMIN_PATTERNS = [
    r"attendance", r"leave entry", r"leave application", r"training",
    r"academy", r"aws", r"red ?hat", r"certification", r"google classroom",
    r"upskill"
]

PLACEMENT_PATTERNS = [
    r"internship", r"hiring", r"placement", r"campus drive",
    r"recruitment", r"career launchpad"
]

AD_DOMAINS = {"pinterest.com", "sendgrid.net", "mailchimp.com", "read.ai"}
NPTEL_DOMAINS = {"nptel.iitm.ac.in", "nptel.ac.in"}
COURSERA_DOMAINS = {"m.learn.coursera.org", "coursera.org"}

def match_any(text, patterns):
    return any(re.search(p, text) for p in patterns)


# ---------------------------------------
# Final Rule Function
# ---------------------------------------

def classify(sender, text):
    dom = extract_domain(sender)
    sender_l = (sender or "").lower()

    # --------------------------
    # 1. NPTEL External Courses
    # --------------------------
    if dom in NPTEL_DOMAINS:
        return "NPTEL / External Courses"

    # Coursera → Misc
    if dom in COURSERA_DOMAINS:
        return "Misc"

    # AD domains → Misc
    if any(ad in dom for ad in AD_DOMAINS):
        return "Misc"

    # --------------------------
    # 2. Student senders (.edu.in)
    # --------------------------
    if dom.endswith("charusat.edu.in"):
        if match_any(text, EVENT_PATTERNS):
            return "Events / Hackathons / Clubs"
        return "Misc"

    # --------------------------
    # 3. Faculty / staff (.ac.in)
    # --------------------------
    if dom.endswith("charusat.ac.in"):

        # Keywords take priority over domain rules

        if match_any(text, EXAM_PATTERNS):
            return "Exam Cell / Academic Office"

        if match_any(text, SGP_PATTERNS):
            return "SGP / Project Related"

        if match_any(text, EVENT_PATTERNS):
            return "Events / Hackathons / Clubs"

        if match_any(text, ADMIN_PATTERNS):
            return "Administrative"

        # Placement allowed ONLY for .ac.in (your rule)
        if match_any(text, PLACEMENT_PATTERNS):
            return "Internships / Placement Cell"

        return "Misc"

    # --------------------------
    # 4. External senders (gmail, etc.)
    # --------------------------
    if match_any(text, EVENT_PATTERNS):
        return "Events / Hackathons / Clubs"

    # Placement from external senders → Misc (you said Q8)
    if match_any(text, PLACEMENT_PATTERNS):
        return "Misc"

    return "Misc"


# ---------------------------------------
# Run on file
# ---------------------------------------

if __name__ == "__main__":
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

    if "clean_text" not in df.columns:
        df["clean_text"] = df["clean_text"].astype(str).map(clean_text)

    df["label_source"] = df.apply(
        lambda r: classify(r.get("from", ""), r.get("clean_text", "")),
        axis=1
    )

    df.to_csv(OUTPUT_FILE, index=False)
    print("Labels written to:", OUTPUT_FILE)
