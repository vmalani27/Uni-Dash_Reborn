import requests
import datetime
from app.models.oauthToken import OAuthToken
from app.models.gmail_message import GmailMessage
from app.models.gmail_sync_status import GmailSyncStatus
from app.utils.google_oauth import get_access_token
from app.utils.gmail_fetch import fetch_gmail_messages, fetch_gmail_message_detail, extract_subject, extract_sender, extract_body


def sync_gmail_for_user(uid: str, local_db, supabase_db=None, limit=100):
    if supabase_db is None:
        supabase_db = local_db

    status = local_db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    now = datetime.datetime.utcnow()

    if not status:
        status = GmailSyncStatus(uid=uid, status="in_progress", started_at=now)
        local_db.add(status)
    else:
        status.status = "in_progress"
        status.started_at = now
        status.finished_at = None
        status.error_message = None

    local_db.commit()

    try:
        token = supabase_db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
        if not token:
            raise Exception("OAuth token not found")

        access_token = get_access_token(token.refresh_token)
        headers = {"Authorization": f"Bearer {access_token}"}

        params = {"maxResults": limit}
        resp = requests.get(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages",
            headers=headers,
            params=params,
            timeout=10
        )

        data = resp.json()
        messages = data.get("messages", [])
        next_page_token = data.get("nextPageToken")

        newest_internal_date = None
        inserted = 0

        for msg in messages:
            gmail_id = msg["id"]

            if local_db.query(GmailMessage).filter_by(gmail_id=gmail_id).first():
                continue

            msg_resp = requests.get(
                f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{gmail_id}",
                headers=headers,
                timeout=10
            )

            full = msg_resp.json()
            internal_date = datetime.datetime.utcfromtimestamp(
                int(full["internalDate"]) / 1000
            )

            headers_map = {h["name"]: h["value"] for h in full["payload"]["headers"]}

            local_db.add(
                GmailMessage(
                    uid=uid,
                    gmail_id=gmail_id,
                    thread_id=full.get("threadId"),
                    sender=headers_map.get("From", ""),
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

        local_db.commit()

        status.status = "completed"
        status.finished_at = datetime.datetime.utcnow()
        # Use the newest message date if we have messages, otherwise use now
        status.last_sync_date = newest_internal_date if newest_internal_date else datetime.datetime.utcnow()
        status.total_messages_synced = (status.total_messages_synced or 0) + inserted
        status.next_page_token = next_page_token
        status.sync_type = "full"

        local_db.commit()
        
        # Capture history ID for future incremental syncs
        print(f"[FULL SYNC] Capturing history ID for user {uid}")
        try:
            capture_and_store_history_id(uid, local_db, supabase_db)
        except Exception as e:
            print(f"[FULL SYNC] Failed to capture history ID: {e}")

    except Exception as e:
        status.status = "failed"
        status.finished_at = datetime.datetime.utcnow()
        status.error_message = str(e)
        local_db.commit()


def capture_and_store_history_id(uid: str, local_db, supabase_db=None):
    """Fetch and store the latest Gmail historyId for the user after a full sync."""
    if supabase_db is None:
        supabase_db = local_db
    status = local_db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    token = supabase_db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    if not token:
        print(f"[CAPTURE HISTORY ID] No OAuth token found for user {uid}")
        return
    access_token = get_access_token(token.refresh_token)
    headers = {"Authorization": f"Bearer {access_token}"}
    print(f"[CAPTURE HISTORY ID] Fetching profile for user {uid}")
    resp = requests.get(
        "https://gmail.googleapis.com/gmail/v1/users/me/profile",
        headers=headers,
        timeout=10
    )
    print(f"[CAPTURE HISTORY ID] Profile response status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        history_id = data.get("historyId")
        print(f"[CAPTURE HISTORY ID] Received historyId: {history_id}")
        if history_id:
            status.last_history_id = str(history_id)
            local_db.commit()
            print(f"[CAPTURE HISTORY ID] Successfully stored historyId: {history_id} for user {uid}")
        else:
            print(f"[CAPTURE HISTORY ID] No historyId in response")
    else:
        print(f"[CAPTURE HISTORY ID] Failed to fetch profile: {resp.text}")
def sync_gmail_history_for_user(uid: str, local_db, supabase_db=None, limit=50):
    if supabase_db is None:
        supabase_db = local_db

    status = local_db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()
    now = datetime.datetime.utcnow()

    # Check if we have the required history ID
    if not status or not status.last_history_id:
        print(f"[GMAIL HISTORY SYNC] No last_history_id found for user {uid}. Falling back to full sync.")
        # Fallback to full sync instead of failing
        sync_gmail_for_user(uid, local_db, supabase_db, limit=100, incremental=False)
        return

    status.status = "in_progress"
    status.started_at = now
    status.finished_at = None
    status.error_message = None
    local_db.commit()

    try:
        token = supabase_db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
        if not token:
            raise Exception("OAuth token not found")

        access_token = get_access_token(token.refresh_token)
        headers = {"Authorization": f"Bearer {access_token}"}

        params = {
            "startHistoryId": status.last_history_id,
            "historyTypes": "messageAdded",
            "maxResults": limit
        }

        resp = requests.get(
            "https://gmail.googleapis.com/gmail/v1/users/me/history",
            headers=headers,
            params=params,
            timeout=10
        )

        print(f"[INCREMENTAL SYNC] Gmail History API status: {resp.status_code}")
        
        if resp.status_code != 200:
            print(f"[INCREMENTAL SYNC] API Error: {resp.text}")
            raise Exception(resp.text)

        data = resp.json()
        history = data.get("history", [])
        new_history_id = data.get("historyId")
        
        print(f"[INCREMENTAL SYNC] History entries received: {len(history)}")
        print(f"[INCREMENTAL SYNC] New historyId: {new_history_id}")
        print(f"[INCREMENTAL SYNC] Previous historyId: {status.last_history_id}")

        inserted = 0
        newest_internal_date = status.last_sync_date

        for entry in history:
            messages_added = entry.get("messagesAdded", [])
            print(f"[INCREMENTAL SYNC] History entry has {len(messages_added)} messages added")
            
            for item in messages_added:
                message = item.get("message", {})
                gmail_id = message.get("id")

                if not gmail_id:
                    print(f"[INCREMENTAL SYNC] Skipping entry with no gmail_id")
                    continue

                print(f"[INCREMENTAL SYNC] Processing message: {gmail_id}")
                
                if local_db.query(GmailMessage).filter_by(gmail_id=gmail_id).first():
                    print(f"[INCREMENTAL SYNC] Message {gmail_id} already exists, skipping")
                    continue

                msg_resp = requests.get(
                    f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{gmail_id}",
                    headers=headers,
                    timeout=10
                )

                full = msg_resp.json()
                internal_date = datetime.datetime.utcfromtimestamp(
                    int(full["internalDate"]) / 1000
                )

                headers_map = {
                    h["name"]: h["value"]
                    for h in full.get("payload", {}).get("headers", [])
                }
                
                subject = headers_map.get("Subject", "")
                sender = headers_map.get("From", "")
                print(f"[INCREMENTAL SYNC] Inserting new message: {gmail_id}")
                print(f"[INCREMENTAL SYNC]   Subject: {subject}")
                print(f"[INCREMENTAL SYNC]   From: {sender}")
                print(f"[INCREMENTAL SYNC]   Date: {internal_date}")

                local_db.add(
                    GmailMessage(
                        uid=uid,
                        gmail_id=gmail_id,
                        thread_id=full.get("threadId"),
                        sender=headers_map.get("From", ""),
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

        local_db.commit()

        print(f"[INCREMENTAL SYNC] ===== SUMMARY =====")
        print(f"[INCREMENTAL SYNC] Total new messages inserted: {inserted}")
        print(f"[INCREMENTAL SYNC] History entries processed: {len(history)}")
        print(f"[INCREMENTAL SYNC] Updated historyId: {new_history_id}")
        
        status.status = "completed"
        status.finished_at = datetime.datetime.utcnow()
        # Use the newest message date if we have new messages, otherwise keep the existing date
        # This prevents the timestamp from going backwards, but still tracks successful syncs
        if inserted > 0 and newest_internal_date:
            status.last_sync_date = newest_internal_date
        # Note: We don't update last_sync_date if no new messages to avoid misleading staleness checks
        status.total_messages_synced = (status.total_messages_synced or 0) + inserted
        status.sync_type = "incremental"

        if data.get("historyId"):
            status.last_history_id = str(data["historyId"])

        local_db.commit()
        print(f"[INCREMENTAL SYNC] Database committed - status updated to completed")
        print(f"[INCREMENTAL SYNC] finished_at: {status.finished_at}")
        print(f"[INCREMENTAL SYNC] last_history_id: {status.last_history_id}")

    except Exception as e:
        print(f"[INCREMENTAL SYNC] ERROR: {e}")
        status.status = "failed"
        status.finished_at = datetime.datetime.utcnow()
        status.error_message = str(e)
        local_db.commit()
        print(f"[INCREMENTAL SYNC] Database committed - status updated to failed")
