import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime
from app.core.database import Base


class Broadcast(Base):
    __tablename__ = "broadcasts"

    id = Column(Integer, primary_key=True)
    broadcast_id = Column(String, unique=True, index=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # AI-derived fields (precomputed before sending)
    ai_summary = Column(Text, nullable=True)
    ai_label_topic = Column(String, nullable=True)
    ai_label_urgency = Column(String, nullable=True)
    ai_label_source = Column(String, nullable=True)
    deadline_iso = Column(DateTime, nullable=True)
    deadline_confidence = Column(String, nullable=True)

    # Optional: store raw payload or notes
    notes = Column(Text, nullable=True)
