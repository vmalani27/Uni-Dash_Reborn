from app.core.database import SupabaseSessionLocal
from app.models.gmail.gmail_message import GmailMessage

db = SupabaseSessionLocal()
try:
    # Reset a few high-value emails to re-trigger the AI and Object Factory
    count = db.query(GmailMessage).filter(GmailMessage.normalized_topic.in_(["ASSIGNMENT", "EXAM", "OPPORTUNITY"])).update({
        "ai_processed": False,
        "ai_status": "pending"
    })
    db.commit()
    print(f"Reset {count} emails for reprocessing.")
finally:
    db.close()
