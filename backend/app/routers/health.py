from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.services.background_scheduler import get_uptime, get_worker_status
from app.core.database import get_supabase_db

router = APIRouter()


@router.get("/health")
def health_check():
    """Health check endpoint with real-time worker status."""
    uptime = get_uptime()
    worker_status = get_worker_status()

    return {
        "status": "ok",
        "uptime_seconds": uptime,
        "workers": worker_status["workers"],
        "summary": {
            "total_emails_synced": worker_status["workers"]["ingestion"]["total_synced"],
            "total_emails_processed": worker_status["workers"]["ai_processing"]["total_processed"],
            "domain_stats_updates": worker_status["workers"]["domain_stats"]["total_updates"],
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
