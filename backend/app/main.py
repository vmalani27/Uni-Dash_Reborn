from contextlib import asynccontextmanager
import asyncio




from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


import os
from dotenv import load_dotenv

# Load environment variables from .env and .env.local (prioritize .env.local for local dev)
load_dotenv()
load_dotenv(".env", override=True)


from app.routers import user_routers, oauth_routes, dashboard_routes
from app.routers import notifications
from app.routers import gmail_sync_routes
from app.routers import sync_events
from app.routers import health
from app.routers import admin_routes
from app.routers import item_routes
from app.routers import entities_routes
from app.core import firebase_config  # Initialize Firebase Admin SDK
from app.services.background_scheduler import ingestion_loop, ai_processing_loop, daily_maintenance_loop
from app.services.ai_service import AIService
from app.services.sync_event_bus import ensure_redis_ready
import datetime
from datetime import timedelta


def _recover_orphaned_syncs():
    """
    Recover from crashes: reset syncs stuck in 'in_progress' state for >30 min.
    Called on app startup.
    """
    from app.core.database import supabase_session_scope
    from app.models.gmail.gmail_sync_status import GmailSyncStatus

    try:
        with supabase_session_scope("recover_orphaned_syncs") as db:
            cutoff = datetime.datetime.utcnow() - timedelta(minutes=30)

            orphaned = db.query(GmailSyncStatus).filter(
                GmailSyncStatus.status == "in_progress",
                GmailSyncStatus.started_at < cutoff
            ).all()

            if orphaned:
                for sync in orphaned:
                    print(
                        f"[RECOVERY] Marking orphaned sync as failed for {sync.uid[:8]}… "
                        f"(started {(datetime.datetime.utcnow() - sync.started_at).total_seconds() / 60:.0f} min ago)"
                    )
                    sync.status = "failed"
                    sync.error_message = "Orphaned sync (worker crash or timeout). Please retry manually."
                    sync.finished_at = datetime.datetime.utcnow()

                db.commit()
                print(f"[RECOVERY] Recovered {len(orphaned)} orphaned sync(es).")
    except Exception as e:
        print(f"[RECOVERY] Failed to recover orphaned syncs: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background workers on startup, cancel on shutdown."""
    print("[LIFESPAN] Starting background workers…")
    await asyncio.to_thread(ensure_redis_ready)
    await asyncio.to_thread(AIService.initialize_inference_backend)
    
    # Recover orphaned syncs from previous crashes/restarts
    print("[LIFESPAN] Recovering orphaned syncs…")
    await asyncio.to_thread(_recover_orphaned_syncs)
    
    ingestion_task = asyncio.create_task(ingestion_loop())
    ai_task = asyncio.create_task(ai_processing_loop())
    maintenance_task = asyncio.create_task(daily_maintenance_loop())
    yield
    print("[LIFESPAN] Shutting down background workers…")
    ingestion_task.cancel()
    ai_task.cancel()
    maintenance_task.cancel()
    
    for task in [ingestion_task, ai_task, maintenance_task]:
        try:
            await task
        except asyncio.CancelledError:
            pass


app = FastAPI(lifespan=lifespan)

# Allow all origins for development and web app testing
# Note: Before production, this should be restricted to specific domains (e.g., your Firebase hosting URL)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

app.include_router(user_routers.router)
app.include_router(oauth_routes.router)
app.include_router(dashboard_routes.router)
app.include_router(notifications.router)
app.include_router(gmail_sync_routes.router)
app.include_router(sync_events.router)
app.include_router(health.router)
app.include_router(admin_routes.router)
app.include_router(item_routes.router)
app.include_router(entities_routes.router)


@app.get("/")
def root():
    return {"message": "Backend running"}
