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
# Level-1 Rules (Source Category)
# ----------------------------------------------------------

EXTERNAL_COURSE_DOMAINS = {
    "nptel.iitm.ac.in",
    "nptel.ac.in",

}

# Admin keywords that indicate institutional office actions
ADMIN_KEYWORDS = [
    "exam cell", "examination", "exam schedule", "timetable", "fees", "payment",
    "hallticket", "admission", "academic office", "notice",
    "circular", "student section", "updated", "renewal", "mysy","scholarship","scheme", "student id","e-governance", "commencment" ,"reporting"
]


def classify_level1(sender, sender_domain, clean_text):
    """
    Level-1 classification:
    Identify the source category (who sent it), not the topic.
    """

    sender_domain = (sender_domain or "").lower().strip()
    clean_text = (clean_text or "").lower()

    # If domain not given - extract
    if not sender_domain:
        sender_domain = extract_domain(sender)

    # 1. External Course Providers
    if sender_domain in EXTERNAL_COURSE_DOMAINS:
        return "External Course Provider"

    # 2. Student / Club
    if sender_domain.endswith("charusat.edu.in"):
        return "Student / Club"

    # 3. Administration / Office (only charusat.ac.in with admin keywords)
    if sender_domain.endswith("charusat.ac.in") and any(k in clean_text for k in ADMIN_KEYWORDS):
        return "Administration / Office"

    # 4. Faculty / Academic Staff (charusat.ac.in, not admin)
    if sender_domain.endswith("charusat.ac.in"):
        return "Faculty / Academic Staff"

    # 5. Misc / External
    return "Misc / External"


# ----------------------------------------------------------
# Apply classifier
# ----------------------------------------------------------
if __name__ == "__main__":
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

    # Extract domain if column absent
    if "sender_domain" not in df.columns:
        df["sender_domain"] = df["from"].map(extract_domain)

    df["label_source"] = df.apply(
        lambda r: classify_level1(
            r.get("from", ""),
            r.get("sender_domain", ""),
            r.get("clean_text", "")
        ),
        axis=1
    )

    df.to_csv(OUTPUT_FILE, index=False)
    print("Level-1 labels written to:", OUTPUT_FILE)
