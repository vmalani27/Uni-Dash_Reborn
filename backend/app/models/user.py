
import datetime

from sqlalchemy import Column, String, Boolean, Integer, DateTime, Text
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    uid = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True)
    name = Column(String)
    branch = Column(String, nullable=True)
    semester = Column(Integer, nullable=True)
    sid = Column(String, nullable=True)
    profile_completed = Column(Boolean, default=False)
    oauth_connected = Column(Boolean, default=False)
    admin_connected = Column(Boolean, default=False)
    reauth_required = Column(Boolean, default=False)
    reauth_required_at = Column(DateTime, nullable=True)
    reauth_reason = Column(Text, nullable=True)

