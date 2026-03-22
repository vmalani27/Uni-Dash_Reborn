from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.core.database import get_supabase_db
from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage
from app.models.academic_objects import AcademicItem
from app.utils.firebase_util import verify_firebase_token
from app.utils.timezone_util import format_ist_datetime
from app.services.gmail_service import get_paginated_messages, get_message_detail
import re
import unicodedata
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

    # Query AcademicItem for this user, excluding dismissed items
    items = db.query(AcademicItem).filter(
        AcademicItem.uid == uid,
        AcademicItem.dismissed == False
    ).order_by(
        desc(AcademicItem.academic_score),
        AcademicItem.due_date.asc()
    ).all()

    # Organize items by entity type
    grouped_items = {
        "assignments": [],
        "exams": [],
        "admin": [],
        "opportunities": [],
        "information": []
    }

    focus_item = None
    timeline = {}

    for item in items:
        # Determine entity type group
        entity_group = grouped_items.get(item.entity_type.lower(), [])
        grouped_items[item.entity_type.lower()] = entity_group  # Ensure the group exists
        entity_group.append({
            "id": item.id,
            "title": item.title,
            "due_date": item.due_date.isoformat() if item.due_date else None,
            "location": item.location,
            "course_code": item.course_code,
            "completed": item.completed,
        })

        # Determine focus item (highest priority)
        if not focus_item or (item.due_date and item.due_date < focus_item["due_date"]):
            focus_item = {
                "id": item.id,
                "entity_type": item.entity_type,
                "title": item.title,
                "due_date": item.due_date,  # Keep as datetime for now
                "location": item.location,
                "course_code": item.course_code,
                "completed": item.completed,
            }

        # Build timeline
        if item.due_date:
            date_key = item.due_date.date().isoformat()
            if date_key not in timeline:
                timeline[date_key] = []
            timeline[date_key].append({
                "id": item.id,
                "entity_type": item.entity_type,
                "title": item.title,
            })

    # Convert `focus_item["due_date"]` to ISO format when returning the response
    if focus_item:
        focus_item["due_date"] = focus_item["due_date"].isoformat()

    return {
        "focus": focus_item,
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
    
    # Fetch OAuth token for this user
    oauth_token = db.query(OAuthToken).filter(
        OAuthToken.uid == uid
    ).first()
    if not oauth_token or not oauth_token.access_token:
        raise HTTPException(status_code=401, detail="No Google OAuth token; please connect Gmail first")
    
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
    headers = {"Authorization": f"Bearer {oauth_token.access_token}"}
    cal_response = requests.post(
        "https://www.googleapis.com/calendar/v3/calendars/primary/events",
        json=event,
        headers=headers
    )
    
    if cal_response.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Failed to create calendar event: {cal_response.text}")
    
    return {"status": "success", "item_id": item_id, "calendar_event_id": cal_response.json().get("id")}

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
    db.commit()
    return {"status": "success", "item_id": item_id}