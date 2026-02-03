import datetime
from datetime import timedelta
from app.models.oauthToken import OAuthToken
from app.models.gmail_sync_status import GmailSyncStatus
from app.services.gmail_sync import sync_gmail_for_user
from app.core.database import LocalSessionLocal, SupabaseSessionLocal

def background_gmail_sync_job():
    """
    Run every 15 minutes to sync new emails for active users.
    Only syncs users who have had recent activity to save resources.
    """
    print(f"[BACKGROUND SYNC] Starting at {datetime.datetime.utcnow()}")
    
    local_db = LocalSessionLocal()
    supabase_db = SupabaseSessionLocal()
    
    try:
        # Get users with recent activity (last 24 hours)
        # This prevents syncing inactive users
        recent_cutoff = datetime.datetime.utcnow() - timedelta(hours=24)
        
        recent_users = local_db.query(GmailSyncStatus)\
            .filter(GmailSyncStatus.started_at > recent_cutoff)\
            .filter(GmailSyncStatus.status.in_(['completed', 'failed']))\
            .all()
        
        print(f"[BACKGROUND SYNC] Found {len(recent_users)} recent active users")
        
        sync_count = 0
        error_count = 0
        
        for user_status in recent_users:
            try:
                # Check if user still has valid OAuth token
                token = supabase_db.query(OAuthToken)\
                    .filter(OAuthToken.uid == user_status.uid)\
                    .first()
                
                if not token:
                    print(f"[BACKGROUND SYNC] No token for user {user_status.uid}, skipping")
                    continue
                
                # Incremental sync with smaller limit for background job
                print(f"[BACKGROUND SYNC] Syncing user {user_status.uid}")
                sync_gmail_for_user(
                    user_status.uid, 
                    local_db, 
                    supabase_db, 
                    limit=20,        # Smaller limit for background
                    incremental=True # Only new emails
                )
                sync_count += 1
                
            except Exception as e:
                error_count += 1
                print(f"[BACKGROUND SYNC] Error syncing user {user_status.uid}: {e}")
                
                # Update status to track errors
                user_status.status = "failed"
                user_status.finished_at = datetime.datetime.utcnow()
                user_status.error_message = f"Background sync error: {str(e)[:500]}"
        
        local_db.commit()
        print(f"[BACKGROUND SYNC] Complete - {sync_count} successful, {error_count} errors")
                
    except Exception as e:
        print(f"[BACKGROUND SYNC] Critical error: {e}")
    finally:
        local_db.close()
        supabase_db.close()

def cleanup_old_emails():
    """
    Remove emails older than 30 days to manage storage.
    Run daily as part of maintenance.
    """
    from app.models.gmail_message import GmailMessage
    
    print(f"[CLEANUP] Starting email cleanup at {datetime.datetime.utcnow()}")
    
    local_db = LocalSessionLocal()
    try:
        cutoff_date = datetime.datetime.utcnow() - timedelta(days=30)
        
        # Count before deletion
        old_count = local_db.query(GmailMessage)\
            .filter(GmailMessage.internal_date < cutoff_date)\
            .count()
        
        if old_count > 0:
            # Delete old emails
            deleted = local_db.query(GmailMessage)\
                .filter(GmailMessage.internal_date < cutoff_date)\
                .delete()
            
            local_db.commit()
            print(f"[CLEANUP] Cleaned up {deleted} emails older than 30 days")
        else:
            print(f"[CLEANUP] No old emails to clean up")
            
    except Exception as e:
        print(f"[CLEANUP] Error during cleanup: {e}")
        local_db.rollback()
    finally:
        local_db.close()

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "sync":
            background_gmail_sync_job()
        elif command == "cleanup":
            cleanup_old_emails()
        else:
            print("Usage: python gmail_background_sync.py [sync|cleanup]")
    else:
        # Default to sync
        background_gmail_sync_job()