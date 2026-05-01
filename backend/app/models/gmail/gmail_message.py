import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean
from app.core.database import Base


# Gmail message model

class GmailMessage(Base):
    __tablename__ = "gmail_messages"

    id = Column(Integer, primary_key=True)
    uid = Column(String, index=True)               # Firebase UID
    gmail_id = Column(String, unique=True, index=True)
    thread_id = Column(String, nullable=True)
    sender = Column(String)
    subject = Column(String)
    snippet = Column(Text)
    body_html = Column(Text)
    body_text = Column(Text)
    internal_date = Column(DateTime)                # Gmail timestamp
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    # AI Processing fields
    ai_status = Column(String, nullable=True)       # None, pending, processing, failed, completed, completed_preprocessed
    ai_processed = Column(Boolean, default=False)   # True when AI inference completed
    ai_summary = Column(Text, nullable=True)        # LLM-generated summary
    ai_label_topic = Column(String, nullable=True)  # LLM topic classification
    ai_label_urgency = Column(String, nullable=True)  # LLM urgency level
    ai_label_source = Column(String, nullable=True)  # Extracted source/domain
    
    # Retry logic fields
    retry_count = Column(Integer, default=0)
    last_error = Column(Text, nullable=True)
    next_retry_at = Column(DateTime, nullable=True)
    
    # Broadcast tracking header (X-UniDash-Broadcast-ID)
    unidash_broadcast_id = Column(String, nullable=True, index=True)
    
    # Extracted metadata fields
    deadline_iso = Column(DateTime, nullable=True)  # Detected deadline
    deadline_confidence = Column(String, nullable=True)  # Confidence level for deadline
    normalized_topic = Column(String, nullable=True)  # Academic ontology topic



# Gmail sync status is defined in gmail_sync_status.py to avoid duplication
