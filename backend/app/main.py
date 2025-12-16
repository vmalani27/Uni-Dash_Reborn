from fastapi import FastAPI
from app.core.database import Base, engine
from app.models import user   # IMPORTANT: import your model files
from app.routers import user_routers, oauth_routes
from app.core import firebase_config


# Create tables
Base.metadata.create_all(bind=engine)


app = FastAPI()

app.include_router(user_routers.router)
app.include_router(oauth_routes.router)


@app.get("/")
def root():
    return {"message": "Backend running"}

