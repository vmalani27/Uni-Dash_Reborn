from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.core.database import get_supabase_db
from app.models.gmail.gmail_message import GmailSyncStatus
from app.utils.firebase_util import verify_firebase_token
import asyncio
import json

router = APIRouter(tags=["Sync Events"])

@router.get("/gmail/sync/stream")
async def stream_sync_status(db: Session = Depends(get_supabase_db), firebase_data=Depends(verify_firebase_token)):
    """
    Server-Sent Events endpoint for real-time sync status updates.
    Frontend subscribes to this and receives updates when sync status changes.
    UID is derived from Firebase token.
    """
    uid = firebase_data["uid"]
    """
    Server-Sent Events endpoint for real-time sync status updates.
    Frontend subscribes to this and receives updates when sync status changes.
    """
    async def event_generator():
        last_status = None
        last_finished_at = None
        
        # Send initial status
        status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
        if status:
            last_status = status.status
            last_finished_at = status.finished_at
            data = {
                "status": status.status,
                "finished_at": status.finished_at.isoformat() if status.finished_at else None,
            }
            yield f"data: {json.dumps(data)}\n\n"
        
        # Poll for changes every 500ms until terminal status is reached
        while True:
            await asyncio.sleep(0.5)
            db.expire_all()
            status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
            print(f"[SSE DEBUG] Polled sync status for {uid}: {status.status if status else 'None'}")
            if not status:
                continue
            # Send update if status changed or finished_at changed
            if status.status != last_status or status.finished_at != last_finished_at:
                last_status = status.status
                last_finished_at = status.finished_at
                data = {
                    "status": status.status,
                    "finished_at": status.finished_at.isoformat() if status.finished_at else None,
                    "new_messages_count": getattr(status, 'new_messages_count', 0) if status.status == "completed" else 0,
                }
                print(f"[SSE DEBUG] Sending status update: {data}")
                yield f"data: {json.dumps(data)}\n\n"
            # If sync completed, failed, or no_action, close the stream
            if status.status in ["completed", "failed", "no_action"]:
                print(f"[SSE DEBUG] Terminal status reached: {status.status}, closing stream.")
                break
        # Send final close message
        yield f"data: {json.dumps({'status': 'stream_closed'})}\n\n"
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        }
    )
