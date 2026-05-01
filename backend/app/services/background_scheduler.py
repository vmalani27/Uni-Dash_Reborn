"""
Background Scheduler - Autonomous ingestion and AI processing loops.
"""

import asyncio
import logging
import os
import time
import traceback
from datetime import datetime, timedelta, timezone

import requests
from sqlalchemy.exc import OperationalError

from app.core.database import supabase_session_scope

logger = logging.getLogger(__name__)

INGESTION_INTERVAL_SECONDS = int(os.getenv("JANITOR_INTERVAL_SECONDS", "3600"))
AI_LOOP_DELAY_SECONDS = 5.0
AI_BATCH_SIZE = 5
STARTUP_DELAY_SECONDS = 10
INGESTION_DB_CONCURRENCY = 5

_start_time = None

_worker_status = {
    "ingestion": {
        "last_run": None,
        "last_error": None,
        "total_synced": 0,
        "total_processed": 0,
        "total_updates": 0,
        "status": "not_started",
    },
    "ai_processing": {
        "last_run": None,
        "last_error": None,
        "total_synced": 0,
        "total_processed": 0,
        "total_updates": 0,
        "status": "not_started",
    },
    "domain_stats": {
        "last_run": None,
        "last_error": None,
        "total_synced": 0,
        "total_processed": 0,
        "total_updates": 0,
        "status": "not_started",
    },
}


def get_uptime() -> int:
    if _start_time is None:
        return 0
    return int(time.time() - _start_time)


def get_worker_status() -> dict:
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
            "last_error": data["last_error"],
        }

    return {
        "uptime_seconds": get_uptime(),
        "workers": status,
    }


def _sync_user(uid: str, limit: int = 50):
    from app.services.gmail_service import GmailService

    with supabase_session_scope("scheduler_sync_user") as db:
        GmailService.incremental_sync(uid, db, limit=limit)


def _process_batch_emails():
    from datetime import datetime

    from app.models.gmail.gmail_message import GmailMessage
    from app.services.ai_service import AIService

    with supabase_session_scope("scheduler_process_batch") as db:
        now = datetime.utcnow()
        messages = (
            db.query(GmailMessage)
            .filter(
                (GmailMessage.ai_status == None)
                | (GmailMessage.ai_status == "pending")
                | (
                    (GmailMessage.ai_status == "failed")
                    & (GmailMessage.retry_count < 5)
                    & ((GmailMessage.next_retry_at == None) | (GmailMessage.next_retry_at <= now))
                )
                | (GmailMessage.ai_status == "completed_preprocessed")
            )
            .order_by(GmailMessage.created_at.asc())
            .limit(AI_BATCH_SIZE)
            .with_for_update(skip_locked=True)
            .all()
        )

        if not messages:
            logger.info("[AI_WORKER] batch_empty")
            return {"message_ids": [], "uids": []}

        for msg in messages:
            msg._original_ai_status = msg.ai_status
            msg.ai_status = "processing"
        db.commit()

        logger.info("[AI_WORKER] batch_start count=%s", len(messages))

        succeeded = []
        affected_uids = set()
        try:
            for msg in messages:
                affected_uids.add(msg.uid)
                original_status = getattr(msg, "_original_ai_status", None)
                logger.info(
                    "[AI_WORKER] item_start gmail_id=%s uid=%s original_status=%s",
                    msg.gmail_id,
                    msg.uid[:8],
                    original_status,
                )
                try:
                    result = AIService.process_email(
                        msg,
                        db=db,
                        use_llm=(original_status != "completed_preprocessed"),
                    )
                    db.commit()
                    succeeded.append(msg.gmail_id)
                    logger.info(
                        "[AI_WORKER] item_done gmail_id=%s uid=%s entity_id=%s created=%s type=%s",
                        msg.gmail_id,
                        msg.uid[:8],
                        result.get("entity_id") if isinstance(result, dict) else None,
                        result.get("entity_created") if isinstance(result, dict) else None,
                        result.get("type") if isinstance(result, dict) else None,
                    )
                except Exception as exc:
                    logger.exception("[AI_WORKER] item_failed gmail_id=%s uid=%s", msg.gmail_id, msg.uid[:8])
                    msg.ai_status = "failed"
                    msg.retry_count = (msg.retry_count or 0) + 1
                    msg.last_error = str(exc)
                    db.commit()

            logger.info("[AI_WORKER] batch_done succeeded=%s", len(succeeded))
            return {"message_ids": succeeded, "uids": list(affected_uids)}
        except Exception:
            logger.exception("[AI_WORKER] batch_failed")
            for msg in messages:
                msg.ai_status = "failed"
                msg.retry_count = (msg.retry_count or 0) + 1
            db.rollback()
            return {"message_ids": [], "uids": list(affected_uids)}


def _count_users():
    from app.models.oauthToken import OAuthToken
    from app.models.user import User

    with supabase_session_scope("scheduler_count_users") as db:
        users = (
            db.query(OAuthToken.uid)
            .join(User, User.uid == OAuthToken.uid)
            .filter(User.oauth_connected.is_(True))
            .all()
        )
        return [u.uid for u in users]


def _recover_stuck_processing():
    from app.models.gmail.gmail_message import GmailMessage

    try:
        with supabase_session_scope("scheduler_recover_stuck_processing") as db:
            count = (
                db.query(GmailMessage)
                .filter(GmailMessage.ai_status == "processing")
                .update({"ai_status": "pending", "ai_processed": False})
            )
            db.commit()
            if count:
                logger.info("[AI_WORKER] recovered_stuck count=%s", count)
    except Exception:
        logger.exception("[AI_WORKER] recover_failed")


async def ingestion_loop():
    global _start_time
    _start_time = time.time()
    _worker_status["ingestion"]["status"] = "waiting_for_users"

    await asyncio.sleep(STARTUP_DELAY_SECONDS)
    logger.info("[INGESTION] loop_started interval_seconds=%s", INGESTION_INTERVAL_SECONDS)

    while True:
        try:
            uids = await asyncio.to_thread(_count_users)
            if not uids:
                _worker_status["ingestion"]["status"] = "waiting_for_users"
                await asyncio.sleep(INGESTION_INTERVAL_SECONDS)
                continue

            logger.info("[INGESTION] run_start users=%s at=%s", len(uids), datetime.utcnow().isoformat())
            _worker_status["ingestion"]["status"] = "running"
            _worker_status["ingestion"]["last_run"] = datetime.now(timezone.utc)

            sem = asyncio.Semaphore(INGESTION_DB_CONCURRENCY)

            async def bounded_sync(uid):
                async with sem:
                    from app.services.sync_event_bus import is_sync_locked

                    if is_sync_locked(uid):
                        logger.info("[INGESTION] skip_locked uid=%s", uid[:8])
                        return

                    try:
                        await asyncio.to_thread(_sync_user, uid)
                        _worker_status["ingestion"]["total_synced"] += 1
                        logger.info("[INGESTION] synced uid=%s", uid[:8])
                    except Exception:
                        logger.exception("[INGESTION] failed uid=%s", uid[:8])

            await asyncio.gather(*(bounded_sync(uid) for uid in uids))
            _worker_status["ingestion"]["status"] = "idle"
        except Exception as exc:
            _worker_status["ingestion"]["status"] = "error"
            _worker_status["ingestion"]["last_error"] = str(exc)
            logger.exception("[INGESTION] loop_error")
            traceback.print_exc()

        await asyncio.sleep(INGESTION_INTERVAL_SECONDS)


async def ai_processing_loop():
    await asyncio.sleep(STARTUP_DELAY_SECONDS + 5)
    await asyncio.to_thread(_recover_stuck_processing)
    _worker_status["ai_processing"]["status"] = "running"
    logger.info("[AI_WORKER] loop_started delay_seconds=%s", AI_LOOP_DELAY_SECONDS)

    while True:
        try:
            try:
                uids = await asyncio.to_thread(_count_users)
            except OperationalError as exc:
                _worker_status["ai_processing"]["status"] = "db_unreachable"
                _worker_status["ai_processing"]["last_error"] = str(exc)
                logger.warning("[AI_WORKER] db_unreachable retry_seconds=60 error=%s", exc)
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
            except OperationalError as exc:
                _worker_status["ai_processing"]["status"] = "db_unreachable"
                _worker_status["ai_processing"]["last_error"] = str(exc)
                logger.warning("[AI_WORKER] db_error retry_seconds=60 error=%s", exc)
                await asyncio.sleep(60)
                continue

            if result:
                _worker_status["ai_processing"]["total_processed"] += len(result.get("message_ids", []))
                if result.get("uids"):
                    from app.services.sync_event_bus import (
                        invalidate_dashboard_snapshot,
                        publish_pipeline_event_with_new_session,
                    )

                    for affected_uid in result["uids"]:
                        await asyncio.to_thread(invalidate_dashboard_snapshot, affected_uid)
                        await asyncio.to_thread(
                            publish_pipeline_event_with_new_session,
                            affected_uid,
                            "ai_worker_progress",
                        )

            if not result or not result.get("message_ids"):
                _worker_status["ai_processing"]["status"] = "idle"
                await asyncio.sleep(15)
                continue

        except requests.exceptions.ConnectionError as exc:
            _worker_status["ai_processing"]["status"] = "offline_llm"
            _worker_status["ai_processing"]["last_error"] = f"LLM offline: {str(exc)}"
            logger.warning("[AI_WORKER] llm_offline retry_seconds=30 error=%s", exc)
            await asyncio.sleep(30)
            continue
        except requests.exceptions.Timeout as exc:
            _worker_status["ai_processing"]["status"] = "offline_llm"
            _worker_status["ai_processing"]["last_error"] = f"LLM offline: {str(exc)}"
            logger.warning("[AI_WORKER] llm_offline retry_seconds=30 error=%s", exc)
            await asyncio.sleep(30)
            continue
        except RuntimeError as exc:
            if str(exc).startswith("[OLLAMA]"):
                _worker_status["ai_processing"]["status"] = "offline_llm"
                _worker_status["ai_processing"]["last_error"] = str(exc)
                logger.warning("[AI_WORKER] llm_backend_unavailable retry_seconds=30 error=%s", exc)
                await asyncio.sleep(30)
                continue
            raise
        except Exception as exc:
            _worker_status["ai_processing"]["status"] = "error"
            _worker_status["ai_processing"]["last_error"] = str(exc)
            logger.exception("[AI_WORKER] loop_error")
            traceback.print_exc()

        await asyncio.sleep(AI_LOOP_DELAY_SECONDS)


async def daily_maintenance_loop():
    await asyncio.sleep(STARTUP_DELAY_SECONDS + 10)
    _worker_status["domain_stats"]["status"] = "running"
    logger.info("[DAILY_MAINTENANCE] loop_started")

    maintenance_interval = 86400

    while True:
        try:
            import os

            topic_name = os.getenv(
                "GMAIL_PUBSUB_TOPIC",
                "projects/f-r-i-d-a-y-vlelfh/topics/gmail-notifications",
            )

            logger.info("[DAILY_MAINTENANCE] run_start at=%s", datetime.utcnow().isoformat())
            _worker_status["domain_stats"]["status"] = "running"
            _worker_status["domain_stats"]["last_run"] = datetime.now(timezone.utc)

            from app.jobs.gmail_background_sync import daily_maintenance_job

            await asyncio.to_thread(daily_maintenance_job, topic_name)

            _worker_status["domain_stats"]["status"] = "idle"
            logger.info("[DAILY_MAINTENANCE] run_done next_run_hours=24")
        except Exception:
            _worker_status["domain_stats"]["status"] = "error"
            logger.exception("[DAILY_MAINTENANCE] run_failed")
            traceback.print_exc()

        await asyncio.sleep(maintenance_interval)
