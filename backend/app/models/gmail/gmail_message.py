import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, Float, Boolean
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
    ai_status = Column(String, nullable=True)       # None, pending, processing, failed, completed
    ai_processed = Column(Boolean, default=False)   # True when AI inference completed
    ai_summary = Column(Text, nullable=True)        # LLM-generated summary
    ai_label_topic = Column(String, nullable=True)  # LLM topic classification
    ai_label_urgency = Column(String, nullable=True)  # LLM urgency level
    ai_label_source = Column(String, nullable=True)  # Extracted source/domain
    
    # Extracted metadata fields
    deadline_iso = Column(DateTime, nullable=True)  # Detected deadline
    deadline_confidence = Column(String, nullable=True)  # Confidence level for deadline
    academic_score = Column(Float, default=0.0)     # Academic relevance score (0.0-1.0)
    normalized_topic = Column(String, nullable=True)  # Academic ontology topic



# Gmail sync status model

class GmailSyncStatus(Base):
    __tablename__ = 'gmail_sync_status'
    uid = Column(String, primary_key=True)
    status = Column(String, default='not_started')  # not_started, in_progress, completed, failed
    started_at = Column(DateTime, default=None)
    finished_at = Column(DateTime, default=None)
    error_message = Column(Text, default=None)
    # New fields for incremental sync tracking
    last_sync_date = Column(DateTime, default=None)     # Track last successful sync
    total_messages_synced = Column(Integer, default=0)  # Monitor sync progress
    next_page_token = Column(String, default=None)      # Gmail API pagination
    sync_type = Column(String, default='full')          # 'full' or 'incremental'
    last_history_id = Column(String, default=None)      # Gmail History API cursor
