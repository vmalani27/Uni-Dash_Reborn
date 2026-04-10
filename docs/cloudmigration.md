# AWS Serverless Migration Plan for Uni-Dash Backend

---

## 1. System Understanding

### Current Backend Architecture
- **API Layer:** FastAPI routes for Gmail sync, classification, OAuth, notifications.
- **Background Jobs:** Asyncio loops for email ingestion and AI processing (run inside FastAPI lifespan).
- **Data Layer:** SQLAlchemy models, PostgreSQL (Supabase).
- **External Integrations:**
  - Gmail API (OAuth, message sync)
  - Firebase (auth)
  - ML/AI (local or remote inference)

### Core Components
- **API Layer:** FastAPI routers in `app/routers/`
- **Background Jobs:** `background_scheduler.py`, jobs in routers, `jobs/`
- **Data Layer:** SQLAlchemy models in `app/models/`, DB session logic in `app/core/database.py`
- **External Integrations:** Gmail API, Firebase, ML/AI services

---

## 2. Decomposition Strategy

### Lambda Functions
- **API Handlers:** Each route (sync, classify, OAuth, notifications) → individual Lambda handler
- **Dispatcher Lambdas:**
  - Scheduled by EventBridge (e.g., every 3 min)
  - Query users/emails, enqueue SQS jobs
- **Worker Lambdas:**
  - Triggered by SQS
  - Perform Gmail sync, classification, etc.

### Shared Modules
- **DB Connection/Models:** Connection logic, SQLAlchemy models
- **Auth:** Firebase token verification, OAuth helpers
- **Gmail Integration:** Gmail API logic
- **ML Logic:** Classification, inference

### Event-Driven Components
- **EventBridge:** Triggers dispatcher Lambdas
- **SQS:** Queues async jobs for workers

---

## 3. AWS Service Mapping

API Routes              ---> API Gateway + Lambda
Background Loops         ---> EventBridge + Lambda
Async Jobs              ---> SQS + Lambda
Database                ---> RDS PostgreSQL
Secrets                 ---> Secrets Manager
Auth                    ---> Lambda (Firebase token validation)

**Rationale:**
- API Gateway/Lambda: Stateless, easy scaling, pay-per-use
- EventBridge: Native scheduling, triggers dispatcher Lambdas
- SQS: Decouples job dispatch from processing, handles retries
- RDS: Managed Postgres, connection pooling support
- Secrets Manager: Centralized, secure secret management

---

## 4. Migration Phases

### Phase 1: Minimal Working System
- Deploy a single API route (e.g., `/gmail/sync`) as Lambda via API Gateway
- Connect to RDS PostgreSQL
- Test end-to-end (auth, DB, Gmail sync)

### Phase 2: Event-Driven Background Jobs
- Move ingestion and AI processing loops to EventBridge + dispatcher Lambda
- Dispatcher Lambda enqueues SQS jobs
- Worker Lambda processes SQS jobs
- Remove background loops from FastAPI

### Phase 3: Expand API Endpoints
- Migrate remaining API routes to Lambda handlers
- Refactor shared logic (DB, auth, Gmail, ML) for Lambda reuse
- Add monitoring/logging (CloudWatch)

### Phase 4: Optimize Scaling & Cost
- Implement DB connection pooling (e.g., RDS Proxy)
- Tune Lambda memory/timeouts
- Batch SQS jobs for efficiency
- Review cold start impact, optimize package size

**Each phase is deployable and testable.**

---

## 5. Folder Structure Refactor

```
backend-lambda/
│
├── handlers/           # API Gateway Lambda handlers
│   ├── gmail_sync.py
│   ├── classify.py
│   ├── oauth.py
│   └── notifications.py
│
├── workers/            # SQS-triggered worker Lambdas
│   ├── gmail_worker.py
│   └── classify_worker.py
│
├── dispatchers/        # EventBridge-triggered dispatcher Lambdas
│   ├── ingestion_dispatcher.py
│   └── ai_dispatcher.py
│
├── shared/             # Common code
│   ├── db.py
│   ├── auth.py
│   ├── gmail.py
│   ├── ml.py
│   └── models.py
│
├── config/             # Config, secrets loading
│   └── settings.py
│
└── requirements.txt
```

**Mapping:**
- `app/routers/` → `handlers/`
- `app/services/` → `shared/`
- `app/models/` → `shared/models.py`
- `app/core/database.py` → `shared/db.py`
- `background_scheduler.py`, `jobs/` → `dispatchers/`, `workers/`

---

## 6. Data & Auth Handling

- **OAuth Tokens:**
  - Store in RDS (encrypted if possible)
  - Use Secrets Manager for client secrets
- **DB Sessions in Lambda:**
  - Use short-lived SQLAlchemy sessions per invocation
  - Use RDS Proxy for connection pooling
- **Connection Pooling:**
  - RDS Proxy recommended to avoid Lambda connection storm
- **Code Changes:**
  - Refactor DB/session logic for stateless, per-invocation use
  - Remove global/session-scoped DB connections
  - Ensure all secrets/config are loaded from environment/Secrets Manager

---

## 7. Risks & Pitfalls

- **What will break:**
  - Long-lived connections (DB, Gmail) must be refactored
  - Streaming endpoints (SSE) not natively supported in Lambda
  - Background loops must be event-driven
- **Lambda Limitations:**
  - Max 15 min execution time
  - DB connection limits (use RDS Proxy)
  - Package size/cold start
- **Gmail API Rate Limits:**
  - Must batch jobs, handle 429s, exponential backoff
- **Cold Start Issues:**
  - Minimize dependencies, use provisioned concurrency if needed

---

## 8. Final Output: Roadmap & Priorities

### Roadmap
1. Extract shared modules (DB, auth, Gmail, ML)
2. Deploy minimal Lambda handler (e.g., `/gmail/sync`)
3. Set up RDS, Secrets Manager, test DB connection
4. Implement dispatcher/worker Lambdas for background jobs
5. Migrate remaining API routes
6. Optimize (RDS Proxy, batching, monitoring)

### Prioritized Implementation Order
- **THIS WEEKEND:**
  1. Extract shared modules
  2. Deploy/test one Lambda handler (API Gateway → Lambda → RDS)
  3. Set up RDS and Secrets Manager
- **NEXT:**
  4. Move background jobs to dispatcher/worker Lambdas
  5. Expand API coverage
  6. Optimize and monitor

---

**Focus on one pipeline end-to-end first.**

---

*This plan is practical, incremental, and minimizes risk. No full rewrite required.*
