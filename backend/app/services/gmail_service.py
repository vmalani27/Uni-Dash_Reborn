import datetime
import requests
from sqlalchemy.orm import Session

from app.models.oauthToken import OAuthToken
from app.models.user import User
from app.models.gmail.gmail_message import GmailMessage
from app.models.gmail.gmail_sync_status import GmailSyncStatus
from app.utils.google_oauth import get_access_token, OAuthReauthRequiredError
from app.utils.gmail_fetch import parse_gmail_payload, extract_headers_map
from app.models.broadcast import Broadcast
from app.utils.encryption import decrypt_token
from app.utils.pipeline_csv_logger import append_csv_row, utc_timestamp
from app.services.sync_event_bus import (
    invalidate_dashboard_snapshot,
    publish_pipeline_event,
)


SYNC_CSV_FIELDS = [
    "timestamp",
    "uid",
    "sync_type",
    "stage",
    "gmail_id",
    "subject",
    "sender",
    "broadcast_id",
    "ai_status",
    "inserted",
    "error",
]


class GmailService:
    """
    Centralized Gmail sync service.
    Handles all Gmail synchronization operations.
    """

    @staticmethod
    def _mark_oauth_reauth_required(uid: str, db, status: GmailSyncStatus | None, reason: str):
        """Disable ingestion for users with revoked/expired refresh tokens until they reconnect OAuth."""
        user = db.query(User).filter_by(uid=uid).first()
        if user:
            user.oauth_connected = False
            user.reauth_required = True
            user.reauth_required_at = datetime.datetime.utcnow()
            user.reauth_reason = reason

        if status:
            status.status = "auth_required"
            status.finished_at = datetime.datetime.utcnow()
            status.error_message = reason

        db.commit()
        print(f"[GMAIL SYNC] OAuth re-auth required for user {uid[:8]}…: {reason}")

    @staticmethod
    def _log_sync_event(
        uid: str,
        sync_type: str,
        stage: str,
        gmail_id: str | None = None,
        subject: str | None = None,
        sender: str | None = None,
        broadcast_id: str | None = None,
        ai_status: str | None = None,
        inserted: bool = False,
        error: str | None = None,
    ) -> None:
        append_csv_row(
            "gmail_sync_log.csv",
            {
                "timestamp": utc_timestamp(),
                "uid": uid,
                "sync_type": sync_type,
                "stage": stage,
                "gmail_id": gmail_id or "",
                "subject": subject or "",
                "sender": sender or "",
                "broadcast_id": broadcast_id or "",
                "ai_status": ai_status or "",
                "inserted": inserted,
                "error": error or "",
            },
            SYNC_CSV_FIELDS,
        )

    @staticmethod
    def full_sync(uid: str, db, limit: int = 100):
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
        publish_pipeline_event(db, uid, source="full_sync_started")
        GmailService._log_sync_event(uid, "full", "start")

        try:
            # Get OAuth token
            token = db.query(OAuthToken).filter_by(uid=uid).first()
            if not token:
                raise Exception("OAuth token not found")

            # Get access token
            try:
                access_token = get_access_token(decrypt_token(token.refresh_token))
            except OAuthReauthRequiredError as e:
                GmailService._mark_oauth_reauth_required(uid, db, status, str(e))
                return
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

                headers_map = extract_headers_map(full)

                sender = headers_map.get("From", "")
                subject = headers_map.get("Subject", "")
                # Prefer the header name exactly as injected by the admin route
                broadcast_id = headers_map.get("X-UniDash-Broadcast-ID") or headers_map.get("x-unidash-broadcast-id")
                text_body, html_body = parse_gmail_payload(full.get("payload", {}))

                # Fallback to parsing text from HTML if text is empty
                if not text_body and html_body:
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(html_body, "html.parser")
                    text_body = soup.get_text(separator="\n").strip()

                # Check cache for Instant Bypassing
                ai_status = "pending"
                ai_summary = None
                ai_label_topic = None
                normalized_topic = "OTHER"
                ai_label_urgency = None
                deadline_iso = None
                deadline_confidence = "None"
                ai_processed = False
                
                if broadcast_id:
                    # First, try to fetch a precomputed Broadcast entry (admin preprocessed data)
                    try:
                        broadcast_entry = db.query(Broadcast).filter(Broadcast.broadcast_id == broadcast_id).first()
                    except Exception:
                        broadcast_entry = None

                    if broadcast_entry:
                        ai_status = "completed_preprocessed"
                        ai_summary = broadcast_entry.ai_summary
                        ai_label_topic = broadcast_entry.ai_label_topic
                        normalized_topic = ai_label_topic or "OTHER"
                        ai_label_urgency = broadcast_entry.ai_label_urgency
                        deadline_iso = broadcast_entry.deadline_iso
                        deadline_confidence = broadcast_entry.deadline_confidence
                        ai_processed = True
                        print(f"[FULL SYNC] Applied Broadcast AI for {broadcast_id} from Broadcast table")
                    else:
                        # Fallback: try to reuse an existing GmailMessage cached inference if present
                        cached_msg = db.query(GmailMessage).filter(
                            GmailMessage.unidash_broadcast_id == broadcast_id,
                            GmailMessage.ai_status == "completed"
                        ).first()

                        if cached_msg:
                            ai_status = "completed"
                            ai_summary = cached_msg.ai_summary
                            ai_label_topic = cached_msg.ai_label_topic
                            normalized_topic = cached_msg.normalized_topic
                            ai_label_urgency = cached_msg.ai_label_urgency
                            deadline_iso = cached_msg.deadline_iso
                            deadline_confidence = cached_msg.deadline_confidence
                            ai_processed = True
                            print(f"[FULL SYNC] Instant Cache Hit for broadcast {broadcast_id}!")

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
                        body_text=text_body,
                        body_html=html_body,
                        unidash_broadcast_id=broadcast_id,
                        ai_status=ai_status,
                        ai_summary=ai_summary,
                        ai_label_topic=ai_label_topic,
                        normalized_topic=normalized_topic,
                        ai_label_urgency=ai_label_urgency,
                        deadline_iso=deadline_iso,
                        deadline_confidence=deadline_confidence,
                        ai_processed=ai_processed
                    )
                )
                GmailService._log_sync_event(
                    uid=uid,
                    sync_type="full",
                    stage="insert",
                    gmail_id=gmail_id,
                    subject=subject,
                    sender=sender,
                    broadcast_id=broadcast_id,
                    ai_status=ai_status,
                    inserted=True,
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
            invalidate_dashboard_snapshot(uid)
            publish_pipeline_event(db, uid, source="full_sync_completed")
            GmailService._log_sync_event(
                uid,
                "full",
                "completed",
                inserted=bool(inserted),
                error="",
            )

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
            publish_pipeline_event(db, uid, source="full_sync_failed")
            GmailService._log_sync_event(uid, "full", "failed", error=str(e))
            raise

    @staticmethod
    def incremental_sync(uid: str, db, limit: int = 50, source: str = None):
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
            GmailService.full_sync(uid, db, limit=500)
            return

        # Check if we have the required history ID
        if not status.last_history_id:
            print(f"[INCREMENTAL SYNC] No last_history_id found for user {uid}. Falling back to full sync.")
            GmailService.full_sync(uid, db, limit=500)
            return

        # Skip if recently synced (within last 60 seconds), unless source is webhook
        if status.last_sync_date and (now - status.last_sync_date).seconds < 60:
            if source != "webhook":
                print(f"[INCREMENTAL SYNC] Skipping - recently synced {uid} at {status.last_sync_date}")
                status.status = "no_action"
                status.finished_at = now
                status.new_messages_count = 0
                status.error_message = None
                db.commit()
                publish_pipeline_event(db, uid, source="incremental_no_action")
                return
            else:
                print(f"[INCREMENTAL SYNC] Webhook bypassing debounce for {uid}")

        # Update status to in progress
        status.status = "in_progress"
        status.started_at = now
        status.finished_at = None
        status.error_message = None
        db.commit()
        publish_pipeline_event(db, uid, source="incremental_started")
        GmailService._log_sync_event(uid, "incremental", "start")

        try:
            # Get OAuth token
            token = db.query(OAuthToken).filter_by(uid=uid).first()
            if not token:
                raise Exception("OAuth token not found")

            # Get access token
            try:
                access_token = get_access_token(decrypt_token(token.refresh_token))
            except OAuthReauthRequiredError as e:
                GmailService._mark_oauth_reauth_required(uid, db, status, str(e))
                return
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

                    headers_map = extract_headers_map(full)

                    sender = headers_map.get("From", "")
                    # Skip emails sent by the user themselves
                    if sender == token.email:
                        continue

                    subject = headers_map.get("Subject", "")
                    broadcast_id = headers_map.get("X-UniDash-Broadcast-ID") or headers_map.get("x-unidash-broadcast-id")
                    print(f"[INCREMENTAL SYNC] Inserting new message: {gmail_id}")
                    print(f"[INCREMENTAL SYNC]   Subject: {subject}")
                    print(f"[INCREMENTAL SYNC]   From: {sender}")
                    # Create and store message
                    text_body, html_body = parse_gmail_payload(full.get("payload", {}))
                    
                    # Fallback to parsing text from HTML if text is empty
                    if not text_body and html_body:
                        from bs4 import BeautifulSoup
                        soup = BeautifulSoup(html_body, "html.parser")
                        text_body = soup.get_text(separator="\n").strip()
                    
                    # Check cache for Instant Bypassing
                    ai_status = "pending"
                    ai_summary = None
                    ai_label_topic = None
                    normalized_topic = "OTHER"
                    ai_label_urgency = None
                    deadline_iso = None
                    deadline_confidence = "None"
                    ai_processed = False
                    
                    if broadcast_id:
                        # Try Broadcast table first
                        try:
                            broadcast_entry = db.query(Broadcast).filter(Broadcast.broadcast_id == broadcast_id).first()
                        except Exception:
                            broadcast_entry = None

                        if broadcast_entry:
                            ai_status = "completed_preprocessed"
                            ai_summary = broadcast_entry.ai_summary
                            ai_label_topic = broadcast_entry.ai_label_topic
                            normalized_topic = ai_label_topic or "OTHER"
                            ai_label_urgency = broadcast_entry.ai_label_urgency
                            deadline_iso = broadcast_entry.deadline_iso
                            deadline_confidence = broadcast_entry.deadline_confidence
                            ai_processed = True
                            print(f"[INCREMENTAL SYNC] Applied Broadcast AI for {broadcast_id} from Broadcast table")
                        else:
                            # Fallback to cached GmailMessage inference
                            cached_msg = db.query(GmailMessage).filter(
                                GmailMessage.unidash_broadcast_id == broadcast_id,
                                GmailMessage.ai_status == "completed"
                            ).first()

                            if cached_msg:
                                ai_status = "completed"
                                ai_summary = cached_msg.ai_summary
                                ai_label_topic = cached_msg.ai_label_topic
                                normalized_topic = cached_msg.normalized_topic
                                ai_label_urgency = cached_msg.ai_label_urgency
                                deadline_iso = cached_msg.deadline_iso
                                deadline_confidence = cached_msg.deadline_confidence
                                ai_processed = True
                                print(f"[INCREMENTAL SYNC] Instant Cache Hit for broadcast {broadcast_id}!")

                    db.add(
                        GmailMessage(
                            uid=uid,
                            gmail_id=gmail_id,
                            thread_id=full.get("threadId"),
                            sender=sender,
                            subject=subject,
                            snippet=full.get("snippet"),
                            internal_date=internal_date,
                            body_text=text_body,
                            body_html=html_body,
                            unidash_broadcast_id=broadcast_id,
                            ai_status=ai_status,
                            ai_summary=ai_summary,
                            ai_label_topic=ai_label_topic,
                            normalized_topic=normalized_topic,
                            ai_label_urgency=ai_label_urgency,
                            deadline_iso=deadline_iso,
                            deadline_confidence=deadline_confidence,
                            ai_processed=ai_processed
                        )
                    )
                    GmailService._log_sync_event(
                        uid=uid,
                        sync_type="incremental",
                        stage="insert",
                        gmail_id=gmail_id,
                        subject=subject,
                        sender=sender,
                        broadcast_id=broadcast_id,
                        ai_status=ai_status,
                        inserted=True,
                    )

                    inserted += 1
                    if not newest_internal_date or internal_date > newest_internal_date:
                        newest_internal_date = internal_date

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
            invalidate_dashboard_snapshot(uid)
            publish_pipeline_event(db, uid, source="incremental_completed")
            GmailService._log_sync_event(
                uid,
                "incremental",
                "completed",
                inserted=bool(inserted),
                error="",
            )

        except Exception as e:
            print(f"[INCREMENTAL SYNC] ERROR: {e}")
            # Mark sync as failed
            status.status = "failed"
            status.finished_at = datetime.datetime.utcnow()
            status.error_message = str(e)
            db.commit()
            publish_pipeline_event(db, uid, source="incremental_failed")
            GmailService._log_sync_event(uid, "incremental", "failed", error=str(e))
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

        try:
            access_token = get_access_token(decrypt_token(token.refresh_token))
        except OAuthReauthRequiredError as e:
            GmailService._mark_oauth_reauth_required(uid, db, status, str(e))
            return
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

    @staticmethod
    def start_gmail_watch(uid: str, db, topic_name: str):
        """
        Tells Gmail to start sending push notifications for this user to Pub/Sub topic.
        
        Args:
            uid: User ID
            db: Database session
            topic_name: Full topic path (e.g., 'projects/my-project/topics/gmail-notifications')
        
        Returns:
            watch_response dict with historyId and expiration (in milliseconds)
        """
        status = db.query(GmailSyncStatus).filter_by(uid=uid).first()
        token = db.query(OAuthToken).filter_by(uid=uid).first()

        if not status or not token:
            raise Exception(f"Missing status or token for user {uid}")

        try:
            access_token = get_access_token(decrypt_token(token.refresh_token))
        except OAuthReauthRequiredError as e:
            GmailService._mark_oauth_reauth_required(uid, db, status, str(e))
            raise

        headers = {"Authorization": f"Bearer {access_token}"}

        body = {
            'topicName': topic_name,
            'labelIds': ['INBOX']  # Watch only INBOX
        }

        print(f"[GMAIL WATCH] Starting watch for user {uid[:8]}… on topic {topic_name}")
        
        resp = requests.post(
            "https://gmail.googleapis.com/gmail/v1/users/me/watch",
            headers=headers,
            json=body,
            timeout=10
        )
        resp.raise_for_status()

        watch_response = resp.json()
        
        # Convert expiration from milliseconds to datetime
        expiration_ms = int(watch_response.get('expiration', 0))
        expiration_dt = datetime.datetime.utcfromtimestamp(expiration_ms / 1000.0)
        
        # Update sync status with watch expiration and history ID
        status.watch_expiration = expiration_dt
        status.last_history_id = watch_response.get('historyId')
        db.commit()
        
        print(f"[GMAIL WATCH] Watch started for user {uid[:8]}. HistoryId: {watch_response.get('historyId')}, Expiration: {expiration_dt}")
        
        return watch_response

    @staticmethod
    def stop_gmail_watch(refresh_token: str, uid: str | None = None) -> bool:
        """
        Tell Gmail to stop sending push notifications for the current account.

        Returns True when Gmail accepts the stop request, False otherwise.
        """
        access_token = get_access_token(decrypt_token(refresh_token))
        headers = {"Authorization": f"Bearer {access_token}"}

        print(f"[GMAIL WATCH] Stopping watch for user {uid[:8] if uid else 'unknown'}")
        resp = requests.post(
            "https://gmail.googleapis.com/gmail/v1/users/me/stop",
            headers=headers,
            timeout=10,
        )

        if resp.status_code not in (200, 204):
            print(f"[GMAIL WATCH] Stop request failed for user {uid[:8] if uid else 'unknown'}: {resp.status_code} {resp.text}")
            return False

        print(f"[GMAIL WATCH] Watch stopped for user {uid[:8] if uid else 'unknown'}")
        return True



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

