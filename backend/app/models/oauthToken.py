from sqlalchemy import Column, DateTime, String, Text
from app.core.database import Base
import datetime

class OAuthToken(Base):
    __tablename__ = "oauth_tokens"

    uid = Column(String, primary_key=True)

    refresh_token = Column(Text, nullable=False)
    scopes = Column(Text, nullable=True)

    expires_at = Column(DateTime, nullable=True)
    token_type = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
