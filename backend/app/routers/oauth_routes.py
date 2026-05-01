import datetime
import os
import urllib.parse
import requests
import secrets
from cryptography.fernet import Fernet

from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.jobs.gmail_sync_job import initial_gmail_sync
from app.core.database import get_supabase_db, supabase_session_scope
from app.models.oauthToken import OAuthToken
from app.models.user import User
from app.utils.firebase_util import verify_firebase_token
from app.utils.encryption import encrypt_token, decrypt_token
from app.services.gmail_service import GmailService



router = APIRouter(prefix="/auth/google", tags=["Google OAuth"])


# In-memory state store for demo; use Redis/DB for production

state_store = {}

TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_REVOKE_URL = "https://oauth2.googleapis.com/revoke"

CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")
INITIAL_SYNC_LIMIT = int(os.getenv("INITIAL_GMAIL_SYNC_LIMIT", "20"))


def _get_redirect_url() -> str:
    local_redirect_url = (os.getenv("LOCAL_REDIRECT_URI") or "").strip()
    backend_redirect_url = (os.getenv("BACKEND_REDIRECT_URI") or "").strip()

    redirect_url = local_redirect_url or backend_redirect_url
    if not redirect_url:
        raise RuntimeError("Missing LOCAL_REDIRECT_URI and BACKEND_REDIRECT_URI")

    return redirect_url


REDIRECT_URL = _get_redirect_url()

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.announcements.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.students.readonly",
    "openid",
    "email",
    "profile",
]

ADMIN_SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
    "openid",
    "email",
    "profile",
]


def _revoke_google_token(refresh_token: str) -> bool:
    """Revoke a Google token. Google may return 200 for already-invalid tokens."""
    response = requests.post(
        GOOGLE_REVOKE_URL,
        params={"token": refresh_token},
        headers={"content-type": "application/x-www-form-urlencoded"},
        timeout=10,
    )
    return response.status_code == 200

# -------------------------------
# STEP 1: Generate Google OAuth URL
# -------------------------------
@router.get("/url")
def get_google_auth_url(
    redirect_to: str = "unidash://oauth/success",
    firebase_data=Depends(verify_firebase_token)
):
    uid = firebase_data["uid"]
    state = secrets.token_urlsafe(32)
    state_store[state] = {"uid": uid, "redirect_to": redirect_to}
    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URL,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent",
        "state": state,  # secure random state
    }
    url = GOOGLE_AUTH_URL + "?" + urllib.parse.urlencode(params)
    return {"auth_url": url}

@router.get("/admin/url")
def get_admin_google_auth_url(
    redirect_to: str = "unidash://admin/success",
    firebase_data=Depends(verify_firebase_token)
):
    uid = firebase_data["uid"]
    state = secrets.token_urlsafe(32)
    # Tagging the state map so we could handle it via custom logic if necessary in callback
    state_store[state] = {"uid": uid, "redirect_to": redirect_to, "role": "admin"}
    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URL,
        "response_type": "code",
        "scope": " ".join(ADMIN_SCOPES),
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    }
    url = GOOGLE_AUTH_URL + "?" + urllib.parse.urlencode(params)
    return {"auth_url": url}


# -------------------------------
# STEP 2: Google redirects here
# -------------------------------


@router.get("/callback")
def google_callback(
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_supabase_db),
):

    # Handles the Google OAuth callback after user authentication.
    # Why: Exchanges the authorization code for tokens, validates state, securely links Gmail access to the correct user, and triggers initial sync.
    
    
    code = request.query_params.get("code")
    state = request.query_params.get("state")
    if not code or not state:
        raise HTTPException(status_code=400, detail="Missing code or state")
    
    state_data = state_store.pop(state, None)
    if not state_data:
        raise HTTPException(status_code=400, detail="Invalid or expired state")
    
    uid = state_data["uid"]
    redirect_to = state_data.get("redirect_to", "unidash://oauth/success")

    # Exchange authorization code for tokens


    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URL,
    }
    resp = requests.post(TOKEN_URL, data=data, timeout=10)
    if resp.status_code != 200:
        raise HTTPException(status_code=400, detail=resp.text)

    token_response = resp.json()
    refresh_token = token_response.get("refresh_token")
    access_token = token_response.get("access_token")

    existing_token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    if not refresh_token and not existing_token:
        raise HTTPException(
            status_code=400,
            detail="No refresh token returned and no existing token found. Please reconnect Google with consent.",
        )

    # Fetch user email from Google
    userinfo_resp = requests.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=10
    )
    if userinfo_resp.status_code != 200:
        raise HTTPException(status_code=400, detail="Failed to fetch user info")
    user_info = userinfo_resp.json()
    email = user_info.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="No email in user info")

    # Calculate token expiry
    expires_in = token_response.get("expires_in")
    expires_at = None
    if expires_in:
        expires_at = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)


    # Store or update user's OAuth token


    token = existing_token
    if token:
        token.email = email
        if refresh_token:
            token.refresh_token = encrypt_token(refresh_token)
        token.expires_at = expires_at
        token.scopes = token_response.get("scope")
    else:
        token = OAuthToken(
            uid=uid,
            email=email,
            refresh_token=encrypt_token(refresh_token),
            scopes=token_response.get("scope"),
            expires_at=expires_at,
        )
        db.add(token)

    user = db.query(User).filter(User.uid == uid).first()
    if user:
        user.oauth_connected = True
        user.reauth_required = False
        user.reauth_required_at = None
        user.reauth_reason = None

    db.commit()


    # Trigger initial Gmail sync and start Pub/Sub watch in the background
    # Why: Ensures user's Gmail is synced immediately after OAuth and Pub/Sub is activated.
    
    
    print(f"Oauth logs: Triggering initial Gmail sync and Pub/Sub watch for user {uid}")
    if background_tasks is not None:

        def sync_and_watch_task(uid: str, limit: int):
            # Background task to perform initial Gmail sync and start Pub/Sub watch.
            # Why: Creates its own DB sessions for thread safety, syncs Gmail, activates Pub/Sub, and cleans up resources.
            with supabase_session_scope("oauth_callback_sync_watch_task") as supabase_db:
                initial_gmail_sync(uid, supabase_db, limit)
                
                # Get Pub/Sub topic from environment or use default
                topic_name = os.getenv(
                    "GMAIL_PUBSUB_TOPIC",
                    "projects/f-r-i-d-a-y-vlelfh/topics/gmail-notifications"
                )
                
                try:
                    print(f"Oauth logs: Starting Gmail watch for user {uid} on topic {topic_name}")
                    GmailService.start_gmail_watch(uid, supabase_db, topic_name)
                    print(f"Oauth logs: Gmail watch started successfully for user {uid}")
                except Exception as e:
                    print(f"Oauth logs: WARNING - Failed to start Gmail watch for user {uid}: {e}")
                    # Non-fatal error - sync already succeeded, watch can be retried daily

        background_tasks.add_task(sync_and_watch_task, uid, INITIAL_SYNC_LIMIT)
        print(f"Oauth logs: Background task (sync + watch) added for user {uid}")

    # Finalize OAuth in the browser by redirecting to the target URI captured in state.
    # Google callback requests do not include custom headers like x-platform.
    print(f"Oauth logs: Login succeeded, redirect_to={redirect_to}")
    return RedirectResponse(url=redirect_to)


@router.post("/disconnect")
def disconnect_google_account(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """Hard disconnect: revoke Google token, remove local OAuth token, and reset OAuth flags."""
    uid = firebase_data["uid"]

    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    user = db.query(User).filter(User.uid == uid).first()

    revoked = False
    if token and token.refresh_token:
        try:
            plain_refresh_token = decrypt_token(token.refresh_token)
            revoked = _revoke_google_token(plain_refresh_token)
        except Exception as e:
            # Do not block disconnect flow if Google revoke call fails.
            print(f"[OAUTH] Token revoke failed for uid={uid[:8]}: {e}")

    if token:
        db.delete(token)

    if user:
        user.oauth_connected = False
        user.reauth_required = False
        user.reauth_required_at = None
        user.reauth_reason = None

    db.commit()

    return {
        "status": "disconnected",
        "google_revoked": revoked,
    }
