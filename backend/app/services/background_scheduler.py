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
AI_LOOP_DELAY_SECONDS = 5.0       # delay between AI batch inferences
AI_BATCH_SIZE = 10                # number of emails to process at once
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


def _process_batch_emails():
    """
    Blocking: picks a batch of unprocessed emails and runs AI inference.
    Returns: List of (gmail_id, topic) on success, empty list if nothing to process.
    """
    from app.core.database import SupabaseSessionLocal
    from app.models.gmail.gmail_message import GmailMessage
    from app.services.ai_service import AIService

    db = SupabaseSessionLocal()
    try:
        messages = (
            db.query(GmailMessage)
            .filter(
                (GmailMessage.ai_status == None) |
                (GmailMessage.ai_status == "pending") |
                (GmailMessage.ai_status == "failed")
            )
            .order_by(GmailMessage.created_at.asc())
            .limit(AI_BATCH_SIZE)
            .with_for_update(skip_locked=True)
            .all()
        )

        if not messages:
            return []

        # Lock them all
        for msg in messages:
            msg.ai_status = "processing"
        db.commit()

        print(f"[AI_WORKER] Processing batch of {len(messages)} email(s)...")

        try:
            results_map = AIService.run_batch_email_inference(messages, db)
            db.commit()
            
            summary = [m.gmail_id for m in messages if m.ai_processed]
            if summary:
                print(f"[AI_WORKER] Batch completed: {len(summary)} succeeded.")
            return summary

        except Exception as e:
            print(f"[AI_WORKER] Batch failed: {e}")
            db.rollback()
            return []

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

            sem = asyncio.Semaphore(5)

            async def bounded_sync(uid):
                async with sem:
                    try:
                        await asyncio.to_thread(_sync_user, uid)
                        print(f"[INGESTION] Synced user {uid[:8]}…")
                    except Exception as e:
                        print(f"[INGESTION] Failed for user {uid[:8]}…: {e}")

            if uids:
                await asyncio.gather(*(bounded_sync(uid) for uid in uids))

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

            result = await asyncio.to_thread(_process_batch_emails)

            if not result:
                # Nothing to process — sleep longer
                await asyncio.sleep(15)
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
