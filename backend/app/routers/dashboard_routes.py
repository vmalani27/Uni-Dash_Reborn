from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

from app.core.database import get_supabase_db
from app.models.academic_objects import AcademicItem
from app.models.gmail.gmail_message import GmailMessage
from app.models.gmail.follow_up import FollowUp
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

    # Fetch academic items for this user
    raw_items: List[AcademicItem] = (
        db.query(AcademicItem)
        .filter(AcademicItem.uid == uid, AcademicItem.completed == False, AcademicItem.dismissed == False)
        .all()
    )

    # Filter out very low priority items
    filtered = [i for i in raw_items if (i.academic_score or 0) >= 20]

    # Sort: due_date ASC (None -> end), then academic_score DESC
    def _sort_key(it: AcademicItem):
        due = it.due_date if it.due_date is not None else datetime.max
        return (due, -it.academic_score)

    filtered.sort(key=_sort_key)

    # Focus
    focus_item = get_focus_item(filtered)

    # Fetch linked GmailMessage rows for any academic items that reference
    # a source email. This lets the frontend render AI-derived fields like
    # `ai_summary`, `ai_label_topic`, and `ai_label_source` without re-running
    # inference on the client.
    source_ids = [i.source_email_id for i in filtered if i.source_email_id]
    gmail_map: Dict[str, GmailMessage] = {}
    if source_ids:
        msgs = (
            db.query(GmailMessage)
            .filter(GmailMessage.gmail_id.in_(source_ids), GmailMessage.uid == uid)
            .all()
        )
        gmail_map = {m.gmail_id: m for m in msgs}

    # Groups — serialize each AcademicItem and include linked GmailMessage metadata
    keys = ["ASSIGNMENT", "EXAM", "ACADEMIC_ADMIN", "OPPORTUNITY", "INFORMATION"]
    groups: Dict[str, List[Dict[str, Any]]] = {k: [] for k in keys}
    for it in filtered:
        et = (it.entity_type or "INFORMATION").upper()
        if et not in groups:
            et = "INFORMATION"

        serialized = {
            "id": it.id,
            "title": it.title,
            "entity_type": it.entity_type,
            "due_date": it.due_date.isoformat() if it.due_date else None,
            "course_code": it.course_code,
            "location": it.location,
            "source_email_id": it.source_email_id,
            "description": it.description,
            "academic_score": it.academic_score,
            "completed": it.completed,
        }

        # Attach AI/enrichment fields from the linked GmailMessage when available
        if it.source_email_id and it.source_email_id in gmail_map:
            gm = gmail_map[it.source_email_id]
            serialized.update({
                "ai_summary": gm.ai_summary,
                "ai_label_topic": gm.ai_label_topic,
                "ai_label_source": gm.ai_label_source,
            })

        groups[et].append(serialized)

    # Timeline
    timeline = build_timeline(db, uid, filtered)

    # Banner
    banner = build_banner(filtered)

    # Enrich focus item with GmailMessage fields if available
    focus_serialized = None
    if focus_item:
        focus_serialized = {
            "id": focus_item.id,
            "title": focus_item.title,
            "entity_type": focus_item.entity_type,
            "due_date": focus_item.due_date.isoformat() if focus_item.due_date else None,
            "course_code": focus_item.course_code,
            "location": focus_item.location,
            "source_email_id": focus_item.source_email_id,
            "description": focus_item.description,
            "academic_score": focus_item.academic_score,
            "completed": focus_item.completed,
        }
        if focus_item.source_email_id and focus_item.source_email_id in gmail_map:
            gm = gmail_map[focus_item.source_email_id]
            focus_serialized.update({
                "ai_summary": gm.ai_summary,
                "ai_label_topic": gm.ai_label_topic,
                "ai_label_source": gm.ai_label_source,
            })

    return {
        "focus": focus_serialized,
        "groups": groups,
        "timeline": timeline,
        "banner": banner,
    }
