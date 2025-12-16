import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.oauthToken import OAuthToken
from app.utils.firebase_util import verify_firebase_token
import urllib.parse
import os
import requests

router = APIRouter(prefix="/auth/google", tags=["Google OAuth"])

TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
CLIENT_SECRET = os.getenv("CLIENT_SECRET")
CLIENT_ID = os.getenv("CLIENT_ID")
REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI")

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.announcements.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.students.readonly",
    "openid",
    "email",
    "profile"
]

# @router.get("/url")
# def get_google_oauth_url(firebase_data=Depends(verify_firebase_token)):
#     uid = firebase_data["uid"]

#     params = {
#         "client_id": CLIENT_ID,
#         "redirect_uri": REDIRECT_URI,
#         "response_type": "code",
#         "scope": " ".join(SCOPES),
#         "access_type": "offline",
#         "prompt": "consent",
#         "state": uid,
#         "include_granted_scopes": "true",
#     }

#     url = GOOGLE_AUTH_URL + "?" + urllib.parse.urlencode(params)
#     return {"auth_url": url}

@router.post("/exchange")
def exchange_google_code(
    payload: dict,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_db)
):
    code = payload.get("code")
    if not code:
        raise HTTPException(status_code=400, detail="Authorization code missing")

    uid = firebase_data["uid"]

    # Exchange code for tokens with Google
    data = {
        "code": code,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code",
    }

    google_response = requests.post(TOKEN_URL, data=data)
    token_data = google_response.json()

    if "error" in token_data:
        print("Google OAuth error:", token_data)
        raise HTTPException(status_code=400, detail=token_data.get("error_description", "OAuth exchange failed"))

    access_token = token_data.get("access_token")
    refresh_token = token_data.get("refresh_token")
    expires_in = token_data.get("expires_in", 3600)
    scope = token_data.get("scope", "")
    token_type = token_data.get("token_type", "Bearer")

    expires_at = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)

    db_token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()

    if db_token:
        db_token.access_token = access_token
        db_token.expires_at = expires_at
        db_token.token_type = token_type
        if refresh_token:
            db_token.refresh_token = refresh_token
    else:
        db_token = OAuthToken(
            uid=uid,
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=expires_at,
            scopes=scope,
            token_type=token_type,
        )
        db.add(db_token)

    db.commit()

    return {
        "success": True,
        "message": "Google OAuth connected successfully",
        "expires_at": expires_at.isoformat(),
        "has_refresh_token": refresh_token is not None,
    }