from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
import datetime
from app.core.database import Base

class AcademicItem(Base):
    __tablename__ = "academic_items"

    id = Column(Integer, primary_key=True, index=True)
    # The source email
    source_email_id = Column(String, index=True)
    # Which user this belongs to
    uid = Column(String, index=True)
    
    # Entity Type: ASSIGNMENT, EXAM, EVENT, OPPORTUNITY, ANNOUNCEMENT
    entity_type = Column(String, index=True)
    
    title = Column(String)
    description = Column(Text, nullable=True)
    
    # Extracted metadata
    due_date = Column(DateTime, nullable=True)
    location = Column(String, nullable=True)
    professor = Column(String, nullable=True)
    course_code = Column(String, nullable=True)
    
    # Inherits importance from the context engine
    academic_score = Column(Integer, default=0)
    
    # UI state
    status = Column(String, default="active", index=True)
    completed = Column(Boolean, default=False)
    dismissed = Column(Boolean, default=False)
    snoozed_until = Column(DateTime, nullable=True)

    # Source consolidation
    source_count = Column(Integer, default=1)
    source_signals_json = Column(Text, nullable=True)
    merge_key = Column(String, index=True, nullable=True)
    
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
