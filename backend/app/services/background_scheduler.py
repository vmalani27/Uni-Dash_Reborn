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
from datetime import datetime, timezone, timedelta
from sqlalchemy import func
from sqlalchemy.exc import OperationalError


# ─── Config ──────────────────────────────────────────────────
INGESTION_INTERVAL_SECONDS = 180   # 3 minutes
AI_LOOP_DELAY_SECONDS = 5.0       # delay between AI batch inferences
AI_BATCH_SIZE = 5                 # number of emails to process at once (was 10, reduced for token limit)
STARTUP_DELAY_SECONDS = 10        # wait for app to fully start

_start_time = None

# Worker tracking
_worker_status = {
    "ingestion": {
        "last_run": None,
        "last_error": None,
        "total_synced": 0,
        "total_processed": 0,
        "total_updates": 0,
        "status": "not_started"
    },
    "ai_processing": {
        "last_run": None,
        "last_error": None,
        "total_synced": 0,
        "total_processed": 0,
        "total_updates": 0,
        "status": "not_started"
    },
    "domain_stats": {
        "last_run": None,
        "last_error": None,
        "total_synced": 0,
        "total_processed": 0,
        "total_updates": 0,
        "status": "not_started"
    }
}


def get_uptime() -> int:
    """Return seconds since scheduler started."""
    if _start_time is None:
        return 0
    return int(time.time() - _start_time)


def get_worker_status() -> dict:
    """Return real-time status of all background workers."""
    status = {}
    for worker_name, data in _worker_status.items():
        last_run = data["last_run"]
        seconds_since = None
        if last_run:
            seconds_since = int((datetime.now(timezone.utc) - last_run).total_seconds())
        
        status[worker_name] = {
            "status": data["status"],
            "last_run": last_run.isoformat() if last_run else None,
            "seconds_since_last_run": seconds_since,
            "total_processed": data["total_processed"],
            "total_synced": data["total_synced"],
            "total_updates": data["total_updates"],
            "last_error": data["last_error"]
        }
    
    return {
        "uptime_seconds": get_uptime(),
        "workers": status
    }


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

        print(f"[AI_WORKER] Processing up to {len(messages)} email(s) sequentially...")

        succeeded = []
        try:
            for msg in messages:
                try:
                    # run single-email inference; this function updates the msg object fields
                    result = AIService.run_email_inference(msg)
                    # Persist AI fields
                    db.commit()

                    # Use AcademicContextEngine to create objects from the deep analysis (120B)
                    try:
                        from app.services.academic_context_engine import AcademicContextEngine
                        parsed_payload = result.get("parsed_payload", {})
                        # Pass DB session so engine can persist AcademicItem and FollowUps
                        AcademicContextEngine.process_academic_objects(msg, parsed_payload, db)
                        db.commit()
                    except Exception as e_obj:
                        print(f"[AI_WORKER] Object factory failed for {msg.gmail_id}: {e_obj}")

                    succeeded.append(msg.gmail_id)
                except Exception as e:
                    print(f"[AI_WORKER] Failed processing {msg.gmail_id}: {e}")
                    msg.ai_processed = False
                    msg.ai_status = "failed"
                    db.commit()

            if succeeded:
                print(f"[AI_WORKER] Completed: {len(succeeded)} succeeded.")
            return succeeded

        except Exception as e:
            print(f"[AI_WORKER] Sequential processing catastrophic failure: {e}")
            db.rollback()
            return []

    finally:
        db.close()




def _count_users():
    """Blocking: returns list of UIDs with OAuth tokens."""
    from app.core.database import SupabaseSessionLocal
    from app.models.oauthToken import OAuthToken
    from app.models.user import User

    db = SupabaseSessionLocal()
    try:
        users = (
            db.query(OAuthToken.uid)
            .join(User, User.uid == OAuthToken.uid)
            .filter(User.oauth_connected.is_(True))
            .all()
        )
        return [u.uid for u in users]
    finally:
        db.close()


def _recover_stuck_processing():
    """Reset messages left in 'processing' state (e.g., after a crash/restart) back to 'pending'."""
    from app.core.database import SupabaseSessionLocal
    from app.models.gmail.gmail_message import GmailMessage

    db = SupabaseSessionLocal()
    try:
        # Reset any records marked 'processing' to 'pending' so they can be picked up again.
        count = db.query(GmailMessage).filter(GmailMessage.ai_status == "processing").update({
            "ai_status": "pending",
            "ai_processed": False
        })
        db.commit()
        if count:
            print(f"[AI_WORKER] Recovered {count} stuck 'processing' message(s) -> set to 'pending'")
    except Exception as e:
        print(f"[AI_WORKER] Failed to recover stuck processing messages: {e}")
        db.rollback()
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
    _worker_status["ingestion"]["status"] = "waiting_for_users"

    await asyncio.sleep(STARTUP_DELAY_SECONDS)
    print(f"[INGESTION] Background ingestion loop started (interval: {INGESTION_INTERVAL_SECONDS}s)")

    while True:
        try:
            uids = await asyncio.to_thread(_count_users)
            
            # Skip if no users are connected
            if not uids:
                _worker_status["ingestion"]["status"] = "waiting_for_users"
                await asyncio.sleep(INGESTION_INTERVAL_SECONDS)
                continue
            
            print(f"[INGESTION] Running for {len(uids)} user(s) at {datetime.utcnow().isoformat()}")
            
            _worker_status["ingestion"]["status"] = "running"
            _worker_status["ingestion"]["last_run"] = datetime.now(timezone.utc)

            sem = asyncio.Semaphore(5)

            async def bounded_sync(uid):
                async with sem:
                    try:
                        await asyncio.to_thread(_sync_user, uid)
                        _worker_status["ingestion"]["total_synced"] += 1
                        print(f"[INGESTION] Synced user {uid[:8]}…")
                    except Exception as e:
                        print(f"[INGESTION] Failed for user {uid[:8]}…: {e}")

            await asyncio.gather(*(bounded_sync(uid) for uid in uids))
            _worker_status["ingestion"]["status"] = "idle"

        except Exception as e:
            _worker_status["ingestion"]["status"] = "error"
            _worker_status["ingestion"]["last_error"] = str(e)
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
    # Recover any stuck messages left in 'processing' state from previous run/crash
    await asyncio.to_thread(_recover_stuck_processing)
    _worker_status["ai_processing"]["status"] = "running"
    print(f"[AI_WORKER] Background AI processing loop started (delay: {AI_LOOP_DELAY_SECONDS}s)")

    while True:
        try:
            # Skip if no users have connected Gmail yet
            try:
                uids = await asyncio.to_thread(_count_users)
            except OperationalError as e:
                # Database unreachable — set worker status and back off without
                # crashing the entire application. The background worker will
                # retry after a pause.
                _worker_status["ai_processing"]["status"] = "db_unreachable"
                _worker_status["ai_processing"]["last_error"] = str(e)
                print(f"[AI_WORKER] Database unreachable, retrying in 60s: {e}")
                await asyncio.sleep(60)
                continue
            if len(uids) == 0:
                _worker_status["ai_processing"]["status"] = "waiting_for_users"
                await asyncio.sleep(60)
                continue

            _worker_status["ai_processing"]["status"] = "running"
            _worker_status["ai_processing"]["last_run"] = datetime.now(timezone.utc)
            
            try:
                result = await asyncio.to_thread(_process_batch_emails)
            except OperationalError as e:
                _worker_status["ai_processing"]["status"] = "db_unreachable"
                _worker_status["ai_processing"]["last_error"] = str(e)
                print(f"[AI_WORKER] Database error during processing, retrying in 60s: {e}")
                await asyncio.sleep(60)
                continue

            if result:
                _worker_status["ai_processing"]["total_processed"] += len(result)

            if not result:
                # Nothing to process — sleep longer
                _worker_status["ai_processing"]["status"] = "idle"
                await asyncio.sleep(15)
                continue

        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            # Ollama unreachable — back off and retry
            _worker_status["ai_processing"]["status"] = "offline_llm"
            _worker_status["ai_processing"]["last_error"] = f"LLM offline: {str(e)}"
            print(f"[AI_WORKER] Ollama unreachable, retrying in 30s: {e}")
            await asyncio.sleep(30)
            continue

        except RuntimeError as e:
            if str(e).startswith("[OLLAMA]"):
                _worker_status["ai_processing"]["status"] = "offline_llm"
                _worker_status["ai_processing"]["last_error"] = str(e)
                print(f"[AI_WORKER] Ollama backend unavailable, retrying in 30s: {e}")
                await asyncio.sleep(30)
                continue
            raise

        except Exception as e:
            _worker_status["ai_processing"]["status"] = "error"
            _worker_status["ai_processing"]["last_error"] = str(e)
            print(f"[AI_WORKER] Loop error: {e}")
            traceback.print_exc()

        await asyncio.sleep(AI_LOOP_DELAY_SECONDS)
