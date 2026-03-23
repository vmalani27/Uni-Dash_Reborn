from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from app.core.database import get_supabase_db
from app.utils.firebase_util import verify_firebase_token
from app.models.oauthToken import OAuthToken
from app.utils.google_oauth import get_access_token
from app.utils.encryption import decrypt_token
import base64
from email.message import EmailMessage
import requests
import uuid
from app.services.ai_service import AIService
from app.models.broadcast import Broadcast
import datetime

router = APIRouter(prefix="/admin", tags=["Admin Broadcast"])


@router.post("/broadcast/send")
def send_admin_broadcast(
    subject: str,
    body_text: str,
    to_emails: list[str],
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_supabase_db),
    firebase_data=Depends(verify_firebase_token)
):
    """
    Sends a broadcast email to a list of students on behalf of the admin.
    Injects the custom X-UniDash-Broadcast-ID header to allow the AI ingestion layer
    to instantly cache and cross-pollinate the AI labels across all student accounts.
    """
    uid = firebase_data["uid"]
    
    # Verify the admin has an OAuth token
    admin_token = db.query(OAuthToken).filter_by(uid=uid).first()
    if not admin_token:
        raise HTTPException(status_code=400, detail="Admin has not connected their Gmail account.")
    
    if not admin_token.scopes or "gmail.send" not in admin_token.scopes:
        raise HTTPException(
            status_code=403, 
            detail="Admin account does not have permission to send emails. Please re-authenticate via the Admin Login."
        )

    # 1. Generate the unique broadcast ID for the cache
    broadcast_id = str(uuid.uuid4())

    # 1b. Precompute AI fields for this broadcast and persist them so recipients' ingestion
    #    can pick up the preprocessed results instantly when they sync.
    try:
        # Create a transient message-like object that AIService can process
        class TempMsg:
            pass

        temp = TempMsg()
        temp.subject = subject
        temp.body_text = body_text
        temp.sender = admin_token.email
        temp.internal_date = datetime.datetime.utcnow()

        # Run the AI pipeline synchronously (best-effort). If it fails, we still send.
        ai_result = None
        try:
            ai_result = AIService.process_email(temp)
        except Exception as e:
            print(f"[ADMIN BROADCAST] AI preprocessing failed: {e}")

        # Store Broadcast record if we obtained results
        try:
            b = Broadcast(
                broadcast_id=broadcast_id,
                ai_summary=getattr(temp, 'ai_summary', None) or (ai_result.get('summary') if ai_result else None),
                ai_label_topic=getattr(temp, 'ai_label_topic', None) or (ai_result.get('topic') if ai_result else None),
                ai_label_urgency=getattr(temp, 'ai_label_urgency', None) or (ai_result.get('urgency') if ai_result else None),
                ai_label_source=getattr(temp, 'ai_label_source', None) or (ai_result.get('source') if ai_result else None),
                deadline_iso=getattr(temp, 'deadline_iso', None),
                deadline_confidence=getattr(temp, 'deadline_confidence', None) or (ai_result.get('deadline_confidence') if ai_result else None),
                academic_score=getattr(temp, 'academic_score', None) or (ai_result.get('academic_score') if ai_result else 0),
                notes=None
            )
            db.add(b)
            db.commit()
            print(f"[ADMIN BROADCAST] Stored Broadcast AI for {broadcast_id}")
        except Exception as e:
            print(f"[ADMIN BROADCAST] Failed to persist Broadcast AI: {e}")
    except Exception:
        # Non-fatal: do not block sending if preprocessing fails
        pass

    # 2. Get Admin's fresh access token
    try:
        access_token = get_access_token(decrypt_token(admin_token.refresh_token))
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Failed to refresh Google token: {e}")

    # 3. Construct the Email (MIME)
    message = EmailMessage()
    message.set_content(body_text)
    
    # We use BCC for broadcasts to protect student privacy
    message["Bcc"] = ", ".join(to_emails)
    message["From"] = admin_token.email
    message["Subject"] = subject
    
    # INJECT CUSTOM TRACKING HEADER
    message["X-UniDash-Broadcast-ID"] = broadcast_id

    # Base64 encode it for Gmail API (URL safe)
    encoded_message = base64.urlsafe_b64encode(message.as_bytes()).decode()

    # 4. Call the Gmail Send API
    headers = {"Authorization": f"Bearer {access_token}"}
    payload = {"raw": encoded_message}
    
    resp = requests.post(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
        headers=headers,
        json=payload,
        timeout=15
    )
    
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=f"Google API Error: {resp.text}")
        
    google_resp = resp.json()

    # Note: We are returning the broadcast_id so the frontend can display it or track it if necessary.
    # The moment the first student syncs their inbox, this broadcast_id will trigger the AI caching logic.
    return {
        "message": "Broadcast sent successfully.",
        "broadcast_id": broadcast_id,
        "google_message_id": google_resp.get("id"),
        "total_recipients": len(to_emails)
    }
