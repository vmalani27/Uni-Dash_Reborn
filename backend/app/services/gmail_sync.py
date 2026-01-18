import requests
import datetime
from app.models.oauthToken import OAuthToken
from app.models.gmail_message import GmailMessage
from app.utils.google_oauth import get_access_token
from app.utils.gmail_fetch import fetch_gmail_messages, fetch_gmail_message_detail, extract_subject, extract_sender, extract_body

def sync_gmail_for_user(uid: str, db):
    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    if not token:
        return
    access_token = get_access_token(token.refresh_token)
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {"maxResults": 20}
    resp = requests.get(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages",
        headers=headers,
        params=params,
        timeout=10
    )
    messages = resp.json().get("messages", [])
    for msg in messages:
        gmail_id = msg["id"]
        exists = db.query(GmailMessage).filter(GmailMessage.gmail_id == gmail_id).first()
        if exists:
            continue
        msg_resp = requests.get(
            f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{gmail_id}",
            headers=headers,
            timeout=10
        )
        full = msg_resp.json()
        headers_map = {h["name"]: h["value"] for h in full["payload"]["headers"]}
        db.add(
            GmailMessage(
                uid=uid,
                gmail_id=gmail_id,
                thread_id=full.get("threadId"),
                sender=headers_map.get("From", ""),
                subject=headers_map.get("Subject", ""),
                snippet=full.get("snippet"),
                internal_date=datetime.datetime.utcfromtimestamp(int(full["internalDate"]) / 1000),
                body_text=extract_body(full),
                body_html="",  # Optionally implement extract_html
            )
        )
    db.commit()
