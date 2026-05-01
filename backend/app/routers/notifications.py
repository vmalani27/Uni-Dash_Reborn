import re
import unicodedata

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.services.gmail_service import get_message_detail, get_paginated_messages
from app.utils.firebase_util import verify_firebase_token
from app.utils.timezone_util import format_ist_datetime


router = APIRouter(prefix="/notifications", tags=["Notifications"])


def normalize_email_text(text: str) -> str:
    if not text:
        return ""
    text = str(text)
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"[\u200b\u200c\u200d\ufeff]", "", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


@router.get("/gmail/list-all")
def list_gmail_notifications(
    page: int = Query(1, ge=1, description="Page number (1-based)"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    include_stats: bool = Query(False, description="Include pagination stats"),
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
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
    if include_stats:
        offset = (page - 1) * limit
        response["pagination"] = {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
            "has_previous": page > 1,
            "has_next": offset + limit < total,
            "showing": len(notifications),
        }
    return response


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
    return {
        "id": message.id,
        "gmail_id": message.gmail_id,
        "thread_id": message.thread_id,
        "sender": message.sender,
        "subject": message.subject,
        "body_text": normalize_email_text(message.body_text),
        "internal_date": format_ist_datetime(message.internal_date),
    }
