import datetime
from datetime import timedelta
from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage, GmailSyncStatus
from app.services.gmail_service import GmailService
from app.core.database import SupabaseSession

def background_gmail_sync_job():
    """
    Run every 15 minutes to sync new emails for active users.
    Only syncs users who have had recent activity to save resources.
    """
    print(f"[BACKGROUND SYNC] Starting at {datetime.datetime.utcnow()}")
    
    supabase_db = SupabaseSession()
    
    try:
        # Get users with recent activity (last 24 hours)
        # This prevents syncing inactive users
        recent_cutoff = datetime.datetime.utcnow() - timedelta(hours=24)
        
        recent_users = supabase_db.query(GmailSyncStatus)\
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
                
                # Sync with smaller limit for background job
                print(f"[BACKGROUND SYNC] Syncing user {user_status.uid}")
                GmailService.incremental_sync(
                    user_status.uid, 
                    supabase_db, 
                    limit=20
                )
                sync_count += 1
                
            except Exception as e:
                error_count += 1
                print(f"[BACKGROUND SYNC] Error syncing user {user_status.uid}: {e}")
                
                # Update status to track errors
                user_status.status = "failed"
                user_status.finished_at = datetime.datetime.utcnow()
                user_status.error_message = f"Background sync error: {str(e)[:500]}"
        
        supabase_db.commit()
        print(f"[BACKGROUND SYNC] Complete - {sync_count} successful, {error_count} errors")
                
    except Exception as e:
        print(f"[BACKGROUND SYNC] Critical error: {e}")
    finally:
        supabase_db.close()

def cleanup_old_emails():
    """
    Remove emails older than 30 days to manage storage.
    Run daily as part of maintenance.
    """
    print(f"[CLEANUP] Starting email cleanup at {datetime.datetime.utcnow()}")
    
    supabase_db = SupabaseSession()
    try:
        cutoff_date = datetime.datetime.utcnow() - timedelta(days=30)
        
        # Count before deletion
        old_count = supabase_db.query(GmailMessage)\
            .filter(GmailMessage.internal_date < cutoff_date)\
            .count()
        
        if old_count > 0:
            # Delete old emails
            deleted = supabase_db.query(GmailMessage)\
                .filter(GmailMessage.internal_date < cutoff_date)\
                .delete()
            
            supabase_db.commit()
            print(f"[CLEANUP] Cleaned up {deleted} emails older than 30 days")
        else:
            print(f"[CLEANUP] No old emails to clean up")
            
    except Exception as e:
        print(f"[CLEANUP] Error during cleanup: {e}")
        supabase_db.rollback()
    finally:
        supabase_db.close()

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