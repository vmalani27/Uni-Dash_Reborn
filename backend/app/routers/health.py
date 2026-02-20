from fastapi import APIRouter
from app.services.background_scheduler import get_uptime

router = APIRouter()


@router.get("/health")
def health_check():
    """Health check endpoint confirming backend and scheduler are alive."""
    uptime = get_uptime()
    return {
        "status": "ok",
        "scheduler": "running" if uptime > 0 else "starting",
        "uptime_seconds": uptime,
    }
