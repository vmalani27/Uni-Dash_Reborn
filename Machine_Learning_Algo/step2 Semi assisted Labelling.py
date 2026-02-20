
import re
import pandas as pd
from html import unescape
import os
from datetime import datetime

INPUT_FILE = "unlabeled_dataset.csv"
# OUTPUT_FILE = "source_labeled_dataset.csv"

# Output will be saved in a timestamped folder
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
OUTPUT_DIR = f"output_{timestamp}"
os.makedirs(OUTPUT_DIR, exist_ok=True)
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "source_labeled_dataset.csv")


# ----------------------------------------------------------
# Level-1: Source Trust Classification (Identity-only)
# ----------------------------------------------------------

EXTERNAL_ACADEMIC_DOMAINS = {
    "nptel.iitm.ac.in",
    "nptel.ac.in",
    "coursera.org",
    "edx.org",
}

def classify_level1(sender_domain: str) -> str:
    """
    Level-1 classification determines the institutional trust level
    of the sender. It does NOT infer intent or topic.
    """

    sender_domain = (sender_domain or "").lower().strip()

    if not sender_domain:
        return "External / Misc"

    if sender_domain in EXTERNAL_ACADEMIC_DOMAINS:
        return "External Academic Platform"

    if sender_domain.endswith("charusat.ac.in"):
        return "Institutional Sender"

    if sender_domain.endswith("charusat.edu.in"):
        return "Student / Peer"

    return "External / Misc"



# ----------------------------------------------------------
# Apply classifier
# ----------------------------------------------------------
if __name__ == "__main__":
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)


    df["label_source"] = df.apply(
        lambda r: classify_level1(
            r.get("sender_domain", ""),
        ),
        axis=1
    )

    df.to_csv(OUTPUT_FILE, index=False)
    print(f"Level-1 labels written to: {OUTPUT_FILE}")
