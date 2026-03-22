import sys
import os
from logging.config import fileConfig
from sqlalchemy import create_engine, pool
from sqlalchemy.engine import URL
from alembic import context
from dotenv import load_dotenv

# Load dotenv file by name if provided, otherwise fall back to ../.env
dotenv_file = os.path.join(os.path.dirname(__file__), '..', '.env.prod')
from pathlib import Path
_dotenv_path = Path(dotenv_file)
if _dotenv_path.exists():
    load_dotenv(str(_dotenv_path))
    print(f"Loaded dotenv from: {_dotenv_path}")
else:
    # Fall back to default load (no-op if no .env present)
    load_dotenv()
    print(f"Dotenv file not found at {_dotenv_path}; called load_dotenv() fallback")

# add project root / app to path so we can import app package
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from configparser import ConfigParser

config = context.config

# Disable interpolation
config._config = ConfigParser(interpolation=None)

fileConfig(config.config_file_name)

# Disable interpolation again after fileConfig to prevent issues with URLs containing %
config._config = ConfigParser(interpolation=None)

# Set DB URL from .env components
from os import getenv


db_user = getenv("DB_USER")
db_pass = getenv("DB_PASS")
db_host = getenv("DB_HOST")
db_port = getenv("DB_PORT")
db_name = getenv("DB_NAME")

# Debug prints
print("DB_USER:", db_user)
print("DB_PASS:", "***masked***" if db_pass else None)
print("DB_HOST:", db_host)
print("DB_PORT:", db_port)
print("DB_NAME:", db_name)

if all([db_user, db_pass, db_host, db_port, db_name]):
    # URL construction for potential future use, but not needed for migrations
    db_url = URL.create(
        "postgresql+psycopg2",
        username=db_user,
        password=db_pass,
        host=db_host,
        port=int(db_port),
        database=db_name,
    )
    print("Constructed URL:", str(db_url).replace(db_pass, "***masked***") if db_pass else str(db_url))
    # Note: Not setting config.set_main_option since we use direct engine creation

# Import your SQLAlchemy Base and models so target_metadata is populated
# Adjust import paths to match your project layout
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'app'))
from app.core.database import Base    # <- your declarative_base()
# import all modules that define models so SQLAlchemy picks them up
import app.models  # This triggers app/models/__init__.py and registers all models
print("TABLES SEEN BY ALEMBIC:", Base.metadata.tables.keys())

target_metadata = Base.metadata


def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    db_url = URL.create(
        drivername="postgresql+psycopg2",
        username=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS"),
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT")),
        database=os.getenv("DB_NAME"),
    )

    engine = create_engine(db_url)

    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
