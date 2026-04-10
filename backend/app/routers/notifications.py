from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.database import get_supabase_db
from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage
from app.models.academic_objects import AcademicItem
from app.models.user import User
from app.services.academic_context_engine import AcademicContextEngine
from app.utils.firebase_util import verify_firebase_token
from app.utils.timezone_util import format_ist_datetime
from app.services.gmail_service import get_paginated_messages, get_message_detail
from app.utils.encryption import decrypt_token
from app.utils.google_oauth import get_access_token
import re
import unicodedata
from datetime import datetime
from datetime import timedelta

# Safe normalization for email body text
def normalize_email_text(text: str) -> str:
    if not text:
        return ""
    text = str(text)
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"[\u200b\u200c\u200d\ufeff]", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


# Request models
class SnoozeRequest(BaseModel):
    hours: int = 24


router = APIRouter(prefix="/notifications", tags=["Notifications"])
@router.get("/gmail/list-all")
def list_gmail_notifications(
    page: int = Query(1, ge=1, description="Page number (1-based)"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    include_stats: bool = Query(False, description="Include pagination stats"),
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    
    # Get paginated messages using the service function
    messages, total = get_paginated_messages(uid, db, page, limit)
        
    notifications = [
        {
            "id": m.id,
            "gmail_id": m.gmail_id,
            "sender": m.sender,
            "subject": m.subject,
            "snippet": m.snippet,
            "internal_date": format_ist_datetime(m.internal_date),
        }
        for m in messages
    ]
    
    response = {"notifications": notifications}
    
    # Include pagination metadata if requested
    if include_stats:
        offset = (page - 1) * limit
        response["pagination"] = {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
            "has_previous": page > 1,
            "has_next": offset + limit < total,
            "showing": len(notifications)
        }
    
    return response

# Endpoint: Get full mail detail (for mail view)
@router.get("/gmail/get-mail/{gmail_id}")
def get_gmail_message_detail(
    gmail_id: str,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    message = get_message_detail(uid, gmail_id, db)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    mail_detail = {
        "id": message.id,
        "gmail_id": message.gmail_id,
        "thread_id": message.thread_id,
        "sender": message.sender,
        "subject": message.subject,
        "body_text": normalize_email_text(message.body_text),
        "internal_date": format_ist_datetime(message.internal_date),
    }
    return mail_detail

@router.get("/academic/dashboard")
def get_academic_dashboard(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Fetch academic items (assignments, exams, events, opportunities) for logged-in user."""
    uid = firebase_data["uid"]

    user = db.query(User).filter(User.uid == uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not user.oauth_connected:
        return {
            "focus": None,
            "assignments": [],
            "exams": [],
            "admin": [],
            "opportunities": [],
            "timeline": [],
            "blocked_reason": "oauth_not_connected",
        }

    items = db.query(AcademicItem).filter(AcademicItem.uid == uid).all()

    source_ids = [item.source_email_id for item in items if item.source_email_id]
    gmail_map = {}
    if source_ids:
        msgs = (
            db.query(GmailMessage)
            .filter(GmailMessage.gmail_id.in_(source_ids), GmailMessage.uid == uid)
            .all()
        )
        gmail_map = {msg.gmail_id: msg for msg in msgs}

    ranked_items = AcademicContextEngine.rank_academic_items(items)

    # Organize items by entity type
    grouped_items = {
        "assignments": [],
        "exams": [],
        "admin": [],
        "opportunities": [],
        "information": []
    }

    focus_item = None
    academic_items = []
    timeline = {}

    type_map = {
        "ASSIGNMENT": "assignments",
        "EXAM": "exams",
        "ACADEMIC_ADMIN": "admin",
        "OPPORTUNITY": "opportunities",
        "INFORMATION": "information",
    }

    for item, metrics in ranked_items:
        serialized = AcademicContextEngine.serialize_academic_item(
            item,
            gmail_map.get(item.source_email_id) if item.source_email_id else None,
            metrics,
        )
        academic_items.append(serialized)

        entity_group = type_map.get((item.entity_type or "INFORMATION").upper(), "information")
        grouped_items[entity_group].append(serialized)

        if serialized.get("due_date"):
            date_key = serialized["due_date"][:10]
            timeline.setdefault(date_key, []).append({
                "id": serialized["id"],
                "entity_type": serialized["entity_type"],
                "title": serialized["title"],
            })

    focus_item = academic_items[0] if academic_items else None

    return {
        "focus": focus_item,
        "academic_items": academic_items,
        "assignments": grouped_items["assignments"],
        "exams": grouped_items["exams"],
        "admin": grouped_items["admin"],
        "opportunities": grouped_items["opportunities"],
        "timeline": [
            {"date": date, "items": items} for date, items in sorted(timeline.items())
        ]
    }

@router.post("/gmail/sync")
def trigger_gmail_sync(
    background_tasks: BackgroundTasks,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    # Sync is now triggered via /gmail/sync/{uid} endpoint only
    return {"status": "no automatic sync; use /gmail/sync/{uid}"}

# ─── Academic Item Actions ───────────────────────────────────────────

@router.post("/academic/{item_id}/mark-done")
def mark_academic_item_done(
    item_id: int,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Mark an academic item as completed."""
    uid = firebase_data["uid"]
    item = db.query(AcademicItem).filter(
        AcademicItem.id == item_id,
        AcademicItem.uid == uid,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    item.completed = True
    item.dismissed = False
    item.status = "completed"
    item.snoozed_until = None
    item.last_updated_at = datetime.utcnow()
    db.commit()
    return {"status": "success", "item_id": item_id}


@router.post("/academic/{item_id}/mark-missed")
def mark_academic_item_missed(
    item_id: int,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Mark an academic item as missed."""
    uid = firebase_data["uid"]
    item = db.query(AcademicItem).filter(
        AcademicItem.id == item_id,
        AcademicItem.uid == uid,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    item.completed = False
    item.dismissed = False
    item.status = "missed"
    item.snoozed_until = None
    item.last_updated_at = datetime.utcnow()
    db.commit()
    return {"status": "success", "item_id": item_id}

@router.post("/academic/{item_id}/add-to-calendar")
def add_academic_item_to_calendar(
    item_id: int,
    request: SnoozeRequest,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Create a Google Calendar event for an academic item."""
    uid = firebase_data["uid"]
    item = db.query(AcademicItem).filter(
        AcademicItem.id == item_id,
        AcademicItem.uid == uid,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if not item.due_date:
        raise HTTPException(status_code=400, detail="This item does not have a due date to add to calendar")
    
    # Fetch OAuth token for this user
    oauth_token = db.query(OAuthToken).filter(
        OAuthToken.uid == uid
    ).first()
    if not oauth_token or not oauth_token.refresh_token:
        raise HTTPException(status_code=401, detail="No Google OAuth token; please connect Gmail first")

    access_token = get_access_token(decrypt_token(oauth_token.refresh_token))
    
    # Build calendar event
    event = {
        "summary": item.title,
        "description": item.description,
        "start": {
            "dateTime": item.due_date.isoformat() if item.due_date else None,
            "timeZone": "Asia/Kolkata"
        },
        "end": {
            "dateTime": (item.due_date + timedelta(hours=1)).isoformat() if item.due_date else None,
            "timeZone": "Asia/Kolkata"
        },
        "location": item.location or ""
    }
    
    import requests
    headers = {"Authorization": f"Bearer {access_token}"}
    cal_response = requests.post(
        "https://www.googleapis.com/calendar/v3/calendars/primary/events",
        json=event,
        headers=headers
    )
    
    if cal_response.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to create calendar event: {cal_response.text}")
    
    return {"status": "success", "item_id": item_id, "calendar_event_id": cal_response.json().get("id")}


@router.post("/academic/{item_id}/snooze")
def snooze_academic_item(
    item_id: int,
    request: SnoozeRequest,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Temporarily hide an academic item until a later time."""
    uid = firebase_data["uid"]
    item = db.query(AcademicItem).filter(
        AcademicItem.id == item_id,
        AcademicItem.uid == uid,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    snooze_hours = max(1, request.hours)
    # Canonical lifecycle keeps snooze as active + future snoozed_until gate.
    item.status = "active"
    item.completed = False
    item.dismissed = False
    item.snoozed_until = datetime.utcnow() + timedelta(hours=snooze_hours)
    item.last_updated_at = datetime.utcnow()
    db.commit()
    return {
        "status": "success",
        "item_id": item_id,
        "snoozed_until": item.snoozed_until.isoformat(),
    }

@router.post("/academic/{item_id}/dismiss")
def dismiss_academic_item(
    item_id: int,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Dismiss (permanently remove) an academic item from the dashboard."""
    uid = firebase_data["uid"]
    item = db.query(AcademicItem).filter(
        AcademicItem.id == item_id,
        AcademicItem.uid == uid,
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    item.dismissed = True
    item.completed = False
    item.status = "ignored"
    item.snoozed_until = None
    item.last_updated_at = datetime.utcnow()
    db.commit()
    return {"status": "success", "item_id": item_id}