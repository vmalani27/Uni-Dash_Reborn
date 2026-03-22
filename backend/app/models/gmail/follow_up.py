from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
import datetime
from app.core.database import Base

class FollowUp(Base):
    __tablename__ = "follow_ups"

    id = Column(Integer, primary_key=True)
    # Using String for gmail_id since GmailMessage.gmail_id is String
    source_email_id = Column(String, index=True) 
    
    # When to surface this nudge
    trigger_at = Column(DateTime, index=True)
    
    # The actual message of the nudge
    message = Column(String)
    
    # State tracking
    delivered = Column(Boolean, default=False)
    dismissed = Column(Boolean, default=False)
    
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
