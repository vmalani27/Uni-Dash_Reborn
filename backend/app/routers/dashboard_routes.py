from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

from app.core.database import get_supabase_db
from app.models.academic_objects import AcademicItem
from app.models.gmail.gmail_message import GmailMessage
from app.models.gmail.follow_up import FollowUp
from app.models.user import User
from app.services.academic_context_engine import AcademicContextEngine
from app.utils.firebase_util import verify_firebase_token

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])


def _serialize_item(item: AcademicItem) -> Dict[str, Any]:
    # Basic serialization for an AcademicItem. Enhanced fields (AI metadata,
    # source email id, description) are added in the main handler where the
    # related GmailMessage rows are available.
    return {
        "id": item.id,
        "title": item.title,
        "entity_type": item.entity_type,
        "due_date": item.due_date.isoformat() if item.due_date else None,
        "course_code": item.course_code,
        "location": item.location,
    }


def get_focus_item(items: List[AcademicItem]) -> Optional[AcademicItem]:
    now = datetime.utcnow()
    within_24 = [i for i in items if i.due_date is not None and 0 <= (i.due_date - now).total_seconds() <= 24 * 3600]
    if within_24:
        # pick the one with soonest due_date, tie-breaker by academic_score
        within_24.sort(key=lambda x: (x.due_date, -x.academic_score))
        return within_24[0]
    # fallback highest academic_score
    items_sorted = sorted(items, key=lambda x: (-x.academic_score, x.due_date or datetime.max))
    return items_sorted[0] if items_sorted else None


def group_items(items: List[AcademicItem]) -> Dict[str, List[Dict[str, Any]]]:
    keys = ["ASSIGNMENT", "EXAM", "ACADEMIC_ADMIN", "OPPORTUNITY", "INFORMATION"]
    grouped: Dict[str, List[Dict[str, Any]]] = {k: [] for k in keys}
    for it in items:
        et = (it.entity_type or "INFORMATION").upper()
        if et not in grouped:
            # place unknown types under INFORMATION
            et = "INFORMATION"
        grouped[et].append(_serialize_item(it))
    return grouped


def build_timeline(db: Session, uid: str, items: List[AcademicItem]) -> List[Dict[str, Any]]:
    now = datetime.utcnow()
    timeline_events: List[Dict[str, Any]] = []

    # Academic item due dates
    for it in items:
        if it.due_date:
            timeline_events.append({
                "id": f"item-{it.id}",
                "title": it.title,
                "time": it.due_date.isoformat(),
                "type": it.entity_type,
            })

    # FollowUps joined with GmailMessage to ensure uid
    followups_raw = (
        db.query(FollowUp, GmailMessage.subject, GmailMessage.normalized_topic)
        .join(GmailMessage, FollowUp.source_email_id == GmailMessage.gmail_id)
        .filter(GmailMessage.uid == uid, FollowUp.dismissed == False)
        .order_by(FollowUp.trigger_at.asc())
        .all()
    )

    for f, subject, normalized_topic in followups_raw:
        if f.trigger_at:
            timeline_events.append({
                "id": f"followup-{f.id}",
                "title": subject or f.message,
                "time": f.trigger_at.isoformat(),
                "type": (normalized_topic or "INFORMATION"),
            })

    # Group events into Today, Tomorrow, This Week
    buckets = {"Today": [], "Tomorrow": [], "This Week": []}
    for ev in sorted(timeline_events, key=lambda x: x["time"]):
        try:
            dt = datetime.fromisoformat(ev["time"])
        except Exception:
            continue
        delta = (dt.date() - now.date()).days
        if delta == 0:
            buckets["Today"].append(ev)
        elif delta == 1:
            buckets["Tomorrow"].append(ev)
        elif 1 < delta <= 7:
            buckets["This Week"].append(ev)

    result = []
    for key in ["Today", "Tomorrow", "This Week"]:
        result.append({"date": key, "items": buckets[key]})
    return result


def build_banner(items: List[AcademicItem]) -> Optional[Dict[str, Any]]:
    now = datetime.utcnow()
    soon = []
    for it in items:
        if it.due_date:
            hours = (it.due_date - now).total_seconds() / 3600.0
            if hours < 0:
                continue
            soon.append((hours, it))
    if not soon:
        return None
    soon.sort(key=lambda x: x[0])
    closest_hours, closest_item = soon[0]
    if closest_hours <= 6:
        hrs = max(0, int(round(closest_hours)))
        return {
            "message": f"{closest_item.title} due in {hrs} hours",
            "type": "urgent",
            "item_id": str(closest_item.id),
        }
    if closest_hours <= 24:
        return {
            "message": f"Upcoming: {closest_item.title}",
            "type": "upcoming",
            "item_id": str(closest_item.id),
        }
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

    # Do not expose dashboard content until OAuth setup is complete.
    if not user.oauth_connected:
        return {
            "focus": None,
            "groups": {
                "ASSIGNMENT": [],
                "EXAM": [],
                "ACADEMIC_ADMIN": [],
                "OPPORTUNITY": [],
                "INFORMATION": [],
            },
            "timeline": [
                {"date": "Today", "items": []},
                {"date": "Tomorrow", "items": []},
                {"date": "This Week", "items": []},
            ],
            "banner": None,
            "blocked_reason": "oauth_not_connected",
        }

    raw_items: List[AcademicItem] = db.query(AcademicItem).filter(AcademicItem.uid == uid).all()

    source_ids = [i.source_email_id for i in raw_items if i.source_email_id]
    gmail_map: Dict[str, GmailMessage] = {}
    if source_ids:
        msgs = (
            db.query(GmailMessage)
            .filter(GmailMessage.gmail_id.in_(source_ids), GmailMessage.uid == uid)
            .all()
        )
        gmail_map = {m.gmail_id: m for m in msgs}

    ranked_items = AcademicContextEngine.rank_academic_items(raw_items)
    filtered = [(item, metrics) for item, metrics in ranked_items if metrics["effective_score"] >= 20]

    focus_item = None
    focus_candidates = [
        (item, metrics)
        for item, metrics in filtered
        if item.due_date is not None and 0 <= (AcademicContextEngine._ensure_aware(item.due_date) - AcademicContextEngine._utc_now()).total_seconds() <= 24 * 3600
    ]
    if focus_candidates:
        focus_candidates.sort(key=lambda pair: (pair[0].due_date or datetime.max, -pair[1]["effective_score"]))
        focus_item = focus_candidates[0][0]
    elif filtered:
        focus_item = filtered[0][0]

    # Groups — serialize each AcademicItem and include linked GmailMessage metadata
    keys = ["ASSIGNMENT", "EXAM", "ACADEMIC_ADMIN", "OPPORTUNITY", "INFORMATION"]
    groups: Dict[str, List[Dict[str, Any]]] = {k: [] for k in keys}
    academic_items: List[Dict[str, Any]] = []
    for it, metrics in filtered:
        et = (it.entity_type or "INFORMATION").upper()
        if et not in groups:
            et = "INFORMATION"

        serialized = AcademicContextEngine.serialize_academic_item(
            it,
            gmail_map.get(it.source_email_id) if it.source_email_id else None,
            metrics,
        )
        groups[et].append(serialized)
        academic_items.append(serialized)

    # Timeline
    timeline = build_timeline(db, uid, [item for item, _metrics in filtered])

    # Banner
    banner = build_banner([item for item, _metrics in filtered])

    # Enrich focus item with GmailMessage fields if available
    focus_serialized = None
    if focus_item:
        focus_serialized = AcademicContextEngine.serialize_academic_item(
            focus_item,
            gmail_map.get(focus_item.source_email_id) if focus_item.source_email_id else None,
        )

    return {
        "focus": focus_serialized,
        "groups": groups,
        "academic_items": academic_items,
        "timeline": timeline,
        "banner": banner,
    }
