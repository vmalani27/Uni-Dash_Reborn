from contextlib import asynccontextmanager
import asyncio




from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


import os
from dotenv import load_dotenv


# Load dotenv file by name if provided, otherwise fall back to ../.env
dotenv_file = os.path.join(os.path.dirname(__file__), '..', '.env.dev')

# replace dev with prod based on branch, for feature branch stay on env.dev, 
from pathlib import Path
_dotenv_path = Path(dotenv_file)
if _dotenv_path.exists():
    load_dotenv(str(_dotenv_path))
    print("file loaded sucessfully")
else:
    # Fall back to default load (no-op if no .env present)
    load_dotenv()
    print("cant find file")


from app.routers import user_routers, oauth_routes, dashboard_routes
from app.routers import notifications
from app.routers import gmail_sync_routes
from app.routers import sync_events
from app.routers import health
from app.core import firebase_config  # Initialize Firebase Admin SDK
from app.services.background_scheduler import ingestion_loop, ai_processing_loop




@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background workers on startup, cancel on shutdown."""
    print("[LIFESPAN] Starting background workers…")
    ingestion_task = asyncio.create_task(ingestion_loop())
    ai_task = asyncio.create_task(ai_processing_loop())
    yield
    print("[LIFESPAN] Shutting down background workers…")
    ingestion_task.cancel()
    ai_task.cancel()
    
    for task in [ingestion_task, ai_task]:
        try:
            await task
        except asyncio.CancelledError:
            pass


app = FastAPI(lifespan=lifespan)

# Allow all origins for development and web app testing
# Note: Before production, this should be restricted to specific domains (e.g., your Firebase hosting URL)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Allows all origins
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


@app.get("/")
def root():
    return {"message": "Backend running"}
