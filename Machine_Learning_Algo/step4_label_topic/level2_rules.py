import re
import pandas as pd
from collections import defaultdict

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

INPUT_FILE = "../level1_output.csv"          # must contain: clean_text, label_source
OUTPUT_RULE_FILE = "level2_rule_labels.csv"
OUTPUT_MODEL_FILE = "level2_model_ready.csv"


# ----------------------------------------------------------
# 1. Level-2 topic definitions
# ----------------------------------------------------------

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
    "Timetable / Schedule Update": [
        r"\btimetable\b", r"\bschedule\b", "class timetable",
        "slot", "lecture schedule", "lab schedule", "rescheduled",
        "class will be", "time table"
    ],
    "Exam Notifications": [
        r"\bexam\b", "midsem", "mid-sem", "endsem", "end-sem",
        "quiz", "test", "unit test", "hall ticket", "seating arrangement",
        "exam form", "exam registration", "assessment"
    ],
    "Assignment or Submission": [
        "submit", "submission", "upload", "weekly report", "weekly reports",
        "sgp", "project report", "assignment", "project file",
        "implementation of their project", "deadline for submission"
    ],
    "Certification / Courses": [
        "course", "nptel", "coursera", "aws academy", "aws educate",
        "certificate", "certification", "cohort", "batch",
        "workshop", "bootcamp", "lms portal", "enroll", "registration is open",
        "code program", "online course", "executive program"
    ],
    "Internship / Placement Opportunities": [
        "internship", "placement", "drive", "shortlisted",
        "hiring", "job opportunity", "career launchpad",
        "stipend", "recruitment", "campus placement", "career program",
        "apply for internship", "career launchpad program"
    ],
    "Events / Hackathons": [
        "event", "hackathon", "ctf", "capture the flag",
        "seminar", "webinar", "talk", "session", "orientation",
        "workshop on", "surc", "symposium", "conference",
        "student branch", "ieee charusat student branch", "challenge now open"
    ],
    "Important Announcements": [
        "final reminder", "gentle reminder", "last date",
        "must", "mandatory", "compulsory", "important notice",
        "important announcement", "attention", "strictly",
        "without fail", "no extension will be granted"
    ],
    "Administrative / Fees / Counselling": [
        "fees", "fee payment", "hostel", "counselling",
        "e-governance", "e governance", "governance portal",
        "registration portal", "university policy",
        "document verification", "academic office"
    ],
    "General Information / Misc": [
        # fallback; normally not used as primary keyword category
        "newsletter", "recap", "meeting report", "summary",
        "weekly recap", "update", "information"
    ],
}


# ----------------------------------------------------------
# 2. Level-1 → Level-2 biases
# ----------------------------------------------------------

LEVEL1_BIAS = {
    # label_source: {level2_topic: bias_score}
    "Student / Club": {
        "Events / Hackathons": 0.6,
        "Important Announcements": 0.3,
        "General Information / Misc": 0.2,
    },
    "Faculty / Academic Staff": {
        "Assignment or Submission": 0.6,
        "Timetable / Schedule Update": 0.4,
        "Important Announcements": 0.4,
        "Administrative / Fees / Counselling": 0.2,
    },
    "External Course Provider": {
        "Certification / Courses": 0.8,
        "Exam Notifications": 0.3,
        "Events / Hackathons": 0.2,
    },
    "University Automation": {
        "Administrative / Fees / Counselling": 0.8,
        "Exam Notifications": 0.4,
        "Important Announcements": 0.3,
    },
    "Misc / External": {
        "Internship / Placement Opportunities": 0.3,
        "Certification / Courses": 0.3,
        "Events / Hackathons": 0.2,
        "General Information / Misc": 0.4,
    },
}


# ----------------------------------------------------------
# Helper functions
# ----------------------------------------------------------

def score_topic_keywords(text: str, topic: str) -> float:
    """Count keyword hits for a topic with simple regex/substring matching."""
    text = text.lower()
    patterns = TOPIC_KEYWORDS.get(topic, [])
    score = 0.0
    for p in patterns:
        if r"\b" in p or "[" in p or "(" in p:
            # treat as regex
            if re.search(p, text):
                score += 1.0
        else:
            if p in text:
                score += 1.0
    return score


def classify_level2_rule_based(text: str, label_source: str) -> tuple[str, float, dict]:
    """
    Rule-based Level-2 classification:
    - keyword score per topic
    - add Level-1 bias
    - choose argmax topic
    """
    text = text or ""
    label_source = (label_source or "").strip()

    scores = defaultdict(float)

    # keyword-based score
    for topic in LEVEL2_LABELS:
        kw_score = score_topic_keywords(text, topic)
        if kw_score > 0:
            scores[topic] += kw_score

    # Level-1 bias
    if label_source in LEVEL1_BIAS:
        for topic, bias in LEVEL1_BIAS[label_source].items():
            scores[topic] += bias

    # If still no score, default to Misc
    if not scores:
        return "General Information / Misc", 0.0, {}

    # pick best topic
    best_topic = max(scores.items(), key=lambda x: x[1])[0]
    best_score = scores[best_topic]

    return best_topic, best_score, dict(scores)


# ----------------------------------------------------------
# 3. Apply rule-based Level-2 classification
# ----------------------------------------------------------

def run_rule_based_level2(df: pd.DataFrame) -> pd.DataFrame:
    level2_labels = []
    level2_scores = []

    for _, row in df.iterrows():
        text = row.get("clean_text", "")
        src = row.get("label_source", "")
        label, score, _ = classify_level2_rule_based(text, src)
        level2_labels.append(label)
        level2_scores.append(score)

    df = df.copy()
    df["label_topic_rule"] = level2_labels
    df["label_topic_rule_score"] = level2_scores
    return df


# ----------------------------------------------------------
# 4. Optional: train ML classifier on weak labels
# ----------------------------------------------------------

def train_supervised_on_weak_labels(df: pd.DataFrame):
    """
    Train a simple TF-IDF + LogisticRegression model
    to generalize beyond the strict keyword rules.
    """
    # use only rows where rule-based score is reasonably confident
    df_train = df[df["label_topic_rule_score"] >= 1.0].copy()
    if df_train.empty:
        print("Not enough confident weak labels to train a model.")
        return None

    X = df_train["clean_text"].fillna("")
    y = df_train["label_topic_rule"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    clf = Pipeline([
        ("tfidf", TfidfVectorizer(
            max_features=7000,
            ngram_range=(1, 2),
            stop_words="english"
        )),
        ("logreg", LogisticRegression(
            max_iter=200,
            n_jobs=-1,
            multi_class="auto"
        )),
    ])

    clf.fit(X_train, y_train)
    y_pred = clf.predict(X_test)

    print("\n=== Supervised model performance on weak labels ===")
    print(classification_report(y_test, y_pred))

    return clf


# ----------------------------------------------------------
# 5. Main
# ----------------------------------------------------------

def main():
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)
    if "clean_text" not in df.columns:
        raise ValueError("Input CSV must contain a 'clean_text' column.")
    if "label_source" not in df.columns:
        print("Warning: 'label_source' not found. Level-1 biases will not be applied.")

    df_rule = run_rule_based_level2(df)
    df_rule.to_csv(OUTPUT_RULE_FILE, index=False, encoding="utf-8")
    print("Rule-based Level-2 labels saved to:", OUTPUT_RULE_FILE)

    # Train supervised classifier (optional)
    model = train_supervised_on_weak_labels(df_rule)
    if model is not None:
        # Use the model to generate refined labels
        preds = model.predict(df_rule["clean_text"].fillna(""))
        df_rule["label_topic_model"] = preds
        df_rule.to_csv(OUTPUT_MODEL_FILE, index=False, encoding="utf-8")
        print("Model-based Level-2 labels saved to:", OUTPUT_MODEL_FILE)
    else:
        print("Skipping supervised model step due to insufficient data.")


if __name__ == "__main__":
    main()
