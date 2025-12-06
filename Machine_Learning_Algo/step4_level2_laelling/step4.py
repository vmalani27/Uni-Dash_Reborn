import pandas as pd
from sentence_transformers import SentenceTransformer, util

INPUT_FILE = "level1_output.csv"
OUTPUT_FILE = "level2_output.csv"

# ---------------------------------------------------------
# Load embedding model
# ---------------------------------------------------------
model = SentenceTransformer("all-mpnet-base-v2")  
# You can change to faster model like:
# "all-MiniLM-L6-v2"

# ---------------------------------------------------------
# LEVEL-2 PROTOTYPE SENTENCES
# ---------------------------------------------------------
PROTOTYPES = {
    "Timetable / Schedule Update":
        "This email is about class schedule updates, timetable changes, rescheduled lectures or sessions.",
    
    "Exam Notifications":
        "This email is about exams, hall tickets, seating arrangements, exam forms or assessment dates.",
    
    "Assignment or Submission":
        "This email is about submitting assignments, reports, weekly submissions, project files or documents.",
    
    "Certification / Courses":
        "This email is about online courses, certifications, NPTEL, Coursera, workshops or training programs.",
    
    "Internship / Placement Opportunities":
        "This email is about jobs, internships, placement drives, career programs or industry opportunities.",
    
    "Events / Hackathons":
        "This email is about events, workshops, hackathons, technical competitions or seminars.",
    
    "Important Announcements":
        "This email contains important announcements, deadlines, applications, notices or required actions.",
    
    "Administrative / Fees / Counselling":
        "This email is about academic administration, fees, portals, counselling, registration or procedures.",
    
    "General Information / Misc":
        "This email contains general information, miscellaneous content or unrelated updates."
}

# ---------------------------------------------------------
# Precompute prototype embeddings
# ---------------------------------------------------------
prototype_labels = list(PROTOTYPES.keys())
prototype_embeddings = model.encode(list(PROTOTYPES.values()), convert_to_tensor=True)

# ---------------------------------------------------------
# CLASSIFIER FUNCTION
# ---------------------------------------------------------
def classify_level2(text):
    if not isinstance(text, str):
        return "General Information / Misc"

    text = text.strip().lower()
    email_vec = model.encode(text, convert_to_tensor=True)

    # Compute cosine similarities
    cosine_scores = util.cos_sim(email_vec, prototype_embeddings)[0]

    # Get best matching label
    best_index = int(cosine_scores.argmax())
    return prototype_labels[best_index]

# ---------------------------------------------------------
# APPLY TO DATASET
# ---------------------------------------------------------
if __name__ == "__main__":
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)

    df["label_topic"] = df["clean_text"].apply(classify_level2)

    df.to_csv(OUTPUT_FILE, index=False)
    print("Level-2 (embedding-only) labels written to:", OUTPUT_FILE)
