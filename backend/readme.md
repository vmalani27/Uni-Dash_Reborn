Flutter App
    ↓
REST API Request
    ↓
FastAPI (receives request)
    ↓
Pydantic Models (validate input)
    ↓
SQLAlchemy (turn into DB operations)
    ↓
PostgreSQL (store and retrieve data)


uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload //for local lan