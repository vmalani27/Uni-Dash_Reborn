from fastapi import FastAPI
from app.core.database import Base, engine
from app.models import user   # IMPORTANT: import your model files
from app.routers import user_routers, oauth_routes
from app.routers import notifications
from app.core import firebase_config




from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.jobs.gmail_sync import sync_all_gmail

app = FastAPI()



app.include_router(user_routers.router)
app.include_router(oauth_routes.router)
app.include_router(notifications.router)

@app.on_event("startup")
def run_gmail_sync_on_startup():
    db: Session = SessionLocal()
    print("[GMAIL SYNC JOB] Running Gmail sync for all users on startup...")
    sync_all_gmail(db)
    db.close()
    print("[GMAIL SYNC JOB] Done.")


@app.get("/")
def root():
    return {"message": "Backend running"}

