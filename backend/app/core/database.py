
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os
from dotenv import load_dotenv

load_dotenv()

USER_DATABASE_URL = os.getenv("USER_DATABASE_URL")
LOCAL_DATABASE_URL = os.getenv("LOCAL_DATABASE_URL")

if USER_DATABASE_URL is None or LOCAL_DATABASE_URL is None:
    raise ValueError("USER_DATABASE_URL or LOCAL_DATABASE_URL is not set in environment variables")

# Supabase (cloud) engine/session for user & oauth
supabase_engine = create_engine(USER_DATABASE_URL, pool_pre_ping=True, future=True)
SupabaseSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=supabase_engine)

# Local engine/session for gmail messages
local_engine = create_engine(LOCAL_DATABASE_URL, pool_pre_ping=True, future=True)
LocalSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=local_engine)

Base = declarative_base()

def get_supabase_db():
    db = SupabaseSessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_local_db():
    db = LocalSessionLocal()
    try:
        yield db
    finally:
        db.close()
