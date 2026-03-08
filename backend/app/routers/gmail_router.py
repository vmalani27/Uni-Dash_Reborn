
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.responses import StreamingResponse
import asyncio
import json
import datetime

from app.core.database import get_supabase_db
from app.utils.firebase_util import verify_firebase_token
from app.utils.timezone_util import format_ist_datetime
from app.models.gmail.gmail_message import GmailMessage, GmailSyncStatus
from app.models.oauthToken import OAuthToken
from app.services.gmail_service import GmailService
from app.services.ai_service import AIService

router = APIRouter()

@router.post("/gmail/sync")
def trigger_gmail_sync(background_tasks: BackgroundTasks, db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Trigger a full Gmail sync for the authenticated user.
    UID is derived from Firebase token, not from the URL.
    """
    uid = firebase_data["uid"]
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

    # Create database session for background task
    def run_sync():
        supabase_db = None
        try:
            from app.core.database import SupabaseSessionLocal
            supabase_db = SupabaseSessionLocal()
            GmailService.full_sync(uid, supabase_db)
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
        except Exception as e:
            # Mark sync as failed
            status = supabase_db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first() if supabase_db else None
            now = datetime.datetime.utcnow()
            if status:
                status.status = "failed"
                status.finished_at = now
                status.error_message = str(e)
                supabase_db.commit()
            raise
        finally:
            if supabase_db:
                supabase_db.close()

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
    This is fire-and-forget - returns immediately without waiting.
    UID is derived from Firebase token.
    """
    uid = firebase_data["uid"]

    # Fire-and-forget background task
    def run_incremental_sync():
        supabase_db = None
        try:
            from app.core.database import SupabaseSessionLocal
            supabase_db = SupabaseSessionLocal()
            GmailService.incremental_sync(uid, supabase_db, 50)
        except Exception as e:
            print(f"[INCREMENTAL SYNC BG TASK] Error for {uid}: {e}")
        finally:
            if supabase_db:
                supabase_db.close()

    background_tasks.add_task(run_incremental_sync)
    return {"status": "sync_started"}

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
    
    # Get user's email to filter out messages sent by themselves
    user_oauth = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    user_email = user_oauth.email if user_oauth else None
    
    # Count total emails, excluding messages sent by the user
    total_query = db.query(GmailMessage).filter(GmailMessage.uid == uid)
    if user_email:
        total_query = total_query.filter(~GmailMessage.sender.contains(user_email))
    total_emails = total_query.count()
    
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
    
    # Get user's email to filter out messages sent by themselves
    user_oauth = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    user_email = user_oauth.email if user_oauth else None
    
    # Build query to filter out messages sent by the user
    query = db.query(GmailMessage).filter(GmailMessage.uid == uid)
    if user_email:
        query = query.filter(~GmailMessage.sender.contains(user_email))
    
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

@router.get("/gmail/{gmail_id}")
def get_gmail_message(gmail_id: str, background_tasks: BackgroundTasks, db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Get a specific Gmail message for the authenticated user.
    Returns immediately with available data, triggers AI inference in background if needed.
    UID is derived from Firebase token.
    """
    uid = firebase_data["uid"]
    from app.models.gmail.gmail_message import GmailMessage

    # Get the email message
    message = db.query(GmailMessage).filter(
        GmailMessage.uid == uid,
        GmailMessage.gmail_id == gmail_id
    ).first()

    if not message:
        raise HTTPException(status_code=404, detail="Email not found")

    if message.ai_processed:
        print(f"[/gmail/{gmail_id}] Message already processed.")
    else:
        print(f"[/gmail/{gmail_id}] Message is pending processing by the background worker.")

    # Return email data immediately (AI data may be None if not processed yet)
    return {
        "id": message.id,
        "gmail_id": message.gmail_id,
        "thread_id": message.thread_id,
        "sender": message.sender,
        "subject": message.subject,
        "snippet": message.snippet,
        "body_text": message.body_text,
        "body_html": message.body_html,
        "internal_date": message.internal_date,
        "ai_summary": message.ai_summary,
        "ai_label_topic": message.ai_label_topic,
        "ai_label_urgency": message.ai_label_urgency,
        "ai_label_source": message.ai_label_source,
        "ai_processed": message.ai_processed,
        "deadline_iso": message.deadline_iso.isoformat() if message.deadline_iso else None,
        "deadline_confidence": message.deadline_confidence,
        "academic_score": message.academic_score,
    }

@router.post("/gmail/{gmail_id}/infer")
def infer_email_ai(gmail_id: str, db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Run AI inference on a specific email for the authenticated user.
    Updates the email with AI-generated summary, topic label, urgency, and source classification.
    """
    uid = firebase_data["uid"]
    from app.models.gmail.gmail_message import GmailMessage

    # Get the email message
    message = db.query(GmailMessage).filter(
        GmailMessage.uid == uid,
        GmailMessage.gmail_id == gmail_id
    ).first()

    if not message:
        raise HTTPException(status_code=404, detail="Email not found")

    # Run AI inference
    try:
        ai_result = AIService.run_email_inference(message)
        db.commit()
        return {
            "gmail_id": gmail_id,
            "ai_summary": ai_result.get("summary"),
            "ai_label_topic": ai_result.get("topic"),
            "ai_label_urgency": ai_result.get("urgency"),
            "ai_label_source": ai_result.get("source"),
            "ai_processed": True,
            "deadline_iso": ai_result.get("deadline_iso"),
            "deadline_confidence": ai_result.get("deadline_confidence"),
            "academic_score": message.academic_score
        }
    except Exception as e:
        db.commit() # Commit the 'failed' status or any partial changes before raising 500
        raise HTTPException(status_code=500, detail=f"AI inference failed: {str(e)}")


@router.get("/gmail/{gmail_id}/ai/stream")
async def stream_ai_updates(gmail_id: str, db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Server-Sent Events endpoint for real-time AI inference updates.
    Frontend subscribes to this when opening an email to get AI results as they become available.
    """
    uid = firebase_data["uid"]
    print(f"[AI STREAM] Starting stream for {gmail_id}, uid: {uid}")
    from app.models.gmail.gmail_message import GmailMessage

    # Check if message exists
    message = db.query(GmailMessage).filter(
        GmailMessage.uid == uid,
        GmailMessage.gmail_id == gmail_id
    ).first()

    if not message:
        print(f"[AI STREAM] Message {gmail_id} not found")
        return StreamingResponse(
            iter([f"data: {json.dumps({'error': 'Email not found'})}\n\n"]),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "Connection": "keep-alive"}
        )

    print(f"[AI STREAM] Message found, ai_processed: {message.ai_processed}")

    async def event_generator():
        # AI not processed yet, wait for updates
        yield f"data: {json.dumps({'status': 'processing'})}\n\n"

        # Give background task a moment to start
        await asyncio.sleep(1.0)

        # Poll for AI completion (max 30 seconds) using fresh database session
        for i in range(60):  # 60 * 0.5s = 30 seconds
            await asyncio.sleep(0.5)

            # Create fresh session for each poll to ensure we see committed changes
            temp_db = None
            try:
                from app.core.database import SupabaseSessionLocal
                temp_db = SupabaseSessionLocal()
                
                updated_message = temp_db.query(GmailMessage).filter(
                    GmailMessage.uid == uid,
                    GmailMessage.gmail_id == gmail_id
                ).first()

                if updated_message and updated_message.ai_processed:
                    print(f"[AI STREAM] Found completed AI for {gmail_id} on poll {i+1}")
                    data = {
                        "status": "completed",
                        "ai_summary": updated_message.ai_summary,
                        "ai_label_topic": updated_message.ai_label_topic,
                        "ai_label_urgency": updated_message.ai_label_urgency,
                        "ai_label_source": updated_message.ai_label_source,
                        "deadline_iso": updated_message.deadline_iso.isoformat() if updated_message.deadline_iso else None,
                        "deadline_confidence": updated_message.deadline_confidence,
                        "academic_score": updated_message.academic_score,
                    }
                    yield f"data: {json.dumps(data)}\n\n"
                    return
                    
                if i % 10 == 0:  # Log every 5 seconds
                    status = updated_message.ai_processed if updated_message else "message_not_found"
                    print(f"[AI STREAM] Still polling for {gmail_id}, attempt {i+1}/60, ai_processed={status}")
                    
            finally:
                if temp_db:
                    temp_db.close()

        # Timeout - AI still processing
        print(f"[AI STREAM] Timeout waiting for AI completion for {gmail_id}")
        yield f"data: {json.dumps({'status': 'timeout'})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )
