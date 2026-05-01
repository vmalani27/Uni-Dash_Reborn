from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from app.services.sync_event_bus import (
    channel_for_uid,
    get_async_redis_client,
    get_last_pipeline_payload,
)
from app.utils.firebase_util import verify_firebase_token
import asyncio
import json

router = APIRouter(tags=["Sync Events"])

@router.get("/gmail/sync/stream")
async def stream_sync_status(firebase_data=Depends(verify_firebase_token)):
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

        # Send initial status from Redis cache only (no DB session in SSE path).
        cached = get_last_pipeline_payload(uid)
        if cached is not None:
            last_payload = cached
            yield f"data: {json.dumps(cached)}\n\n"
        else:
            yield "data: {}\n\n"

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
                    # keep-alive event to prevent idle proxy disconnects
                    yield "data: {}\n\n"
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
        finally:
            await pubsub.unsubscribe(channel_for_uid(uid))
            await pubsub.close()
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        }
    )
