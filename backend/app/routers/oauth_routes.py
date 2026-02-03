import datetime
import os
import urllib.parse
import requests
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.models.oauthToken import OAuthToken
from app.utils.firebase_util import verify_firebase_token

router = APIRouter(prefix="/auth/google", tags=["Google OAuth"])

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
def get_google_auth_url(firebase_data=Depends(verify_firebase_token)):
    uid = firebase_data["uid"]

    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URL,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent",
        "state": uid,  # link callback to user
    }

    url = GOOGLE_AUTH_URL + "?" + urllib.parse.urlencode(params)
    print(f"[OAUTH DEBUG] Generated URL: {url}")
    print(f"[OAUTH DEBUG] CLIENT_ID: {CLIENT_ID}")
    print(f"[OAUTH DEBUG] CLIENT_SECRET: {CLIENT_SECRET}")
    return {"auth_url": url}


# -------------------------------
# STEP 2: Google redirects here
# -------------------------------

from fastapi import BackgroundTasks
from app.jobs.gmail_sync import initial_gmail_sync
from app.core.database import get_local_db

@router.get("/callback")
def google_callback(
    request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_supabase_db),
):
    code = request.query_params.get("code")
    uid = request.query_params.get("state")

    if not code or not uid:
        raise HTTPException(status_code=400, detail="Missing code or state")

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

    if not refresh_token:
        raise HTTPException(status_code=400, detail="No refresh token returned")

    expires_in = token_response.get("expires_in")
    expires_at = None
    if expires_in:
        expires_at = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)

    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    if token:
        token.refresh_token = refresh_token
        token.expires_at = expires_at
        token.scopes = token_response.get("scope")
    else:
        token = OAuthToken(
            uid=uid,
            refresh_token=refresh_token,
            scopes=token_response.get("scope"),
            expires_at=expires_at,
        )
        db.add(token)

    db.commit()

    print(f"[OAUTH CALLBACK] OAuth token saved for user {uid}")
    
    # Trigger initial Gmail sync (limit 100 mails)
    print(f"[OAUTH CALLBACK] Triggering initial Gmail sync for user {uid}")
    if background_tasks is not None:
        from app.core.database import LocalSessionLocal
        local_db = LocalSessionLocal()  # For gmail messages and sync status
        background_tasks.add_task(initial_gmail_sync, uid, local_db, db, 100)
        print(f"[OAUTH CALLBACK] Background task added for user {uid}")

    # Redirect to app using deep link
    print(f"[OAUTH CALLBACK] Redirecting to app via deep link")
    return RedirectResponse(url="unidash://oauth/success")
