from fastapi import FastAPI
from app.core.database import Base, supabase_engine, local_engine
from app.models import user   # IMPORTANT: import your model files
from app.routers import user_routers, oauth_routes
from app.routers import notifications
from app.core import firebase_config
from app.routers import gmail_sync




from sqlalchemy.orm import Session
from app.core.database import SupabaseSessionLocal, LocalSessionLocal
from app.jobs.gmail_sync import sync_all_gmail


app = FastAPI()

app.include_router(user_routers.router)
app.include_router(oauth_routes.router)
app.include_router(notifications.router)
app.include_router(gmail_sync.router)

# ---
# To create tables, run this manually in a script or shell, not on every startup:
# Base.metadata.create_all(supabase_engine)
# Base.metadata.create_all(local_engine)
# ---



@app.get("/")
def root():
    return {"message": "Backend running"}

