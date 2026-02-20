
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.orm import Session
from app.core.database import get_supabase_db
from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage
from app.utils.firebase_util import verify_firebase_token
from app.utils.timezone_util import format_ist_datetime
from app.services.gmail_service import get_paginated_messages, get_message_detail
import re
import unicodedata

# Safe normalization for email body text
def normalize_email_text(text: str) -> str:
    if not text:
        return ""
    text = str(text)
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"[\u200b\u200c\u200d\ufeff]", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


router = APIRouter(prefix="/notifications", tags=["Notifications"])
@router.get("/gmail/list-all")
def list_gmail_notifications(
    offset: int = Query(0, ge=0, description="Number of items to skip (0-based)"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    include_stats: bool = Query(False, description="Include pagination stats"),
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    
    # Convert offset to page (page is 1-based, offset is 0-based)
    page = (offset // limit) + 1
    
    # Get paginated messages using the service function
    messages, total = get_paginated_messages(uid, db, page, limit)
        
    notifications = [
        {
            "id": m.id,
            "gmail_id": m.gmail_id,
            "sender": m.sender,
            "subject": m.subject,
            "snippet": m.snippet,
            "internal_date": format_ist_datetime(m.internal_date),
            "normalized_topic": m.normalized_topic,
            "academic_score": m.academic_score,
        }
        for m in messages
    ]
    
    response = {"notifications": notifications}
    
    # Include pagination metadata if requested
    if include_stats:
        offset = (page - 1) * limit
        response["pagination"] = {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
            "has_previous": page > 1,
            "has_next": offset + limit < total,
            "showing": len(notifications)
        }
    
    return response

# Endpoint: Get full mail detail (for mail view)
@router.get("/gmail/get-mail/{gmail_id}")
def get_gmail_message_detail(
    gmail_id: str,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    message = get_message_detail(uid, gmail_id, db)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    mail_detail = {
        "id": message.id,
        "gmail_id": message.gmail_id,
        "thread_id": message.thread_id,
        "sender": message.sender,
        "subject": message.subject,
        "body_html": message.body_html,
        "body_text": normalize_email_text(message.body_text),
        "internal_date": format_ist_datetime(message.internal_date),
    }
    return mail_detail

@router.post("/gmail/sync")
def trigger_gmail_sync(
    background_tasks: BackgroundTasks,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    # Sync is now triggered via /gmail/sync/{uid} endpoint only
    return {"status": "no automatic sync; use /gmail/sync/{uid}"}


@router.post("/gmail/classify-all")
def classify_all_emails(
    background_tasks: BackgroundTasks,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Bulk classify all unprocessed emails for the user.
    
    This endpoint:
    - Finds all emails where ai_processed = False
    - Queues them for AI inference (max 200 to avoid rate limits)
    - Runs background job to populate normalized_topic and academic_score
    - Returns immediate status
    """
    uid = firebase_data["uid"]
    
    # Count unprocessed emails
    unprocessed_count = db.query(GmailMessage).filter(
        GmailMessage.uid == uid,
        GmailMessage.ai_processed == False
    ).count()
    
    if unprocessed_count == 0:
        return {
            "status": "completed",
            "message": "All emails already classified",
            "processed": 0,
            "total": 0
        }
    
    # Limit to last 200 emails to avoid rate limits
    limit = min(unprocessed_count, 200)
    
    # Queue background job
    background_tasks.add_task(
        _classify_emails_background,
        uid=uid,
        limit=limit
    )
    
    return {
        "status": "in_progress",
        "message": f"Started classifying {limit} emails",
        "total_unprocessed": unprocessed_count,
        "will_process": limit
    }


def _classify_emails_background(uid: str, limit: int):
    """
    Background job to classify emails.
    Processes in batches with delays between LLM calls to respect rate limits.
    Creates its own database session since the request session will be closed.
    """
    import time
    from app.services.ai_service import AIService
    from app.core.database import SupabaseSessionLocal
    
    print(f"[CLASSIFY] Starting bulk classification for uid={uid}, limit={limit}")
    
    # Create fresh database session for background job
    db_session = SupabaseSessionLocal()
    
    try:
        # Fetch unprocessed emails ordered by most recent first
        messages = db_session.query(GmailMessage).filter(
            GmailMessage.uid == uid,
            GmailMessage.ai_processed == False
        ).order_by(GmailMessage.internal_date.desc()).limit(limit).all()
        
        print(f"[CLASSIFY] Found {len(messages)} messages to process")
        
        processed = 0
        failed = 0
        
        for i, message in enumerate(messages):
            try:
                print(f"[CLASSIFY] Processing {i+1}/{len(messages)}: {message.gmail_id}")
                AIService.run_email_inference(message, db_session)
                processed += 1
            except Exception as e:
                print(f"[CLASSIFY] Failed to process {message.gmail_id}: {e}")
                failed += 1
                # Mark as processed so it doesn't block completion status
                try:
                    message.ai_processed = True
                    message.normalized_topic = "UNCLASSIFIED"
                    message.ai_summary = f"Classification failed: {str(e)[:100]}"
                    db_session.commit()
                except:
                    db_session.rollback()
            
            # Delay between calls to respect Ollama rate limits (1 call per second)
            if i < len(messages) - 1:
                time.sleep(1)
        
        print(f"[CLASSIFY] Completed: {processed} processed, {failed} failed")
        return {
            "processed": processed,
            "failed": failed,
            "total": len(messages)
        }
    finally:
        db_session.close()


@router.get("/gmail/classify-status")
def get_classify_status(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Get current classification progress.
    Tracks progress relative to the batch size (max 200).
    """
    uid = firebase_data["uid"]

    # Count remaining unprocessed emails
    unprocessed_count = db.query(GmailMessage).filter(
        GmailMessage.uid == uid,
        GmailMessage.ai_processed == False
    ).count()

    # Total emails eligible for classification (max 200)
    total_emails = db.query(GmailMessage).filter(
        GmailMessage.uid == uid
    ).count()

    total_to_process = min(total_emails, 200)

    # Calculate how many processed in this batch
    # = (total batch size) - (remaining unprocessed in batch)
    processed_this_run = total_to_process - min(unprocessed_count, total_to_process)

    if unprocessed_count == 0:
        status = "completed"
    elif processed_this_run > 0:
        status = "running"
    else:
        status = "pending"

    return {
        "status": status,
        "processed": max(processed_this_run, 0),
        "total": total_to_process,
        "unprocessed_remaining": unprocessed_count
    }
