from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.services.background_scheduler import get_uptime, get_worker_status
from app.core.database import get_supabase_db
from app.models.gmail.gmail_message import GmailMessage
from app.models.gmail.gmail_sync_status import GmailSyncStatus

router = APIRouter()


@router.get("/health")
def health_check(db: Session = Depends(get_supabase_db)):
    """Health check endpoint with real-time worker status."""
    uptime = get_uptime()
    worker_status = get_worker_status()

    total_emails_synced = db.query(GmailMessage).count()
    total_emails_processed = db.query(GmailMessage).filter(GmailMessage.ai_processed.is_(True)).count()
    domain_stats_updates = db.query(GmailSyncStatus).filter(
        GmailSyncStatus.watch_expiration.isnot(None)
    ).count()

    return {
        "status": "ok",
        "uptime_seconds": uptime,
        "workers": worker_status["workers"],
        "summary": {
            "total_emails_synced": total_emails_synced,
            "total_emails_processed": total_emails_processed,
            "domain_stats_updates": domain_stats_updates,
            "all_workers_healthy": all(
                w["status"] in ["running", "idle", "waiting_for_users"] 
                for w in worker_status["workers"].values()
            )
        }
    }


@router.get('/health/db', summary='Check DB connectivity')
def health_db_check(db: Session = Depends(get_supabase_db)):
    """Simple endpoint to verify database connectivity. Returns 200 if DB responds to a trivial query."""
    try:
        # Perform a trivial select; SQLAlchemy Core execution
        result = db.execute(text("SELECT 1")).scalar()
        ok = bool(result == 1 or result == '1')
        return {"status": "ok" if ok else "error", "db_response": result}
    except Exception as e:
        return {"status": "error", "error": str(e)}
