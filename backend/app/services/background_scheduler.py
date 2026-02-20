"""
Background Scheduler — Autonomous ingestion and AI processing loops.

Two asyncio tasks run inside FastAPI's lifespan:
1. ingestion_loop: Pulls new Gmail messages every 3 minutes for all OAuth-connected users
2. ai_processing_loop: Continuously processes unclassified emails (1.5s delay between each)

Both reuse existing GmailService and AIService — no new logic, just autonomous scheduling.
"""

import asyncio
import time
import traceback
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


# ─── Ingestion Loop ─────────────────────────────────────────

async def ingestion_loop():
    """
    Every INGESTION_INTERVAL_SECONDS, pull new emails for all users
    who have an OAuth token (i.e., connected Gmail).
    """
    global _start_time
    _start_time = time.time()
    
    # Let server fully start before first run
    await asyncio.sleep(STARTUP_DELAY_SECONDS)
    print(f"[INGESTION] Background ingestion loop started (interval: {INGESTION_INTERVAL_SECONDS}s)")

    while True:
        try:
            # Import here to avoid circular imports at module load
            from app.core.database import SupabaseSessionLocal
            from app.models.oauthToken import OAuthToken
            from app.services.gmail_service import GmailService

            db = SupabaseSessionLocal()
            try:
                # Get all users with OAuth tokens
                users = db.query(OAuthToken.uid).all()
                uids = [u.uid for u in users]
                print(f"[INGESTION] Running for {len(uids)} user(s) at {datetime.utcnow().isoformat()}")

                for uid in uids:
                    user_db = SupabaseSessionLocal()
                    try:
                        GmailService.incremental_sync(uid, user_db, limit=50)
                        print(f"[INGESTION] ✓ Synced user {uid[:8]}…")
                    except Exception as e:
                        print(f"[INGESTION] ✗ Failed for user {uid[:8]}…: {e}")
                    finally:
                        user_db.close()

            finally:
                db.close()

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
    # Wait a bit longer than ingestion so initial emails land first
    await asyncio.sleep(STARTUP_DELAY_SECONDS + 5)
    print(f"[AI_WORKER] Background AI processing loop started (delay: {AI_LOOP_DELAY_SECONDS}s)")

    while True:
        try:
            from app.core.database import SupabaseSessionLocal
            from app.models.gmail.gmail_message import GmailMessage
            from app.models.oauthToken import OAuthToken
            from app.services.ai_service import AIService

            db = SupabaseSessionLocal()
            try:
                # Skip if no users have connected Gmail yet
                user_count = db.query(OAuthToken.uid).count()
                if user_count == 0:
                    db.close()
                    await asyncio.sleep(60)
                    continue

                # Get one unprocessed email
                message = (
                    db.query(GmailMessage)
                    .filter(GmailMessage.ai_processed == False)
                    .order_by(GmailMessage.internal_date.desc())  # newest first
                    .first()
                )

                if message is None:
                    # Nothing to process — sleep longer
                    db.close()
                    await asyncio.sleep(10)
                    continue

                print(f"[AI_WORKER] Processing: {message.gmail_id} | {message.subject[:50]}…")

                try:
                    AIService.run_email_inference(message, db)
                    print(f"[AI_WORKER] ✓ Classified: {message.gmail_id} → {message.normalized_topic}")
                except Exception as e:
                    print(f"[AI_WORKER] ✗ Failed: {message.gmail_id}: {e}")
                    # Mark as processed so it doesn't block the queue
                    try:
                        message.ai_processed = True
                        message.normalized_topic = "UNCLASSIFIED"
                        message.ai_summary = f"Classification failed: {str(e)[:100]}"
                        db.commit()
                    except Exception:
                        db.rollback()

            finally:
                db.close()

        except Exception as e:
            print(f"[AI_WORKER] Loop error: {e}")
            traceback.print_exc()

        await asyncio.sleep(AI_LOOP_DELAY_SECONDS)
