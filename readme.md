# Uni-Dash: AI-Powered Academic Email Platform

Uni-Dash is a distributed, AI-augmented email dashboard built for university students. It solves the problem of academic email overload by automatically syncing, parsing, and classifying student emails into actionable insights (e.g., deadlines, exam notifications, fees) using local Large Language Models (LLMs).

Unlike traditional monolithic student projects, Uni-Dash is designed as a **distributed system** with clear separation of concerns across multiple nodes: a frontend client, an API broker on a Raspberry Pi, a centralized database, and a dedicated GPU AI inference worker.

---

## System Architecture

The architecture mimics a production-grade microservice environment, ensuring that heavy AI workloads never block API routing or user interactions.

```mermaid
graph TD
    %% Frontend Layer
    subgraph Client Layer
        F[Flutter Mobile App]
    end

    %% API Broker Layer (Raspberry Pi)
    subgraph Edge Node (Raspberry Pi)
        API[FastAPI Gateway]
        SYNC[Incremental Sync Worker]
    end

    %% Inference Layer (GPU Machine)
    subgraph AI Processing Node (GPU Worker)
        OLLAMA[Ollama Inference Server]
        MODEL[Llama 3 Model]
        AI_WORK[AI Processing Background Job]
    end

    %% Storage Layer
    subgraph Cloud Storage
        DB[(Supabase PostgreSQL)]
    end

    %% External Services
    subgraph External APIs
        GMAIL[Gmail API / OAuth 2.0]
    end

    %% Connections
    F -->|Secure REST via ngrok| API
    API <-->|OAuth Tokens| DB
    SYNC -->|Fetch incremental emails| GMAIL
    SYNC -->|Store raw MIME| DB
    
    AI_WORK <-->|Query unprocessed emails| DB
    AI_WORK -->|Prompt + Context| OLLAMA
    OLLAMA --> MODEL
    OLLAMA -->|Return structured JSON| AI_WORK
    AI_WORK -->|Write insights| DB
    
    API <-->|Serve classified emails| DB
```

### Component Breakdown

1. **Frontend (Flutter)**
   - Minimalist, dynamic UI built with Flutter.
   - Passive consumer of state: it renders the dashboard and relies on the backend for heavy lifting.
   - Implements local widget caching to prevent redundant API calls during UI animations.

2. **API Broker & Edge Node (Raspberry Pi via ngrok)**
   - Built with **FastAPI**.
   - Acts as the central nervous system. Handles OAuth state validation, serves REST endpoints, and runs the `Incremental Sync Worker` via `asyncio` background tasks.
   - Periodically polls the Gmail API, parsing complex MIME trees (with BeautifulSoup fallbacks for HTML-only emails), and writes raw payloads to the database.

3. **Database (Supabase PostgreSQL)**
   - Central state store for OAuth tokens, User Profiles, Sync Statuses, and Email data.
   - Decouples the API Broker from the AI Worker.

4. **AI Inference Server (GPU Node)**
   - Runs a dedicated polling worker that queries Supabase for emails marked `ai_processed == False`.
   - Offloads heavy NLP and categorization tasks to a locally hosted **Ollama** server running specialized LLMs.
   - Extracts semantic insights (Topic, Urgency, Academic Score, Deadlines) and writes them back to Supabase. This ensures the Raspberry Pi API broker never hangs due to GPU compute blocking.

5. **CI/CD Pipeline (GitHub Actions)**
   - Automated deployment via a Self-Hosted GitHub Action runner hosted directly on the Raspberry Pi edge node.
   - Restarts the `uvicorn` systemd service automatically on main-branch pushes.

---

## Features

- **Distributed AI Pipeline**: Inference runs on a LAN-connected GPU rig, fully decoupled from the Edge API Gateway.
- **Robust MIME Parsing**: Recursively traverses `multipart/alternative` and `multipart/mixed` email payloads to extract pure text, with built-in `text/html` fallback parsing for automated/marketing emails.
- **Incremental Sync**: Only fetches new emails by tracking the `historyId` and `last_sync_date`, avoiding Gmail API rate limits.
- **Automated Taxonomies**: Emails are grouped by semantic topic (Exams, Assignments, Events) and urgency, allowing students to focus strictly on actionable items.
- **Graceful Degradation**: If the AI GPU server goes offline, the REST API and email sync continue functioning perfectly. Users see the raw email until the AI server comes back online and processes the backlog.

---

## Deployment

### Prerequisites
- Flutter SDK (Frontend)
- Python 3.10+ (Backend)
- PostgreSQL / Supabase account
- Ollama installed on a GPU-enabled machine
- Raspberry Pi (Optional, but recommended for API hosting)
- Google Cloud Console account (for OAuth credentials)

### Backend Setup
1. Clone the repository and navigate to `/backend`.
2. Create `venv`: `python -m venv venv && source venv/bin/activate`
3. Install dependencies: `pip install -r requirements.txt`
4. Copy `.env.example` to `.env` and fill in Supabase and Google OAuth keys.
5. Apply Alembic migrations: `alembic upgrade head`
6. Start the server: `uvicorn app.main:app --host 0.0.0.0 --port 8000`

### AI Worker Setup
Make sure the machine running Ollama is accessible from the API Broker (e.g., connected to the same Tailscale network or LAN).
Update the `OLLAMA_URL` in the backend `.env` file to point to this inference machine's IP (e.g., `http://192.168.1.100:11434`).

### Frontend Setup
1. Navigate to `/trial1`.
2. Run `flutter pub get`.
3. Update `api_services.dart` to point to the base URL of your FastAPI server (or ngrok tunnel).
4. Run the app: `flutter run`.

---

## OAuth & Security

- **Strict Environment Separation**: The frontend handles Google Sign-In and passes an authorization code to the backend. The backend strictly exchanges and stores the Refresh Tokens.
- **Symmetric Encryption**: OAuth Refresh tokens are encrypted symmetrically via `cryptography.fernet` before resting in the database.

---
*Built to simplify the student experience through resilient systems engineering.*