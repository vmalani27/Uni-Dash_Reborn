
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from app.utils.firebase_util import verify_firebase_token
from sqlalchemy.orm import Session
from app.models.gmail.gmail_message import GmailSyncStatus
from app.services.gmail_service import GmailService
from app.services.sync_event_bus import (
    publish_pipeline_event,
    is_sync_locked,
    acquire_sync_lock,
    release_sync_lock,
)
from app.core.database import get_supabase_db
from app.utils.timezone_util import format_ist_datetime
import datetime

router = APIRouter()

@router.post("/gmail/sync")
def trigger_gmail_sync(background_tasks: BackgroundTasks, db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Trigger a full Gmail sync for the authenticated user.
    UID is derived from Firebase token, not from the URL.
    
    Returns HTTP 409 if sync is already in progress (prevents duplicate syncs).
    """
    uid = firebase_data["uid"]
    
    # Check if sync is already running (distributed lock)
    if is_sync_locked(uid):
        raise HTTPException(
            status_code=409,
            detail="Sync already in progress for this user. Please wait or try again later.",
        )
    
    # Try to acquire lock
    if not acquire_sync_lock(uid, ttl=600):
        raise HTTPException(
            status_code=409,
            detail="Could not acquire sync lock. Another sync may be starting.",
        )
    
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
    publish_pipeline_event(db, uid, source="route_full_sync_started")

    # Create database session for background task
    def run_sync():
        supabase_db = None
        try:
            from app.core.database import SupabaseSessionLocal
            supabase_db = SupabaseSessionLocal()
            GmailService.full_sync(uid, supabase_db, limit=500)
            # After full sync, capture latest historyId
            GmailService.capture_history_id(uid, supabase_db)
            # Mark sync as completed
            status = supabase_db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
            now = datetime.datetime.utcnow()
            if status:
                status.status = "completed"
                status.finished_at = now
                status.error_message = None
                supabase_db.commit()
                publish_pipeline_event(supabase_db, uid, source="route_full_sync_completed")
        except Exception as e:
            # Mark sync as failed
            status = supabase_db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first() if supabase_db else None
            now = datetime.datetime.utcnow()
            if status:
                status.status = "failed"
                status.finished_at = now
                status.error_message = str(e)
                supabase_db.commit()
                publish_pipeline_event(supabase_db, uid, source="route_full_sync_failed")
            raise
        finally:
            if supabase_db:
                supabase_db.close()
            # Always release lock (even on error)
            release_sync_lock(uid)

    background_tasks.add_task(run_sync)
    return {"message": "Sync started"}

@router.get("/gmail/sync/status")
def get_gmail_sync_status(db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Get Gmail sync status for the authenticated user.
    UID is derived from Firebase token.
    """
    uid = firebase_data["uid"]
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

@router.post("/gmail/sync/incremental")
def trigger_incremental_gmail_sync(background_tasks: BackgroundTasks, db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Trigger incremental Gmail sync for the authenticated user.
    UID is derived from Firebase token.
    
    Status lifecycle is owned by GmailService.incremental_sync():
    - Sets in_progress when starting
    - Sets completed/failed/no_action when done
    """
    uid = firebase_data["uid"]

    def run_incremental_sync():
        supabase_db = None
        try:
            from app.core.database import SupabaseSessionLocal
            supabase_db = SupabaseSessionLocal()
            GmailService.incremental_sync(uid, supabase_db, 50)
        except Exception as e:
            print(f"[INCREMENTAL SYNC ROUTE] Error: {e}")
            # incremental_sync already marks status as failed internally
        finally:
            if supabase_db:
                supabase_db.close()

    background_tasks.add_task(run_incremental_sync)
    return {"message": "Incremental sync started"}

@router.get("/gmail/sync/stats")
def get_gmail_sync_stats(db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Get detailed Gmail sync statistics for the authenticated user.
    UID is derived from Firebase token.
    """
    uid = firebase_data["uid"]
    """Get detailed sync statistics"""
    from app.models.gmail.gmail_message import GmailMessage
    
    status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    if not status:
        raise HTTPException(status_code=404, detail="No sync status found")
    
    total_emails = db.query(GmailMessage).filter(GmailMessage.uid == uid).count()
    
    return {
        "uid": status.uid,
        "status": status.status,
        "last_sync_date": format_ist_datetime(status.last_sync_date),
        "total_messages_synced": status.total_messages_synced or 0,
        "total_messages_stored": total_emails,
        "sync_type": status.sync_type or 'full',
        "has_more_pages": bool(status.next_page_token),
        "started_at": format_ist_datetime(status.started_at),
        "finished_at": format_ist_datetime(status.finished_at),
        "error_message": status.error_message,
    }

@router.get("/gmail/messages")
def get_gmail_messages(db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token), limit: int = 50, offset: int = 0, order: str = "desc"):
    """
    Fetch paginated Gmail messages for the authenticated user.
    UID is derived from Firebase token.
    Use order='desc' for latest, 'asc' for oldest.
    """
    uid = firebase_data["uid"]
    """Fetch paginated Gmail messages for a user. Use order='desc' for latest, 'asc' for oldest."""
    from app.models.gmail.gmail_message import GmailMessage
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
            "ai_summary": m.ai_summary,
            "ai_label_topic": m.ai_label_topic,
            "ai_label_urgency": m.ai_label_urgency,
            "ai_label_source": m.ai_label_source,
            "ai_processed": m.ai_processed,
            "deadline_iso": m.deadline_iso.isoformat() if m.deadline_iso else None,
            "deadline_confidence": m.deadline_confidence,
            "academic_score": m.academic_score,
        }
        for m in messages
    ]