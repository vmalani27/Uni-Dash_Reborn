# GmailSyncStatus model for tracking Gmail sync progress and state per user.
# Why: Enables robust, incremental, and resumable Gmail syncs with error tracking.
from sqlalchemy import Column, String, DateTime, Text, Integer
from app.core.database import Base
import datetime

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
    watch_expiration = Column(DateTime, default=None)   # When Gmail Pub/Sub watch expires (renew before this time)
