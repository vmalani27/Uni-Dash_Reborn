
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session
from app.models.gmail_sync_status import GmailSyncStatus
from app.services.gmail_sync import sync_gmail_for_user, sync_gmail_history_for_user
from app.core.database import get_local_db
import datetime

router = APIRouter()

@router.post("/gmail/sync/{uid}")
def trigger_gmail_sync(uid: str, background_tasks: BackgroundTasks, db: Session = Depends(get_local_db)):
    # Set status to in_progress
    status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    now = datetime.datetime.utcnow()
    if not status:
        status = GmailSyncStatus(uid=uid, status="in_progress", started_at=now, finished_at=None, error_message=None)
        db.add(status)
    else:
        status.status = "in_progress"
        status.started_at = now
        status.finished_at = None
        status.error_message = None
    db.commit()

    # Create separate database sessions for background task
    def run_sync():
        local_db = None
        supabase_db = None
        try:
            from app.core.database import LocalSessionLocal, SupabaseSessionLocal
            local_db = LocalSessionLocal()  # For gmail messages and sync status
            supabase_db = SupabaseSessionLocal()  # For oauth tokens only
            sync_gmail_for_user(uid, local_db, supabase_db)
            # After full sync, capture latest historyId
            from app.services.gmail_sync import capture_and_store_history_id
            capture_and_store_history_id(uid, local_db, supabase_db)
        finally:
            if local_db:
                local_db.close()
            if supabase_db:
                supabase_db.close()

    background_tasks.add_task(run_sync)
    return {"message": "Sync started"}

@router.get("/gmail/sync/status/{uid}")
def get_gmail_sync_status(uid: str, db: Session = Depends(get_local_db)):
    status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    if not status:
        raise HTTPException(status_code=404, detail="No sync status found for user")
    return {
        "uid": status.uid,
        "status": status.status,
        "started_at": status.started_at,
        "finished_at": status.finished_at,
        "error_message": status.error_message,
    }

@router.post("/gmail/sync/{uid}/incremental")
def trigger_incremental_gmail_sync(uid: str, background_tasks: BackgroundTasks, db: Session = Depends(get_local_db)):
    """Trigger incremental sync (only new emails since last sync)"""
    # Set status to in_progress
    status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    now = datetime.datetime.utcnow()
    if not status:
        status = GmailSyncStatus(uid=uid, status="in_progress", started_at=now, finished_at=None, error_message=None)
        db.add(status)
    else:
        status.status = "in_progress"
        status.started_at = now
        status.finished_at = None
        status.error_message = None
    db.commit()

    # Create separate database sessions for background task
    def run_incremental_sync():
        local_db = None
        supabase_db = None
        try:
            from app.core.database import LocalSessionLocal, SupabaseSessionLocal
            local_db = LocalSessionLocal()  # For gmail messages and sync status
            supabase_db = SupabaseSessionLocal()  # For oauth tokens only
            sync_gmail_history_for_user(uid, local_db, supabase_db, 50)  # Use history-based sync
        finally:
            if local_db:
                local_db.close()
            if supabase_db:
                supabase_db.close()

    background_tasks.add_task(run_incremental_sync)
    return {"message": "Incremental sync started"}

@router.get("/gmail/sync/stats/{uid}")
def get_gmail_sync_stats(uid: str, db: Session = Depends(get_local_db)):
    """Get detailed sync statistics"""
    from app.models.gmail_message import GmailMessage
    
    status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    if not status:
        raise HTTPException(status_code=404, detail="No sync status found")
    
    total_emails = db.query(GmailMessage).filter(GmailMessage.uid == uid).count()
    
    return {
        "uid": status.uid,
        "status": status.status,
        "last_sync_date": status.last_sync_date,
        "total_messages_synced": status.total_messages_synced or 0,
        "total_messages_stored": total_emails,
        "sync_type": status.sync_type or 'full',
        "has_more_pages": bool(status.next_page_token),
        "started_at": status.started_at,
        "finished_at": status.finished_at,
        "error_message": status.error_message,
    }

@router.get("/gmail/messages/{uid}")
def get_gmail_messages(uid: str, db: Session = Depends(get_local_db), limit: int = 50, offset: int = 0, order: str = "desc"):
    """Fetch paginated Gmail messages for a user. Use order='desc' for latest, 'asc' for oldest."""
    from app.models.gmail_message import GmailMessage
    query = db.query(GmailMessage).filter(GmailMessage.uid == uid)
    if order == "desc":
        query = query.order_by(GmailMessage.internal_date.desc())
    else:
        query = query.order_by(GmailMessage.internal_date.asc())
    messages = query.offset(offset).limit(limit).all()
    return [
        {
            "gmail_id": m.gmail_id,
            "thread_id": m.thread_id,
            "sender": m.sender,
            "subject": m.subject,
            "snippet": m.snippet,
            "body_text": m.body_text,
            "body_html": m.body_html,
            "internal_date": m.internal_date,
        }
        for m in messages
    ]