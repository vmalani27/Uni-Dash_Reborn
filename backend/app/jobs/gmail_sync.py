from app.models.oauthToken import OAuthToken
from app.services.gmail_sync import sync_gmail_for_user

def initial_gmail_sync(uid, local_db, supabase_db, limit=100):
    try:
        sync_gmail_for_user(uid, local_db, supabase_db, limit=limit)
    except Exception as e:
        print(f"[GMAIL INITIAL SYNC ERROR] uid={uid}: {e}")
from app.models.gmail_message import GmailMessage
from app.core.database import get_local_db, get_supabase_db, LocalSessionLocal, SupabaseSessionLocal
from sqlalchemy.orm import Session

def sync_all_gmail(local_db: Session, supabase_db: Session):
    # Check if oauth_tokens table exists
    from sqlalchemy.exc import ProgrammingError
    try:
        tokens = supabase_db.query(OAuthToken).filter(OAuthToken.refresh_token != None).all()
    except ProgrammingError as e:
        print("[GMAIL SYNC JOB] Skipping: oauth_tokens table does not exist.")
        return
    if not tokens:
        print("[GMAIL SYNC JOB] Skipping: No oauth tokens found.")
        return
    for token in tokens:
        try:
            sync_gmail_for_user(token.uid, local_db)
        except Exception as e:
            print(f"[GMAIL SYNC ERROR] uid={token.uid}: {e}")

if __name__ == "__main__":
    import sys
    import os
    import time
    print("[GMAIL SYNC JOB] Starting Gmail sync for all users...")
    local_db = LocalSessionLocal()
    supabase_db = SupabaseSessionLocal()
    sync_all_gmail(local_db, supabase_db)
    local_db.close()
    supabase_db.close()
    print("[GMAIL SYNC JOB] Done.")
