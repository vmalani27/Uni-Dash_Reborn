# Uni-Dash Reborn Backend

The backend for Uni-Dash Reborn is a high-performance, asynchronous API gateway built with **FastAPI**. It manages OAuth authentication, synchronizes student emails, and coordinates AI processing between the edge node (Raspberry Pi) and a GPU inference machine.

## Key Features

- **OAuth 2.0 Integration:** Securely handles Google/Gmail authentication with encrypted token storage.
- **Distributed Sync Worker:** Background jobs for full and incremental Gmail sync, optimizing coverage and API quotas.
- **AI Processing Pipeline:** Decouples heavy MIME parsing and extraction from the main request/response cycle.
- **Background Workers:** Automatic ingestion and AI classification loops via FastAPI Lifespan.
- **Resilient Middleware:** Built-in error handling for token revocation and connectivity issues.

## Architecture

```mermaid
graph LR
    subgraph Edge_Node[API Broker]
        FastAPI[FastAPI Gateway]
        Ingestion[Ingestion Worker]
        AI_Worker[AI Processing Worker]
    end
    
    subgraph Storage[Cloud Persistence]
        DB[(Supabase PostgreSQL)]
    end
    
    FastAPI <--> DB
    Ingestion --> DB
    AI_Worker <--> DB
```

## Setup & Installation

### 1. Prerequisites
- Python 3.10+
- PostgreSQL (or Supabase)
- Ngrok (for local development exposing)

### 2. Local Environment Setup
1. **Database Initialization:**
   ```sql
   CREATE DATABASE unidash;
   CREATE USER unidash_user WITH PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE unidash TO unidash_user;
   ```
2. **Environment Variables:** Create a `.env` file in this directory:
   ```env
   USER_DATABASE_URL=postgresql://user:pass@host:5432/dbname
   CLIENT_ID=your_google_id
   CLIENT_SECRET=your_google_secret
   BACKEND_REDIRECT_URI=https://your-ngrok-url/auth/google/callback
   ENCRYPTION_KEY=fernet_key_here
   firebase_config_path=path/to/firebase.json
   OLLAMA_URL=http://your-gpu-machine:11434/api/generate
   ```
3. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
4. **Database Migrations:**
   ```bash
   alembic upgrade head
   ```
   
### Alembic: Auto-generate & Run Migrations

If you've changed SQLAlchemy models and need to create a migration, use Alembic's autogenerate feature:

1. Create an auto-generated revision (run from the `backend` directory):
```bash
PYTHONPATH=$(pwd) alembic revision --autogenerate -m "Describe your change"
```

2. Inspect the generated file under `alembic/versions/` and edit if necessary.

3. Apply the migration to your database:
```bash
PYTHONPATH=$(pwd) alembic upgrade head
```

Notes:
- Ensure your `alembic.ini` is configured to use the correct `sqlalchemy.url` (or read from env). The project's `alembic/env.py` is configured to import `app` models when `PYTHONPATH` includes the `backend` folder.
- If Alembic reports multiple heads, inspect `alembic/versions/` and set correct `down_revision` values or merge heads with:
```bash
alembic merge -m "merge heads" <head1> <head2>
```

### 3. Running Locally
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Docker Support

The backend can be containerized for consistent deployment.

1. **Build the Image:**
   ```bash
   docker build -t unidash-backend -f ../Dockerfile ..
   ```
   *(Note: The Dockerfile assumes context is the root directory)*

2. **Run the Container:**
   ```bash
   docker run -p 8000:8000 --env-file .env unidash-backend
   ```

## Project Structure

- `app/main.py`: Application entry point and lifespan management.
- `app/routers/`: API endpoints (OAuth, Gmail Sync, Notifications, etc.)
- `app/services/`: Core logic for sync, background loops, and AI interaction.
- `app/models/`: SQLAlchemy models for tokens, emails, and sync status.
- `app/utils/`: Helper functions for encryption, Firebase, and Google APIs.

## API Endpoints (Primary)
- `/auth/google/url`: Get URL for Google authentication.
- `/gmail/sync`: Trigger a core sync cycle.
- `/gmail/sync/status`: Monitor current sync progress.
- `/gmail/messages`: Access classified academic emails.

---
*Developed as part of the Uni-Dash Reborn ecosystem.*