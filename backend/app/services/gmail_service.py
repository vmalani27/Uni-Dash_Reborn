import datetime
import requests
from sqlalchemy.orm import Session

from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage, GmailSyncStatus
from app.utils.google_oauth import get_access_token
from app.utils.gmail_fetch import extract_body
from app.utils.encryption import decrypt_token


class GmailService:
    """
    Centralized Gmail sync service.
    Handles all Gmail synchronization operations.
    """

    @staticmethod
    def full_sync(uid: str, db, limit: int = 200):
        """
        Perform a full sync of Gmail messages for a user.
        Fetches recent emails and stores them in the database.
        """
        now = datetime.datetime.utcnow()

        # Get or create sync status
        status = db.query(GmailSyncStatus).filter_by(uid=uid).first()
        if not status:
            status = GmailSyncStatus(uid=uid)
            db.add(status)

        # Update status to in progress
        status.status = "in_progress"
        status.started_at = now
        status.finished_at = None
        status.error_message = None
        db.commit()

        try:
            # Get OAuth token
            token = db.query(OAuthToken).filter_by(uid=uid).first()
            if not token:
                raise Exception("OAuth token not found")

            # Get access token
            access_token = get_access_token(decrypt_token(token.refresh_token))
            headers = {"Authorization": f"Bearer {access_token}"}

            # Fetch message list
            resp = requests.get(
                "https://gmail.googleapis.com/gmail/v1/users/me/messages",
                headers=headers,
                params={"maxResults": limit},
                timeout=10
            )
            resp.raise_for_status()

            data = resp.json()
            messages = data.get("messages", [])
            next_page_token = data.get("nextPageToken")

            inserted = 0
            newest_internal_date = None

            # Optimization: Batch check for existing IDs to prevent UniqueViolation and N+1 queries
            message_ids = [m["id"] for m in messages]
            existing_ids = set()
            if message_ids:
                existing_records = db.query(GmailMessage.gmail_id).filter(
                    GmailMessage.uid == uid,
                    GmailMessage.gmail_id.in_(message_ids)
                ).all()
                existing_ids = {r[0] for r in existing_records}

            # Process each message
            for msg in messages:
                gmail_id = msg["id"]

                # Skip if already exists
                if gmail_id in existing_ids:
                    continue

                # Fetch full message details
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
                subject = headers_map.get("Subject", "")
                # Skip emails sent by the user themselves
                if sender == token.email:
                    continue

                # Create and store message
                db.add(
                    GmailMessage(
                        uid=uid,
                        gmail_id=gmail_id,
                        thread_id=full.get("threadId"),
                        sender=sender,
                        subject=subject,
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

            # Update sync status
            status.status = "completed"
            status.finished_at = datetime.datetime.utcnow()
            # Use the newest message date if we have messages, otherwise use now
            status.last_sync_date = newest_internal_date if newest_internal_date else datetime.datetime.utcnow()
            status.total_messages_synced = (status.total_messages_synced or 0) + inserted
            status.next_page_token = next_page_token
            status.sync_type = "full"
            status.new_messages_count = inserted  # Track new messages in this session
            db.commit()

            # Capture history ID for future incremental syncs
            print(f"[FULL SYNC] Capturing history ID for user {uid}")
            try:
                GmailService.capture_history_id(uid, db)
            except Exception as e:
                print(f"[FULL SYNC] Failed to capture history ID: {e}")

        except Exception as e:
            # Mark sync as failed
            status.status = "failed"
            status.finished_at = datetime.datetime.utcnow()
            status.error_message = str(e)
            db.commit()
            raise

    @staticmethod
    def incremental_sync(uid: str, db, limit: int = 50):
        """
        Perform an incremental sync using Gmail history API.
        Only fetches new emails since last sync.
        """
        now = datetime.datetime.utcnow()

        # Get sync status
        status = db.query(GmailSyncStatus).filter_by(uid=uid).first()
        if not status:
            # No previous sync, fall back to full sync
            print(f"[INCREMENTAL SYNC] No sync status found for user {uid}. Falling back to full sync.")
            GmailService.full_sync(uid, db, limit=100)
            return

        # Check if we have the required history ID
        if not status.last_history_id:
            print(f"[INCREMENTAL SYNC] No last_history_id found for user {uid}. Falling back to full sync.")
            GmailService.full_sync(uid, db, limit=100)
            return

        # Skip if recently synced (within last 60 seconds)
        if status.last_sync_date and (now - status.last_sync_date).seconds < 60:
            print(f"[INCREMENTAL SYNC] Skipping - recently synced {uid} at {status.last_sync_date}")
            status.status = "no_action"
            status.finished_at = now
            status.new_messages_count = 0
            status.error_message = None
            db.commit()
            return

        # Update status to in progress
        status.status = "in_progress"
        status.started_at = now
        status.finished_at = None
        status.error_message = None
        db.commit()

        try:
            # Get OAuth token
            token = db.query(OAuthToken).filter_by(uid=uid).first()
            if not token:
                raise Exception("OAuth token not found")

            # Get access token
            access_token = get_access_token(decrypt_token(token.refresh_token))
            headers = {"Authorization": f"Bearer {access_token}"}

            # Use Gmail History API for incremental sync
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
                raise Exception(f"History API error: {resp.text}")

            data = resp.json()
            history = data.get("history", [])
            new_history_id = data.get("historyId")

            print(f"[INCREMENTAL SYNC] History entries received: {len(history)}")
            print(f"[INCREMENTAL SYNC] New historyId: {new_history_id}")
            print(f"[INCREMENTAL SYNC] Previous historyId: {status.last_history_id}")

            inserted = 0
            newest_internal_date = status.last_sync_date

            # Process history entries
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

                    # Skip if already exists
                    if db.query(GmailMessage).filter_by(gmail_id=gmail_id).first():
                        print(f"[INCREMENTAL SYNC] Message {gmail_id} already exists, skipping")
                        continue

                    # Fetch full message details
                    try:
                        msg_resp = requests.get(
                            f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{gmail_id}",
                            headers=headers,
                            timeout=10
                        )
                        
                        if msg_resp.status_code == 404:
                            print(f"[INCREMENTAL SYNC] Message {gmail_id} no longer exists (404), skipping.")
                            continue
                            
                        msg_resp.raise_for_status()
                        
                    except requests.exceptions.RequestException as e:
                        print(f"[INCREMENTAL SYNC] Non-fatal error fetching message {gmail_id}: {e}")
                        continue

                    full = msg_resp.json()
                    internal_date = datetime.datetime.utcfromtimestamp(
                        int(full["internalDate"]) / 1000
                    )

                    headers_map = {
                        h["name"]: h["value"]
                        for h in full.get("payload", {}).get("headers", [])
                    }

                    sender = headers_map.get("From", "")
                    # Skip emails sent by the user themselves
                    if sender == token.email:
                        continue

                    subject = headers_map.get("Subject", "")
                    print(f"[INCREMENTAL SYNC] Inserting new message: {gmail_id}")
                    print(f"[INCREMENTAL SYNC]   Subject: {subject}")
                    print(f"[INCREMENTAL SYNC]   From: {sender}")
                    print(f"[INCREMENTAL SYNC]   Date: {internal_date}")

                    # Create and store message
                    db.add(
                        GmailMessage(
                            uid=uid,
                            gmail_id=gmail_id,
                            thread_id=full.get("threadId"),
                            sender=sender,
                            subject=subject,
                            snippet=full.get("snippet"),
                            internal_date=internal_date,
                            body_text=extract_body(full),
                            body_html=""
                        )
                    )

                    inserted += 1
                    if not newest_internal_date or internal_date > newest_internal_date:
                        newest_internal_date = internal_date

                    # Trigger background AI processing for new messages
                    # This will run AI inference asynchronously without blocking sync
                    try:
                        from app.services.ai_service import AIService
                        # Run AI in background thread to avoid blocking sync
                        import threading
                        def background_ai():
                            try:
                                supabase_db = None
                                from app.core.database import SupabaseSessionLocal
                                supabase_db = SupabaseSessionLocal()
                                message = supabase_db.query(GmailMessage).filter_by(gmail_id=gmail_id).first()
                                if message:
                                    AIService.run_email_inference(message, supabase_db)
                                    print(f"[BACKGROUND AI] Processed {gmail_id}")
                                supabase_db.close()
                            except Exception as e:
                                print(f"[BACKGROUND AI] Failed for {gmail_id}: {e}")
                        
                        # Start background thread for AI processing
                        ai_thread = threading.Thread(target=background_ai, daemon=True)
                        ai_thread.start()
                        
                    except Exception as e:
                        print(f"[SYNC] Failed to start background AI for {gmail_id}: {e}")

            db.commit()

            print(f"[INCREMENTAL SYNC] ===== SUMMARY =====")
            print(f"[INCREMENTAL SYNC] Total new messages inserted: {inserted}")
            print(f"[INCREMENTAL SYNC] History entries processed: {len(history)}")
            print(f"[INCREMENTAL SYNC] Updated historyId: {new_history_id}")

            # Update sync status
            status.status = "completed"
            status.finished_at = datetime.datetime.utcnow()
            # Use the newest message date if we have new messages, otherwise keep the existing date
            if inserted > 0 and newest_internal_date:
                status.last_sync_date = newest_internal_date
            status.total_messages_synced = (status.total_messages_synced or 0) + inserted
            status.sync_type = "incremental"
            status.new_messages_count = inserted  # Track new messages in this session

            if new_history_id and str(new_history_id) != status.last_history_id:
                status.last_history_id = str(new_history_id)
                print(f"[INCREMENTAL SYNC] Updated historyId from {status.last_history_id} to {new_history_id}")
            else:
                print(f"[INCREMENTAL SYNC] HistoryId unchanged: {new_history_id}")

            db.commit()
            print(f"[INCREMENTAL SYNC] Database committed - status updated to completed")
            print(f"[INCREMENTAL SYNC] finished_at: {status.finished_at}")
            print(f"[INCREMENTAL SYNC] last_history_id: {status.last_history_id}")

        except Exception as e:
            print(f"[INCREMENTAL SYNC] ERROR: {e}")
            # Mark sync as failed
            status.status = "failed"
            status.finished_at = datetime.datetime.utcnow()
            status.error_message = str(e)
            db.commit()
            raise

    @staticmethod
    def capture_history_id(uid: str, db):
        """
        Capture and store the current history ID for incremental syncs.
        """
        status = db.query(GmailSyncStatus).filter_by(uid=uid).first()
        token = db.query(OAuthToken).filter_by(uid=uid).first()

        if not status or not token:
            print(f"[CAPTURE HISTORY ID] Missing status or token for user {uid}")
            return

        access_token = get_access_token(decrypt_token(token.refresh_token))
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
                db.commit()
                print(f"[CAPTURE HISTORY ID] Successfully stored historyId: {history_id} for user {uid}")
            else:
                print(f"[CAPTURE HISTORY ID] No historyId in response")
        else:
            print(f"[CAPTURE HISTORY ID] Failed to fetch profile: {resp.text}")


# Utility functions for message retrieval
def get_paginated_messages(uid: str, db: Session, page: int, limit: int):
    offset = (page - 1) * limit

    user_oauth = db.query(OAuthToken).filter_by(uid=uid).first()
    user_email = user_oauth.email if user_oauth else None

    query = db.query(GmailMessage).filter(GmailMessage.uid == uid)

    if user_email:
        query = query.filter(~GmailMessage.sender.contains(user_email))

    # Sort primarily by date (newest first)
    messages = (
        query.order_by(GmailMessage.internal_date.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    total = query.count()

    return messages, total


def get_message_detail(uid: str, gmail_id: str, db: Session):
    return (
        db.query(GmailMessage)
        .filter(GmailMessage.uid == uid, GmailMessage.gmail_id == gmail_id)
        .first()
    )

