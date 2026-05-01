'''============== code approved by developer after review since the developer himself wrote it =============='''
from contextlib import contextmanager
import logging
import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

''' SupabaseSession: Connects to the cloud database (Supabase) for user and OAuth token management.

Notes: in future it maybe that the messages are stored in the cloud as well, but for now we want to keep them separate to reduce load on the cloud database and allow for faster read/write during sync operations. '''


USER_DATABASE_URL = os.getenv("USER_DATABASE_URL")

if USER_DATABASE_URL is None:
    raise ValueError("USER_DATABASE_URL is not set in environment variables")

# Supabase (cloud) engine/session for user & oauth.
# Bound the pool to avoid exhausting provider limits under bursty background work.
supabase_engine = create_engine(
    USER_DATABASE_URL,
    pool_size=5,
    max_overflow=10,
    pool_timeout=30,
    pool_recycle=1800,
    pool_pre_ping=True,
    future=True,
)
SupabaseSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=supabase_engine)

logger = logging.getLogger(__name__)

Base = declarative_base()


@contextmanager
def supabase_session_scope(context: str = "unknown"):
    db = SupabaseSessionLocal()
    logger.info("[DB] Session opened (%s)", context)
    try:
        yield db
    except Exception as exc:
        logger.exception("[DB] Session error (%s): %s", context, exc)
        raise
    finally:
        db.close()
        logger.info("[DB] Session closed (%s)", context)


def get_supabase_db():
    db = SupabaseSessionLocal()
    logger.info("[DB] Session opened (http_request)")
    try:
        yield db
    except Exception as exc:
        logger.exception("[DB] Session error (http_request): %s", exc)
        raise
    finally:
        db.close()
        logger.info("[DB] Session closed (http_request)")

