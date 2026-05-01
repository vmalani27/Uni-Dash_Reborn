import json
import importlib
import os
import time
from typing import Any, Optional

from app.models.gmail.gmail_message import GmailMessage
from app.models.gmail.gmail_sync_status import GmailSyncStatus

try:
    _redis_module = importlib.import_module("redis")
    _redis_async_module = importlib.import_module("redis.asyncio")
    RedisClient = getattr(_redis_module, "Redis")
    AsyncRedisClient = getattr(_redis_async_module, "Redis")
    _REDIS_AVAILABLE = True
except Exception:  # pragma: no cover - runtime dependency guard
    RedisClient = None
    AsyncRedisClient = None
    _REDIS_AVAILABLE = False


_sync_redis_client: Optional[Any] = None
_async_redis_client: Optional[Any] = None

DASHBOARD_SNAPSHOT_TTL_SECONDS = 60 * 60
LAST_PIPELINE_PAYLOAD_TTL_SECONDS = 60 * 60


def _redis_url() -> str:
    return (os.getenv("REDIS_URL") or "").strip()


def redis_enabled() -> bool:
    return bool(_redis_url()) and _REDIS_AVAILABLE


def channel_for_uid(uid: str) -> str:
    return f"sync_events:{uid}"


def dashboard_snapshot_key(uid: str) -> str:
    return f"dashboard_snapshot:{uid}"


def last_pipeline_payload_key(uid: str) -> str:
    return f"last_pipeline_payload:{uid}"


def get_sync_redis_client() -> Any:
    global _sync_redis_client
    if not redis_enabled():
        raise RuntimeError(
            "Redis is required but not configured. Ensure REDIS_URL is set and redis package is installed."
        )
    if _sync_redis_client is None:
        _sync_redis_client = RedisClient.from_url(_redis_url(), decode_responses=True)
    return _sync_redis_client


def get_async_redis_client() -> Any:
    global _async_redis_client
    if not redis_enabled():
        raise RuntimeError(
            "Redis is required but not configured. Ensure REDIS_URL is set and redis package is installed."
        )
    if _async_redis_client is None:
        _async_redis_client = AsyncRedisClient.from_url(_redis_url(), decode_responses=True)
    return _async_redis_client


def ensure_redis_ready() -> None:
    """Fail fast on boot if Redis is unavailable."""
    client = get_sync_redis_client()
    try:
        client.ping()
        print("[BOOT] Redis connected, pub/sub mode enabled")
    except Exception as exc:
        raise RuntimeError(f"Redis connection failed during boot: {exc}") from exc


def build_pipeline_payload(db: Any, uid: str) -> dict[str, Any]:
    sync_status = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()

    ai_pending_count = (
        db.query(GmailMessage)
        .filter(GmailMessage.uid == uid, GmailMessage.ai_status.is_(None))
        .count()
        + db.query(GmailMessage)
        .filter(GmailMessage.uid == uid, GmailMessage.ai_status == "pending")
        .count()
        + db.query(GmailMessage)
        .filter(GmailMessage.uid == uid, GmailMessage.ai_status == "processing")
        .count()
    )

    ai_failed_count = (
        db.query(GmailMessage)
        .filter(
            GmailMessage.uid == uid,
            GmailMessage.ai_status == "failed",
        )
        .count()
    )

    sync_value = sync_status.status if sync_status else "not_started"
    finished_at = sync_status.finished_at.isoformat() if sync_status and sync_status.finished_at else None
    pipeline_complete = sync_value in ["completed", "no_action"] and ai_pending_count == 0

    return {
        "status": sync_value,
        "finished_at": finished_at,
        "new_messages_count": getattr(sync_status, "new_messages_count", 0) if sync_status else 0,
        "ai_pending_count": ai_pending_count,
        "ai_failed_count": ai_failed_count,
        "pipeline_complete": pipeline_complete,
    }


def get_last_pipeline_payload(uid: str) -> Optional[dict[str, Any]]:
    client = get_sync_redis_client()
    try:
        raw = client.get(last_pipeline_payload_key(uid))
        if not raw:
            return None
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else None
    except Exception as exc:
        print(f"[PIPELINE_CACHE] read failed for uid={uid[:8]}: {exc}")
        return None


def set_last_pipeline_payload(
    uid: str,
    payload: dict[str, Any],
    ttl_seconds: int = LAST_PIPELINE_PAYLOAD_TTL_SECONDS,
) -> None:
    client = get_sync_redis_client()
    try:
        client.setex(
            last_pipeline_payload_key(uid),
            ttl_seconds,
            json.dumps(payload, default=str),
        )
    except Exception as exc:
        print(f"[PIPELINE_CACHE] write failed for uid={uid[:8]}: {exc}")


def publish_pipeline_event(db: Any, uid: str, source: str = "unknown") -> None:
    client = get_sync_redis_client()

    payload = build_pipeline_payload(db, uid)
    payload["source"] = source

    try:
        set_last_pipeline_payload(uid, payload)
        print(f"[SYNC] Publishing sync update uid={uid[:8]} source={source}")
        client.publish(channel_for_uid(uid), json.dumps(payload))
    except Exception as exc:
        print(f"[SYNC_BUS] publish failed for uid={uid[:8]} source={source}: {exc}")


def publish_pipeline_event_with_new_session(uid: str, source: str = "unknown") -> None:
    from app.core.database import supabase_session_scope

    with supabase_session_scope("publish_pipeline_event") as db:
        publish_pipeline_event(db, uid, source=source)


def publish_user_event(uid: str, payload: dict[str, Any]) -> None:
    client = get_sync_redis_client()
    body = dict(payload)
    body.setdefault("type", "event")

    try:
        client.publish(channel_for_uid(uid), json.dumps(body, default=str))
    except Exception as exc:
        print(f"[SYNC_BUS] user-event publish failed for uid={uid[:8]}: {exc}")


def get_dashboard_snapshot(uid: str) -> Optional[dict[str, Any]]:
    client = get_sync_redis_client()
    try:
        raw = client.get(dashboard_snapshot_key(uid))
        if not raw:
            return None
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else None
    except Exception as exc:
        print(f"[DASHBOARD_CACHE] read failed for uid={uid[:8]}: {exc}")
        return None


def set_dashboard_snapshot(
    uid: str,
    payload: dict[str, Any],
    ttl_seconds: int = DASHBOARD_SNAPSHOT_TTL_SECONDS,
) -> None:
    client = get_sync_redis_client()
    try:
        client.setex(
            dashboard_snapshot_key(uid),
            ttl_seconds,
            json.dumps(payload, default=str),
        )
    except Exception as exc:
        print(f"[DASHBOARD_CACHE] write failed for uid={uid[:8]}: {exc}")


def invalidate_dashboard_snapshot(uid: str) -> None:
    client = get_sync_redis_client()
    try:
        client.delete(dashboard_snapshot_key(uid))
    except Exception as exc:
        print(f"[DASHBOARD_CACHE] invalidate failed for uid={uid[:8]}: {exc}")


# ─── Distributed Locking ────────────────────────────────────

def sync_lock_key(uid: str) -> str:
    """Key for distributed sync lock."""
    return f"sync_lock:{uid}"


def acquire_sync_lock(uid: str, ttl: int = 600) -> bool:
    """
    Try to acquire exclusive sync lock for user (prevents concurrent syncs).
    
    Args:
        uid: Firebase user ID
        ttl: Lock time-to-live in seconds (auto-expires after ttl if not released)
    
    Returns:
        True if lock was acquired, False if already locked by another process.
    """
    client = get_sync_redis_client()
    
    lock_key = sync_lock_key(uid)
    lock_value = str(time.time())
    
    try:
        result = client.set(lock_key, lock_value, nx=True, ex=ttl)
        if result is not None:
            print(f"[LOCK] Acquired sync lock for {uid[:8]}… (ttl={ttl}s)")
            return True
        else:
            print(f"[LOCK] Could not acquire lock for {uid[:8]}… (already locked)")
            return False
    except Exception as exc:
        raise RuntimeError(f"[LOCK] Failed to acquire lock: {exc}") from exc


def release_sync_lock(uid: str) -> None:
    """
    Release sync lock for user (allow next sync to proceed).
    Safe to call multiple times (idempotent).
    """
    client = get_sync_redis_client()
    
    lock_key = sync_lock_key(uid)
    try:
        deleted = client.delete(lock_key)
        if deleted > 0:
            print(f"[LOCK] Released sync lock for {uid[:8]}…")
    except Exception as exc:
        raise RuntimeError(f"[LOCK] Failed to release lock: {exc}") from exc


def is_sync_locked(uid: str) -> bool:
    """
    Check if user's sync is currently locked (another sync in progress).
    """
    client = get_sync_redis_client()
    
    lock_key = sync_lock_key(uid)
    try:
        return client.exists(lock_key) > 0
    except Exception as exc:
        raise RuntimeError(f"[LOCK] Failed to check lock status: {exc}") from exc
