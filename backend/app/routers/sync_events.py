from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.core.database import get_supabase_db
from app.models.gmail.gmail_message import GmailSyncStatus
from app.services.sync_event_bus import (
    build_pipeline_payload,
    channel_for_uid,
    get_async_redis_client,
)
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

    try:
        redis_client = get_async_redis_client()
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Redis unavailable for sync stream: {exc}",
        ) from exc

    async def event_generator():
        last_payload = None
        
        # Send initial status
        status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
        data = build_pipeline_payload(db, uid)
        last_payload = data
        yield f"data: {json.dumps(data)}\n\n"

        if data["pipeline_complete"] or data["status"] == "failed":
            yield f"data: {json.dumps({'status': 'stream_closed'})}\n\n"
            return

        pubsub = redis_client.pubsub()
        await pubsub.subscribe(channel_for_uid(uid))
        print(f"[SSE] Subscribed to Redis channel {channel_for_uid(uid)}")
        try:
            while True:
                message = await pubsub.get_message(
                    ignore_subscribe_messages=True,
                    timeout=30.0,
                )

                if message is None:
                    await asyncio.sleep(0.1)
                    continue

                try:
                    payload = json.loads(message["data"])
                except Exception:
                    continue

                if payload != last_payload:
                    last_payload = payload
                    print(f"[SSE DEBUG] Sending redis update: {payload}")
                    yield f"data: {json.dumps(payload)}\n\n"

                if payload.get("pipeline_complete") or payload.get("status") == "failed":
                    print(f"[SSE DEBUG] Terminal pipeline state reached (redis): {payload}")
                    break
        finally:
            await pubsub.unsubscribe(channel_for_uid(uid))
            await pubsub.close()

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
