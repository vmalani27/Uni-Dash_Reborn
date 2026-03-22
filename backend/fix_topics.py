"""
Re-normalize all existing gmail_messages using the fixed normalize_topic logic.
This is a one-time migration to repair data from the broken ordering.
"""
from app.core.database import SupabaseSessionLocal
from app.models.gmail.gmail_message import GmailMessage
from app.services.academic_context_engine import AcademicContextEngine

db = SupabaseSessionLocal()
changed = 0
try:
    messages = db.query(GmailMessage).filter(GmailMessage.ai_processed == True).all()
    print(f"Found {len(messages)} processed emails to re-normalize.")
    for msg in messages:
        if not msg.ai_label_topic:
            continue
        correct = AcademicContextEngine.normalize_topic(msg.ai_label_topic)
        if msg.normalized_topic != correct:
            msg.normalized_topic = correct
            changed += 1

    db.commit()
    print(f"Re-normalized: {changed} rows updated.")
finally:
    db.close()
