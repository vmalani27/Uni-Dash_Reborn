"""
Background Scheduler — Autonomous ingestion and AI processing loops.

Two asyncio tasks run inside FastAPI's lifespan:
1. ingestion_loop: Pulls new Gmail messages every 3 minutes for all OAuth-connected users
2. ai_processing_loop: Continuously processes unclassified emails (1.5s delay between each)

Both reuse existing GmailService and AIService — no new logic, just autonomous scheduling.
All blocking I/O is wrapped in asyncio.to_thread() to avoid blocking the event loop.
"""

import asyncio
import time
import traceback
import requests
from datetime import datetime


# ─── Config ──────────────────────────────────────────────────
INGESTION_INTERVAL_SECONDS = 180   # 3 minutes
AI_LOOP_DELAY_SECONDS = 1.5       # delay between AI inferences
STARTUP_DELAY_SECONDS = 10        # wait for app to fully start

_start_time = None


def get_uptime() -> int:
    """Return seconds since scheduler started."""
    if _start_time is None:
        return 0
    return int(time.time() - _start_time)


# ─── Blocking helpers (run in thread pool) ───────────────────

def _sync_user(uid: str, limit: int = 50):
    """Blocking: runs incremental_sync for one user in its own DB session."""
    from app.core.database import SupabaseSessionLocal
    from app.services.gmail_service import GmailService

    db = SupabaseSessionLocal()
    try:
        GmailService.incremental_sync(uid, db, limit=limit)
    finally:
        db.close()


def _process_one_email():
    """
    Blocking: picks one unprocessed email and runs AI inference.
    Returns: (gmail_id, topic) on success, None if nothing to process.
    Raises: ConnectionError/Timeout if Ollama is unreachable (retryable).
    """
    from app.core.database import SupabaseSessionLocal
    from app.models.gmail.gmail_message import GmailMessage
    from app.services.ai_service import AIService

    db = SupabaseSessionLocal()
    try:
        message = (
            db.query(GmailMessage)
            .filter(GmailMessage.ai_processed == False)
            .order_by(GmailMessage.internal_date.desc())
            .first()
        )

        if message is None:
            return None

        gmail_id = message.gmail_id
        subject = message.subject[:50] if message.subject else ""
        print(f"[AI_WORKER] Processing: {gmail_id} | {subject}…")

        try:
            AIService.run_email_inference(message, db)
            topic = message.normalized_topic
            print(f"[AI_WORKER] ✓ Classified: {gmail_id} → {topic}")
            return (gmail_id, topic)

        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout):
            # Ollama unreachable — don't mark as processed, will retry
            raise

        except Exception as e:
            print(f"[AI_WORKER] ✗ Failed: {gmail_id}: {e}")
            # Non-transient failure — mark as processed so it doesn't block queue
            try:
                message.ai_processed = True
                message.normalized_topic = "UNCLASSIFIED"
                message.ai_summary = f"Classification failed: {str(e)[:100]}"
                db.commit()
            except Exception:
                db.rollback()
            return (gmail_id, "UNCLASSIFIED")

    finally:
        db.close()


def _count_users():
    """Blocking: returns list of UIDs with OAuth tokens."""
    from app.core.database import SupabaseSessionLocal
    from app.models.oauthToken import OAuthToken

    db = SupabaseSessionLocal()
    try:
        users = db.query(OAuthToken.uid).all()
        return [u.uid for u in users]
    finally:
        db.close()


# ─── Ingestion Loop ─────────────────────────────────────────

async def ingestion_loop():
    """
    Every INGESTION_INTERVAL_SECONDS, pull new emails for all users
    who have an OAuth token (i.e., connected Gmail).
    """
    global _start_time
    _start_time = time.time()

    await asyncio.sleep(STARTUP_DELAY_SECONDS)
    print(f"[INGESTION] Background ingestion loop started (interval: {INGESTION_INTERVAL_SECONDS}s)")

    while True:
        try:
            uids = await asyncio.to_thread(_count_users)
            print(f"[INGESTION] Running for {len(uids)} user(s) at {datetime.utcnow().isoformat()}")

            for uid in uids:
                try:
                    await asyncio.to_thread(_sync_user, uid)
                    print(f"[INGESTION] ✓ Synced user {uid[:8]}…")
                except Exception as e:
                    print(f"[INGESTION] ✗ Failed for user {uid[:8]}…: {e}")

        except Exception as e:
            print(f"[INGESTION] Loop error: {e}")
            traceback.print_exc()

        await asyncio.sleep(INGESTION_INTERVAL_SECONDS)


# ─── AI Processing Loop ─────────────────────────────────────

async def ai_processing_loop():
    """
    Continuously process unclassified emails, one at a time.
    Sleeps AI_LOOP_DELAY_SECONDS between each inference.
    """
    await asyncio.sleep(STARTUP_DELAY_SECONDS + 5)
    print(f"[AI_WORKER] Background AI processing loop started (delay: {AI_LOOP_DELAY_SECONDS}s)")

    while True:
        try:
            # Skip if no users have connected Gmail yet
            uids = await asyncio.to_thread(_count_users)
            if len(uids) == 0:
                await asyncio.sleep(60)
                continue

            result = await asyncio.to_thread(_process_one_email)

            if result is None:
                # Nothing to process — sleep longer
                await asyncio.sleep(10)
                continue

        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            # Ollama unreachable — back off and retry
            print(f"[AI_WORKER] Ollama unreachable, retrying in 30s: {e}")
            await asyncio.sleep(30)
            continue

        except Exception as e:
            print(f"[AI_WORKER] Loop error: {e}")
            traceback.print_exc()

        await asyncio.sleep(AI_LOOP_DELAY_SECONDS)
