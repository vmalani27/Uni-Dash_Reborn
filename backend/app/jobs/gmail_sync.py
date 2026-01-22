from app.models.oauthToken import OAuthToken
from app.services.gmail_sync import sync_gmail_for_user
from app.models.gmail_message import GmailMessage
from app.core.database import get_db
from sqlalchemy.orm import Session

def sync_all_gmail(db: Session):
    # Check if oauth_tokens table exists
    from sqlalchemy.exc import ProgrammingError
    try:
        tokens = db.query(OAuthToken).filter(OAuthToken.refresh_token != None).all()
    except ProgrammingError as e:
        print("[GMAIL SYNC JOB] Skipping: oauth_tokens table does not exist.")
        return
    if not tokens:
        print("[GMAIL SYNC JOB] Skipping: No oauth tokens found.")
        return
    for token in tokens:
        try:
            sync_gmail_for_user(token.uid, db)
        except Exception as e:
            print(f"[GMAIL SYNC ERROR] uid={token.uid}: {e}")

if __name__ == "__main__":
    import sys
    import os
    import time
    from fastapi import Depends
    from app.core.database import SessionLocal

    db = SessionLocal()
    print("[GMAIL SYNC JOB] Starting Gmail sync for all users...")
    sync_all_gmail(db)
    db.close()
    print("[GMAIL SYNC JOB] Done.")
