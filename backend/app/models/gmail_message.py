import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime
from app.core.database import Base

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
