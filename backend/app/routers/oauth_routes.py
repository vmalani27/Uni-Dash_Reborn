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
CLIENT_ID = os.getenv("ANDROID_GOOGLE_CLIENT_ID")
REDIRECT_URL = os.getenv("REDIRECT_URL")

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.announcements.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.students.readonly",
    "openid",
    "email",
    "profile"
]


@router.post("/exchange")
def exchange_google_refresh_token(
    payload: dict,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    code = payload.get("code")
    code_verifier = payload.get("code_verifier")

    if not code or not code_verifier:
        raise HTTPException(status_code=400, detail="Missing code or code_verifier")

    data = {
        "client_id": CLIENT_ID,
        "grant_type": "authorization_code",
        "code": code,
        "code_verifier": code_verifier,
        "redirect_uri": REDIRECT_URL,
    }

    resp = requests.post(TOKEN_URL, data=data, timeout=10)

    if resp.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Google exchange failed: {resp.text}")

    token_response = resp.json()

    refresh_token = token_response.get("refresh_token")
    access_token = token_response.get("access_token")
    id_token = token_response.get("id_token")
    scope = token_response.get("scope")
    expires_in = token_response.get("expires_in")
    expires_at = None
    if expires_in is not None:
        expires_at = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)


    if not refresh_token:
        raise HTTPException(status_code=400, detail="No refresh_token returned by Google")

    uid = firebase_data["uid"]


    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()

    if token:
        token.refresh_token = refresh_token
        token.scopes = scope
        if expires_at is not None:
            token.expires_at = expires_at
    else:
        token = OAuthToken(
            uid=uid,
            refresh_token=refresh_token,
            scopes=scope,
            expires_at=expires_at if expires_at is not None else None,
        )
        db.add(token)

    db.commit()

    return {
        "success": True,
        "message": "Google account connected",
    }
