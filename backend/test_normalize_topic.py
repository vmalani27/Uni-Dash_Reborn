#!/usr/bin/env python3
"""Quick test to verify normalize_topic mapping is correct."""

from app.services.academic_context_engine import AcademicContextEngine

# All LLM labels
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

# Expected mapping
EXPECTED = {
    "Timetable / Schedule Update": "ACADEMIC_ADMIN",
    "Exam Notifications": "EXAM",
    "Assignment or Submission": "ASSIGNMENT",
    "Certification / Courses": "OPPORTUNITY",
    "Internship / Placement Opportunities": "OPPORTUNITY",
    "Events / Hackathons": "OPPORTUNITY",
    "Important Announcements": "INFORMATION",
    "Administrative / Fees / Counselling": "ACADEMIC_ADMIN",
    "General Information / Misc": "INFORMATION",
}

print("Testing normalize_topic() mapping...\n")

all_pass = True
for label in LEVEL2_LABELS:
    result = AcademicContextEngine.normalize_topic(label)
    expected = EXPECTED[label]
    status = "✓" if result == expected else "✗"
    
    if result != expected:
        all_pass = False
    
    print(f"{status} {label:40} → {result:15} (expected: {expected})")

print("\n" + ("="*70))
if all_pass:
    print("✓ All mappings correct!")
else:
    print("✗ Some mappings failed!")

# Test edge cases
print("\nEdge cases:")
print(f"  None/empty: {AcademicContextEngine.normalize_topic(None)} (expected: OTHER)")
print(f"  Empty str: {AcademicContextEngine.normalize_topic('')} (expected: OTHER)")
print(f"  Random: {AcademicContextEngine.normalize_topic('Random Mail')} (expected: OTHER)")
