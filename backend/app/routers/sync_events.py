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
    
    If the current status is already terminal (completed/failed/no_action),
    the stream enters a waiting window (~30s) to catch a new sync that's
    about to be triggered by the frontend. If no new sync starts within
    the window, the stream closes gracefully.
    """
    uid = firebase_data["uid"]

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
                "new_messages_count": status.new_messages_count or 0 if status.status == "completed" else 0,
            }
            print(f"[SSE] Initial status for {uid}: {data}")
            yield f"data: {json.dumps(data)}\n\n"
        
        # If initial status is terminal, wait for a new sync to start
        if last_status in ["completed", "failed", "no_action", None]:
            print(f"[SSE] Status is '{last_status}', entering waiting window for new sync...")
            waited = 0
            max_wait = 30  # 30 seconds max
            
            while waited < max_wait:
                await asyncio.sleep(0.5)
                waited += 0.5
                db.expire_all()
                status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
                
                if not status:
                    continue
                
                # Check if status changed to in_progress (new sync started)
                if status.status == "in_progress":
                    print(f"[SSE] New sync detected (in_progress), switching to active monitoring")
                    last_status = status.status
                    last_finished_at = status.finished_at
                    data = {
                        "status": "in_progress",
                        "finished_at": None,
                    }
                    yield f"data: {json.dumps(data)}\n\n"
                    break
                
                # Check if finished_at changed (sync completed between polls)
                if status.finished_at != last_finished_at:
                    last_status = status.status
                    last_finished_at = status.finished_at
                    data = {
                        "status": status.status,
                        "finished_at": status.finished_at.isoformat() if status.finished_at else None,
                        "new_messages_count": status.new_messages_count or 0 if status.status == "completed" else 0,
                    }
                    print(f"[SSE] Status changed during wait: {data}")
                    yield f"data: {json.dumps(data)}\n\n"
                    
                    # If it completed during wait, we're done
                    if status.status in ["completed", "failed", "no_action"]:
                        print(f"[SSE] Sync completed during wait window, closing.")
                        yield f"data: {json.dumps({'status': 'stream_closed'})}\n\n"
                        return
            else:
                # Timeout — no new sync started
                print(f"[SSE] Waiting window expired, no new sync started. Closing stream.")
                yield f"data: {json.dumps({'status': 'stream_closed'})}\n\n"
                return
        
        # Active sync monitoring: poll until terminal status
        while True:
            await asyncio.sleep(0.5)
            db.expire_all()
            status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
            
            if not status:
                continue
            
            # Send update if status or finished_at changed
            if status.status != last_status or status.finished_at != last_finished_at:
                last_status = status.status
                last_finished_at = status.finished_at
                data = {
                    "status": status.status,
                    "finished_at": status.finished_at.isoformat() if status.finished_at else None,
                    "new_messages_count": status.new_messages_count or 0 if status.status == "completed" else 0,
                }
                print(f"[SSE] Status update: {data}")
                yield f"data: {json.dumps(data)}\n\n"
            
            # Terminal status reached — close stream
            if status.status in ["completed", "failed", "no_action"]:
                print(f"[SSE] Terminal status: {status.status}, closing stream.")
                break
        
        yield f"data: {json.dumps({'status': 'stream_closed'})}\n\n"
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )
