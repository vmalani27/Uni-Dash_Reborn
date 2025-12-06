import re
import pandas as pd
from html import unescape

INPUT_FILE = "unlabeled_dataset.csv"
OUTPUT_FILE = "level1_output.csv"

# ----------------------------------------------------------
# Helper: Extract domain from "from" field if missing
# ----------------------------------------------------------
def extract_domain(sender):
    """Extracts domain from 'from' field if the dataset doesn't contain sender_domain."""
    if not isinstance(sender, str):
        return ""
    m = re.search(r"@([^ >]+)", sender)
    return m.group(1).lower() if m else ""


# ----------------------------------------------------------
# Level-1 Rules (Final)
# ----------------------------------------------------------

EXTERNAL_COURSE_DOMAINS = {
    "nptel.iitm.ac.in",
    "nptel.ac.in",
    "m.learn.coursera.org",
    "coursera.org",
    "awseducate.com",
    "awsacademy.com"
}

UNIVERSITY_AUTOMATION_KEYWORDS = [
    "e-governance", "governance",
    "attendance", "fees", "portal", "examform", "academicoffice"
]


def classify_level1(sender, sender_domain, clean_text):
    """
    Level-1 classification:
    Identify ONLY the *source category*, not the topic.
    """

    # -------------------------------
    # Normalize and handle missing
    # -------------------------------
    sender_domain = (sender_domain or "").lower().strip()
    clean_text = (clean_text or "").lower()

    # Extract if domain missing
    if not sender_domain:
        sender_domain = extract_domain(sender)

    # -------------------------------
    # 1. External Course Providers
    # -------------------------------
    if sender_domain in EXTERNAL_COURSE_DOMAINS:
        return "External Course Provider"

    # -------------------------------
    # 2. University Automation Systems
    # (Based on keywords in clean_text)
    # -------------------------------
    if any(k in clean_text for k in UNIVERSITY_AUTOMATION_KEYWORDS):
        return "University Automation"

    # -------------------------------
    # 3. Faculty / Academic Staff
    # (ALL @charusat.ac.in emails)
    # -------------------------------
    if sender_domain.endswith("charusat.ac.in"):
        return "Faculty / Academic Staff"

    # -------------------------------
    # 4. Student / Club
    # (ALL @charusat.edu.in emails)
    # -------------------------------
    if sender_domain.endswith("charusat.edu.in"):
        return "Student / Club"

    # -------------------------------
    # 5. Misc / External Sender
    # -------------------------------
    return "Misc / External"


# ----------------------------------------------------------
# Apply classifier
# ----------------------------------------------------------

if __name__ == "__main__":
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

    if "sender_domain" not in df.columns:
        df["sender_domain"] = df["from"].map(extract_domain)

    df["label_source"] = df.apply(
        lambda r: classify_level1(r.get("from", ""),
                                  r.get("sender_domain", ""),
                                  r.get("clean_text", "")),
        axis=1
    )

    df.to_csv(OUTPUT_FILE, index=False)
    print("Level-1 labels written to:", OUTPUT_FILE)
