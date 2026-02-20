import datetime
import requests

from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage, GmailSyncStatus
from app.utils.google_oauth import get_access_token
from app.utils.gmail_fetch import extract_body
from app.utils.encryption import decrypt_token


def sync_gmail_for_user(uid: str, db, limit: int = 200):
    now = datetime.datetime.utcnow()

    status = db.query(GmailSyncStatus).filter_by(uid=uid).first()
    if not status:
        status = GmailSyncStatus(uid=uid)
        db.add(status)

    status.status = "in_progress"
    status.started_at = now
    status.finished_at = None
    status.error_message = None
    db.commit()

    try:
        token = db.query(OAuthToken).filter_by(uid=uid).first()
        if not token:
            raise Exception("OAuth token not found")

        access_token = get_access_token(decrypt_token(token.refresh_token))
        headers = {"Authorization": f"Bearer {access_token}"}

        resp = requests.get(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages",
            headers=headers,
            params={"maxResults": limit},
            timeout=10
        )
        resp.raise_for_status()

        messages = resp.json().get("messages", [])
        next_page_token = resp.json().get("nextPageToken")

        inserted = 0
        newest_internal_date = None

        for msg in messages:
            gmail_id = msg["id"]

            if db.query(GmailMessage).filter_by(gmail_id=gmail_id).first():
                continue

            msg_resp = requests.get(
                f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{gmail_id}",
                headers=headers,
                timeout=10
            )
            msg_resp.raise_for_status()

            full = msg_resp.json()

            internal_date = datetime.datetime.utcfromtimestamp(
                int(full["internalDate"]) / 1000
            )

            headers_map = {
                h["name"]: h["value"]
                for h in full.get("payload", {}).get("headers", [])
            }

            sender = headers_map.get("From", "")
            if sender == token.email:
                continue

            db.add(
                GmailMessage(
                    uid=uid,
                    gmail_id=gmail_id,
                    thread_id=full.get("threadId"),
                    sender=sender,
                    subject=headers_map.get("Subject", ""),
                    snippet=full.get("snippet"),
                    internal_date=internal_date,
                    body_text=extract_body(full),
                    body_html=""
                )
            )

            inserted += 1
            if not newest_internal_date or internal_date > newest_internal_date:
                newest_internal_date = internal_date

        db.commit()

        status.status = "completed"
        status.finished_at = datetime.datetime.utcnow()
        status.last_sync_date = newest_internal_date or datetime.datetime.utcnow()
        status.total_messages_synced = (status.total_messages_synced or 0) + inserted
        status.next_page_token = next_page_token
        status.sync_type = "full"

        db.commit()

        capture_and_store_history_id(uid, db)

    except Exception as e:
        status.status = "failed"
        status.finished_at = datetime.datetime.utcnow()
        status.error_message = str(e)
        db.commit()
        raise

def capture_and_store_history_id(uid: str, db):
    status = db.query(GmailSyncStatus).filter_by(uid=uid).first()
    token = db.query(OAuthToken).filter_by(uid=uid).first()

    if not status or not token:
        return

    access_token = get_access_token(decrypt_token(token.refresh_token))
    headers = {"Authorization": f"Bearer {access_token}"}

    resp = requests.get(
        "https://gmail.googleapis.com/gmail/v1/users/me/profile",
        headers=headers,
        timeout=10
    )

    if resp.status_code == 200:
        history_id = resp.json().get("historyId")
        if history_id:
            status.last_history_id = str(history_id)
            db.commit()
