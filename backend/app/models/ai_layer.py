import datetime

from sqlalchemy import Column, Integer, String, Text, DateTime, Float, ForeignKey, JSON, Boolean, UniqueConstraint, text

from app.core.database import Base


class ExtractedSignal(Base):
    __tablename__ = "extracted_signals"

    id = Column(Integer, primary_key=True)
    source_email_id = Column(String, ForeignKey("gmail_messages.gmail_id", ondelete="CASCADE"), index=True, nullable=False)
    uid = Column(String, index=True, nullable=False)
    raw_llm_output = Column(JSON, nullable=True)
    extracted_dates = Column(JSON, nullable=True)
    extracted_entities = Column(JSON, nullable=True)
    intent = Column(String, nullable=True, index=True)
    type_candidates = Column(JSON, nullable=True)
    confidence = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, index=True)


class AcademicEntity(Base):
    __tablename__ = "academic_entities"

    id = Column(Integer, primary_key=True)
    uid = Column(String, index=True, nullable=False)
    origin = Column(String, nullable=False, default="system", server_default=text("'system'"), index=True)
    canonical_title = Column(String, nullable=False, index=True)
    summary = Column(Text, nullable=True)
    entity_type = Column(String, nullable=False, index=True)
    best_deadline = Column(DateTime, nullable=True, index=True)
    confidence_score = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)


class EntitySourceMap(Base):
    __tablename__ = "entity_source_map"
    __table_args__ = (
        UniqueConstraint("entity_id", "source_email_id", name="uq_entity_source_map_entity_email"),
    )

    id = Column(Integer, primary_key=True)
    entity_id = Column(Integer, ForeignKey("academic_entities.id", ondelete="CASCADE"), index=True, nullable=False)
    source_email_id = Column(String, ForeignKey("gmail_messages.gmail_id", ondelete="CASCADE"), index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class EntityActionState(Base):
    __tablename__ = "entity_action_state"
    __table_args__ = (
        UniqueConstraint("entity_id", "uid", name="uq_entity_action_state_entity_uid"),
    )

    id = Column(Integer, primary_key=True)
    entity_id = Column(Integer, ForeignKey("academic_entities.id", ondelete="CASCADE"), nullable=False)
    uid = Column(String, nullable=False, index=True)
    completed = Column(Boolean, default=False, nullable=False)
    dismissed = Column(Boolean, default=False, nullable=False)
    snoozed_until = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
