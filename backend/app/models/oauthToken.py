from sqlalchemy import Column, DateTime, String, Boolean, Integer
from sqlalchemy.types import Text
from app.core.database import Base

class OAuthToken(Base):
    __tablename__ = "oauth_tokens"

    uid = Column(String, primary_key=True)
    access_token = Column(Text, nullable=True)
    refresh_token = Column(Text, nullable=True)
    expires_at = Column(DateTime, nullable=True)
    scopes = Column(Text, nullable=True)
    token_type = Column(String, nullable=True)
