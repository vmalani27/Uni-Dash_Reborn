
import datetime

from sqlalchemy import Column, String, Boolean, Integer, DateTime, Text
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    uid = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True)
    full_name = Column(String, nullable=False)
    degree = Column(String, nullable=False)
    branch = Column(String, nullable=False)
    admission_year = Column(Integer, nullable=False)
    sid = Column(String, nullable=True)
    profile_completed = Column(Boolean, default=False)
    oauth_connected = Column(Boolean, default=False)
    admin_connected = Column(Boolean, default=False)
    reauth_required = Column(Boolean, default=False)
    reauth_required_at = Column(DateTime, nullable=True)
    reauth_reason = Column(Text, nullable=True)

