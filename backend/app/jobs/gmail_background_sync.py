import datetime
from datetime import timedelta
from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_message import GmailMessage
from app.models.gmail.gmail_sync_status import GmailSyncStatus
from app.services.gmail_service import GmailService
from app.core.database import SupabaseSessionLocal, supabase_session_scope

def background_gmail_sync_job():
    """
    Run every 15 minutes to sync new emails for active users.
    Only syncs users who have had recent activity to save resources.
    """
    print(f"[BACKGROUND SYNC] Starting at {datetime.datetime.utcnow()}")
    
    supabase_db = SupabaseSessionLocal()
    
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

def daily_maintenance_job(topic_name: str):
    """
    Run daily to renew expiring Gmail watches and sync failed users.
    This prevents Pub/Sub notifications from stopping after 7 days.
    
    Args:
        topic_name: Full Pub/Sub topic path (e.g., 'projects/my-project/topics/gmail-notifications')
    """
    print(f"[DAILY MAINTENANCE] Starting at {datetime.datetime.utcnow()}")
    
    supabase_db = SupabaseSessionLocal()
    
    try:
        # 1. RENEW EXPIRING WATCHES
        # Check for watches expiring in the next 24 hours
        tomorrow = datetime.datetime.utcnow() + timedelta(days=1)
        
        expiring_soon = supabase_db.query(GmailSyncStatus)\
            .filter(GmailSyncStatus.watch_expiration != None)\
            .filter(GmailSyncStatus.watch_expiration < tomorrow)\
            .all()
        
        print(f"[DAILY MAINTENANCE] Found {len(expiring_soon)} users with expiring watches")
        
        renewal_count = 0
        renewal_errors = 0
        
        for user_status in expiring_soon:
            try:
                token = supabase_db.query(OAuthToken)\
                    .filter(OAuthToken.uid == user_status.uid)\
                    .first()
                
                if not token:
                    print(f"[DAILY MAINTENANCE] No token for user {user_status.uid}, skipping renewal")
                    continue
                
                # Renew the watch
                print(f"[DAILY MAINTENANCE] Renewing watch for user {user_status.uid}")
                GmailService.start_gmail_watch(user_status.uid, supabase_db, topic_name)
                renewal_count += 1
                
            except Exception as e:
                renewal_errors += 1
                print(f"[DAILY MAINTENANCE] Error renewing watch for user {user_status.uid}: {e}")
        
        # 2. SYNC FAILED USERS (Secondary benefit - catch any missed emails)
        recent_cutoff = datetime.datetime.utcnow() - timedelta(hours=24)
        
        failed_users = supabase_db.query(GmailSyncStatus)\
            .filter(GmailSyncStatus.status == 'failed')\
            .filter(GmailSyncStatus.finished_at > recent_cutoff)\
            .all()
        
        print(f"[DAILY MAINTENANCE] Found {len(failed_users)} users with recent failures")
        
        recovery_count = 0
        recovery_errors = 0
        
        for user_status in failed_users:
            try:
                token = supabase_db.query(OAuthToken)\
                    .filter(OAuthToken.uid == user_status.uid)\
                    .first()
                
                if not token:
                    print(f"[DAILY MAINTENANCE] No token for user {user_status.uid}, skipping recovery")
                    continue
                
                # Retry failed sync
                print(f"[DAILY MAINTENANCE] Retrying sync for user {user_status.uid}")
                GmailService.incremental_sync(user_status.uid, supabase_db, limit=50)
                recovery_count += 1
                
            except Exception as e:
                recovery_errors += 1
                print(f"[DAILY MAINTENANCE] Error recovering user {user_status.uid}: {e}")
        
        supabase_db.commit()
        print(f"[DAILY MAINTENANCE] Complete - {renewal_count} watches renewed ({renewal_errors} errors), {recovery_count} users recovered ({recovery_errors} errors)")
                
    except Exception as e:
        print(f"[DAILY MAINTENANCE] Critical error: {e}")
    finally:
        supabase_db.close()

def cleanup_old_emails():
    """
    Remove emails older than 30 days to manage storage.
    Run daily as part of maintenance.
    """
    print(f"[CLEANUP] Starting email cleanup at {datetime.datetime.utcnow()}")
    
    supabase_db = SupabaseSessionLocal()
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
        elif command == "maintenance":
            # Usage: python gmail_background_sync.py maintenance "projects/YOUR_PROJECT/topics/gmail-notifications"
            topic_name = sys.argv[2] if len(sys.argv) > 2 else "projects/f-r-i-d-a-y-vlelfh/topics/gmail-notifications"
            daily_maintenance_job(topic_name)
        else:
            print("Usage: python gmail_background_sync.py [sync|cleanup|maintenance <topic_name>]")
    else:
        # Default to sync
        background_gmail_sync_job()