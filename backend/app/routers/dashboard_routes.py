from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.models.ai_layer import AcademicEntity, EntityActionState, EntitySourceMap, ExtractedSignal
from app.models.gmail.gmail_message import GmailMessage
from app.models.user import User
from app.services.sync_event_bus import get_dashboard_snapshot, set_dashboard_snapshot
from app.utils.firebase_util import verify_firebase_token

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])

GRACE_WINDOW_DAYS = 2
RECENT_WINDOW_DAYS = 14
MAX_ITEMS = 50


class DashboardItemThin(BaseModel):
    id: int
    title: str
    category: str | None = None
    priority: int | None = None
    due_at: str | None = None
    status: str | None = None


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _ensure_aware(value: Optional[datetime]) -> Optional[datetime]:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _parse_iso_datetime(value: Any) -> Optional[datetime]:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except Exception:
        return None
    return _ensure_aware(parsed)


def _recency_score(now: datetime, created_at: Optional[datetime], best_deadline: Optional[datetime]) -> float:
    score = 0.0
    created = _ensure_aware(created_at)
    deadline = _ensure_aware(best_deadline)

    if deadline:
        delta_days = (deadline - now).total_seconds() / 86400.0
        if delta_days >= -GRACE_WINDOW_DAYS:
            if delta_days < 0:
                score += 75.0
            else:
                score += max(20.0, 100.0 - (delta_days * 20.0))
    if created:
        age_days = max(0.0, (now - created).total_seconds() / 86400.0)
        if age_days <= RECENT_WINDOW_DAYS:
            score += max(10.0, 40.0 - age_days * 2.5)
    return min(score, 100.0)


def _short_description(latest_signal: Optional[ExtractedSignal], entity: AcademicEntity) -> str | None:
    if latest_signal and isinstance(latest_signal.raw_llm_output, dict):
        summary = latest_signal.raw_llm_output.get("summary")
        if summary:
            return str(summary)
    if getattr(entity, "summary", None):
        return str(entity.summary)
    if latest_signal and latest_signal.extracted_entities:
        return ", ".join(str(item) for item in latest_signal.extracted_entities[:3])
    return None


def _serialize_item(
    entity: AcademicEntity,
    latest_signal: Optional[ExtractedSignal],
    action_state: Optional[EntityActionState],
) -> Dict[str, Any]:
    urgency = _recency_score(_utc_now(), entity.created_at, entity.best_deadline)
    entity_type = (entity.entity_type or "INFORMATION").upper()
    description = _short_description(latest_signal, entity)
    completed = bool(action_state.completed) if action_state else False
    dismissed = bool(action_state.dismissed) if action_state else False
    snoozed_until = (
        action_state.snoozed_until.isoformat()
        if action_state and action_state.snoozed_until
        else None
    )
    status = "completed" if completed else "dismissed" if dismissed else "snoozed" if snoozed_until else "active"
    return {
        "id": entity.id,
        "title": entity.canonical_title,
        "type": entity_type,
        "category": entity_type,
        "origin": getattr(entity, "origin", "system") or "system",
        "deadline": entity.best_deadline.isoformat() if entity.best_deadline else None,
        "due_at": entity.best_deadline.isoformat() if entity.best_deadline else None,
        "description": description,
        "short_description": description,
        "relative_urgency": round(urgency, 2),
        "priority": int(round(urgency)),
        "status": status,
        "completed": completed,
        "dismissed": dismissed,
        "snoozed_until": snoozed_until,
    }


def _collect_latest_signals(db: Session, uid: str, entity_ids: List[int]) -> Dict[int, ExtractedSignal]:
    if not entity_ids:
        return {}

    rows = (
        db.query(EntitySourceMap.entity_id, ExtractedSignal)
        .join(ExtractedSignal, ExtractedSignal.source_email_id == EntitySourceMap.source_email_id)
        .join(GmailMessage, GmailMessage.gmail_id == ExtractedSignal.source_email_id)
        .filter(GmailMessage.uid == uid, EntitySourceMap.entity_id.in_(entity_ids))
        .order_by(ExtractedSignal.created_at.desc())
        .all()
    )

    latest: Dict[int, ExtractedSignal] = {}
    for entity_id, signal in rows:
        if entity_id not in latest:
            latest[entity_id] = signal
    return latest


def _collect_action_states(db: Session, uid: str, entity_ids: List[int]) -> Dict[int, EntityActionState]:
    if not entity_ids:
        return {}
    rows = (
        db.query(EntityActionState)
        .filter(EntityActionState.uid == uid, EntityActionState.entity_id.in_(entity_ids))
        .all()
    )
    return {row.entity_id: row for row in rows}


def _entity_visible(
    entity: AcademicEntity,
    latest_signal: Optional[ExtractedSignal],
    action_state: Optional[EntityActionState],
) -> bool:
    now = _utc_now()
    deadline = _ensure_aware(entity.best_deadline)
    created = _ensure_aware(entity.created_at)

    if action_state:
        if action_state.completed or action_state.dismissed:
            return False
        if action_state.snoozed_until and _ensure_aware(action_state.snoozed_until) > now:
            return False

    if deadline and deadline >= now - timedelta(days=GRACE_WINDOW_DAYS):
        return True
    if created and created >= now - timedelta(days=RECENT_WINDOW_DAYS):
        return True
    if latest_signal and _ensure_aware(latest_signal.created_at) and _ensure_aware(latest_signal.created_at) >= now - timedelta(days=RECENT_WINDOW_DAYS):
        return True
    return False


def _build_groups(items: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    groups: Dict[str, List[Dict[str, Any]]] = {
        "ASSIGNMENT": [],
        "EXAM": [],
        "OPPORTUNITY": [],
        "ACADEMIC_ADMIN": [],
        "INFORMATION": [],
    }
    for item in items:
        bucket = str(item.get("type") or "").upper()
        if bucket in groups:
            groups[bucket].append(item)

    return groups


def _build_focus(items: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not items:
        return None
    focus = sorted(
        items,
        key=lambda item: (
            -float(item.get("relative_urgency") or 0),
            item.get("deadline") or "",
            item.get("id") or 0,
        ),
    )[0]
    return focus


def _build_timeline(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    now = _utc_now()
    buckets = {"Today": [], "Tomorrow": [], "This Week": []}
    for item in sorted(items, key=lambda row: row.get("deadline") or ""):
        dt = _parse_iso_datetime(item.get("deadline"))
        if dt is None:
            continue
        delta = (dt.date() - now.date()).days
        if delta == 0:
            buckets["Today"].append(item)
        elif delta == 1:
            buckets["Tomorrow"].append(item)
        elif 1 < delta <= 7:
            buckets["This Week"].append(item)
    return [{"date": key, "items": buckets[key]} for key in ["Today", "Tomorrow", "This Week"]]


def _build_banner(items: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not items:
        return None
    now = _utc_now()
    upcoming = []
    for item in items:
        dt = _parse_iso_datetime(item.get("deadline"))
        if dt is None:
            continue
        hours = (dt - now).total_seconds() / 3600.0
        if hours < -48:
            continue
        upcoming.append((hours, item))
    if not upcoming:
        return None
    upcoming.sort(key=lambda pair: pair[0])
    hours, item = upcoming[0]
    if hours <= 6:
        return {"message": f"{item['title']} due in {max(0, int(round(hours)))} hours", "type": "urgent", "item_id": str(item["id"])}
    if hours <= 24:
        return {"message": f"Upcoming: {item['title']}", "type": "upcoming", "item_id": str(item["id"])}
    return None


@router.get("/", summary="Structured academic dashboard")
async def get_dashboard(
    db: Session = Depends(get_supabase_db),
    firebase_data: dict = Depends(verify_firebase_token),
):
    uid = firebase_data["uid"]

    user = db.query(User).filter(User.uid == uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    cached_payload = get_dashboard_snapshot(uid)
    if cached_payload is not None:
        return cached_payload

    if not user.oauth_connected:
        payload = {
            "focus": None,
            "groups": {
                "ASSIGNMENT": [],
                "EXAM": [],
                "OPPORTUNITY": [],
                "ACADEMIC_ADMIN": [],
                "INFORMATION": [],
            },
            "timeline": [
                {"date": "Today", "items": []},
                {"date": "Tomorrow", "items": []},
                {"date": "This Week", "items": []},
            ],
            "banner": None,
            "academic_items": [],
            "blocked_reason": "oauth_not_connected",
        }
        return payload

    entities: List[AcademicEntity] = (
        db.query(AcademicEntity)
        .filter(AcademicEntity.uid == uid)
        .order_by(AcademicEntity.updated_at.desc())
        .all()
    )

    latest_signal_map = _collect_latest_signals(db, uid, [entity.id for entity in entities])
    action_state_map = _collect_action_states(db, uid, [entity.id for entity in entities])

    visible_entities: List[AcademicEntity] = []
    for entity in entities:
        latest_signal = latest_signal_map.get(entity.id)
        action_state = action_state_map.get(entity.id)
        if _entity_visible(entity, latest_signal, action_state):
            visible_entities.append(entity)

    thin_items = [
        _serialize_item(entity, latest_signal_map.get(entity.id), action_state_map.get(entity.id))
        for entity in visible_entities[:MAX_ITEMS]
    ]
    thin_items.sort(
        key=lambda item: (
            -float(item.get("relative_urgency") or 0),
            item.get("deadline") or "",
            item.get("id") or 0,
        )
    )

    payload = {
        "academic_items": thin_items,
        "focus": _build_focus(thin_items),
        "groups": _build_groups(thin_items),
        "timeline": _build_timeline(thin_items),
        "banner": _build_banner(thin_items),
    }

    if not payload["academic_items"]:
        fallback_entities = entities[:MAX_ITEMS]
        payload["academic_items"] = [
            _serialize_item(entity, latest_signal_map.get(entity.id), action_state_map.get(entity.id))
            for entity in fallback_entities
        ]
        payload["focus"] = _build_focus(payload["academic_items"])
        payload["groups"] = _build_groups(payload["academic_items"])
        payload["timeline"] = _build_timeline(payload["academic_items"])
        payload["banner"] = _build_banner(payload["academic_items"])

    item_count = len(payload.get("academic_items", []))
    print(f"[DASHBOARD] items={item_count} uid={uid[:8]}")

    set_dashboard_snapshot(uid, payload)
    return payload
