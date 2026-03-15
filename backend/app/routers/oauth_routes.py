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
from app.core.database import get_supabase_db, SupabaseSessionLocal
from app.models.oauthToken import OAuthToken
from app.utils.firebase_util import verify_firebase_token
from app.utils.encryption import encrypt_token, decrypt_token



router = APIRouter(prefix="/auth/google", tags=["Google OAuth"])


# In-memory state store for demo; use Redis/DB for production

state_store = {}

TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"

CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")
REDIRECT_URL = os.getenv("BACKEND_REDIRECT_URI")

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.announcements.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.students.readonly",
    "openid",
    "email",
    "profile",
]

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
    if not refresh_token:
        raise HTTPException(status_code=400, detail="No refresh token returned")

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


    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    if token:
        token.email = email
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
    db.commit()


    # Trigger initial Gmail sync in the background
    # Why: Ensures user's Gmail is synced immediately after OAuth, without blocking the HTTP response.
    
    
    print(f"Oauth logs: Triggering initial Gmail sync for user {uid}")
    if background_tasks is not None:

        def sync_task(uid: str, limit: int):
            # Background task to perform initial Gmail sync for the user.
            # Why: Creates its own DB sessions for thread safety, syncs Gmail, and cleans up resources.
            supabase_db = SupabaseSessionLocal()
            try:
                initial_gmail_sync(uid, supabase_db, limit)
            except Exception:
                supabase_db.rollback()
                raise
            finally:
                supabase_db.close()

        background_tasks.add_task(sync_task, uid, 100)
        print(f"Oauth logs: Background task added for user {uid}")

    # Redirect to app using deep link
    # Why: Signals frontend that OAuth succeeded and user can proceed.


    print(f"Oauth logs: Login succeeded, Redirecting to {redirect_to}")
    return RedirectResponse(url=redirect_to)
