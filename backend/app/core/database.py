'''============== code approved by developer after review since the developer himself wrote it =============='''
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker, declarative_base
import os
from fastapi import HTTPException

''' SupabaseSession: Connects to the cloud database (Supabase) for user and OAuth token management.

Notes: in future it maybe that the messages are stored in the cloud as well, but for now we want to keep them separate to reduce load on the cloud database and allow for faster read/write during sync operations. '''



USER_DATABASE_URL = os.getenv("USER_DATABASE_URL")

if USER_DATABASE_URL is None:
    raise ValueError("USER_DATABASE_URL is not set in environment variables")

# Supabase (cloud) engine/session for user & oauth
supabase_engine = create_engine(USER_DATABASE_URL, pool_pre_ping=True, future=True)
SupabaseSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=supabase_engine)


Base = declarative_base()

def get_supabase_db():
    # Perform a quick connectivity check so HTTP handlers receive a clear
    # 503 response when the cloud user DB is unreachable instead of raising
    # an internal 500 during query execution.
    try:
        # Try acquiring a lightweight connection from the engine.
        conn = supabase_engine.connect()
        conn.close()
    except OperationalError as e:
        # Convert low-level DB connectivity errors into a service-unavailable
        # HTTP response. This prevents unhandled tracebacks from surfacing
        # to callers and makes the failure explicit for the frontend.
        raise HTTPException(status_code=503, detail="User database unreachable")

    db = SupabaseSessionLocal()
    try:
        yield db
    finally:
        db.close()

