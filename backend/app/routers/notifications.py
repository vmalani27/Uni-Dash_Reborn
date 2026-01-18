
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.oauthToken import OAuthToken
from app.models.gmail_message import GmailMessage
from app.utils.firebase_util import verify_firebase_token
from app.utils.google_oauth import get_access_token
from app.utils.gmail_fetch import fetch_gmail_messages, fetch_gmail_message_detail, normalize_gmail
from app.services.gmail_sync import sync_gmail_for_user
import re
import unicodedata

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


router = APIRouter(prefix="/notifications", tags=["Notifications"])


# Endpoint: List all notifications (preview for home/main page)
@router.get("/gmail/list-all")
def list_gmail_notifications(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    uid = firebase_data["uid"]
    messages = db.query(GmailMessage)\
        .filter(GmailMessage.uid == uid)\
        .order_by(GmailMessage.internal_date.desc())\
        .limit(50)\
        .all()
    notifications = [
        {
            "id": m.id,
            "gmail_id": m.gmail_id,
            "sender": m.sender,
            "subject": m.subject,
            "snippet": m.snippet,
            "internal_date": m.internal_date.isoformat() if m.internal_date else None,
        }
        for m in messages
    ]
    return {"notifications": notifications}

# Endpoint: Get full mail detail (for mail view)
@router.get("/gmail/get-mail/{gmail_id}")
def get_gmail_message_detail(
    gmail_id: str,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    uid = firebase_data["uid"]
    message = db.query(GmailMessage)\
        .filter(GmailMessage.uid == uid, GmailMessage.gmail_id == gmail_id)\
        .first()
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    mail_detail = {
        "id": message.id,
        "gmail_id": message.gmail_id,
        "thread_id": message.thread_id,
        "sender": message.sender,
        "subject": message.subject,
        "body_html": message.body_html,
        "body_text": normalize_email_text(message.body_text),
        "internal_date": message.internal_date.isoformat() if message.internal_date else None,
    }
    return mail_detail

@router.post("/gmail/sync")
def trigger_gmail_sync(
    background_tasks: BackgroundTasks,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    uid = firebase_data["uid"]
    background_tasks.add_task(sync_gmail_for_user, uid, db)
    return {"status": "sync started"}