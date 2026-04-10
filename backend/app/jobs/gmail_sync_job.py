
# Organized imports
from sqlalchemy.orm import Session
from sqlalchemy.exc import ProgrammingError
from app.models.oauthToken import OAuthToken
from app.models.user import User
from app.services.gmail_sync import sync_gmail_for_user
from app.core.database import SupabaseSessionLocal

# Initial sync for a single user
def initial_gmail_sync(uid, supabase_db, limit=300):
    try:
        sync_gmail_for_user(uid, supabase_db, limit=limit)
    except Exception as e:
        print(f"[GMAIL INITIAL SYNC ERROR] uid={uid}: {e}")

# Sync all users' Gmail
def sync_all_gmail(supabase_db: Session):
    try:
        tokens = (
            supabase_db.query(OAuthToken)
            .join(User, User.uid == OAuthToken.uid)
            .filter(OAuthToken.refresh_token != None)
            .filter(User.oauth_connected.is_(True))
            .all()
        )
    except ProgrammingError:
        print("[GMAIL SYNC JOB] Skipping: oauth_tokens table does not exist.")
        return
    if not tokens:
        print("[GMAIL SYNC JOB] Skipping: No oauth tokens found.")
        return
    for token in tokens:
        try:
            sync_gmail_for_user(token.uid, supabase_db)
        except Exception as e:
            print(f"[GMAIL SYNC ERROR] uid={token.uid}: {e}")

# Script entry point
if __name__ == "__main__":
    print("[GMAIL SYNC JOB] Starting Gmail sync for all users...")
    supabase_db = SupabaseSessionLocal()
    sync_all_gmail(supabase_db)
    supabase_db.close()
    print("[GMAIL SYNC JOB] Done.")
