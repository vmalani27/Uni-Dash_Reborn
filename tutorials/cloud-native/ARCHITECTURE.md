# Cloud-Native Architecture Overview

## From Monolith to Microservices on AWS Lambda

### Current Architecture (FastAPI)

```
┌─────────────────────────────────────────────────────────────┐
│                      Single FastAPI Process                 │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              FastAPI Main Process                   │  │
│  │                                                      │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │  │
│  │  │ HTTP Routes │  │  Background  │  │ Scheduled  │ │  │
│  │  │ (sync,      │──│ Jobs         │──│ Tasks/     │ │  │
│  │  │ classify)   │  │ (async loops)│  │ Cron       │ │  │
│  │  └─────────────┘  └──────────────┘  └────────────┘ │  │
│  │                        ↓                            │  │
│  │                  Shared DB Session                  │  │
│  │                  (persistent connection)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                            ↓                               │
│      PostgreSQL (Supabase)  +  Gmail API  +  Firebase      │
└─────────────────────────────────────────────────────────────┘

Problem: Single point of failure, tight coupling, hard to scale
```

---

### Target Architecture (AWS Serverless)

```
Internet
   │
   ├─────────────────────────────────────────────────────────┐
   │                                                         │
   ↓                                                         │
╔═════════════════════════════════════════════════════════════╗
║              AWS API Gateway (REST API)                    ║
║  (Handles HTTP requests, routing, authorization)          ║
╚═════════════════════════╤═════════════════════════════════╝
                          │
         ┌────────────────┼────────────────┐
         ↓                ↓                ↓
    ┌─────────────┐ ┌──────────────┐ ┌────────────┐
    │ Lambda      │ │ Lambda       │ │ Lambda     │
    │ Handler 1   │ │ Handler 2    │ │ Handler 3  │
     │ (read APIs) │ │ (enqueue     │ │ (oauth)    │
     │             │ │ sync jobs)   │ │            │
    └─────────────┘ └──────────────┘ └────────────┘
         │                │                │
         └────────────────┼────────────────┘
                          │
                  ┌───────┴────────┐
                  │                │
                  ↓                ↓
       ╔═══════════════════╗  ╔═══════════════════╗
       ║  RDS PostgreSQL   ║  ║  AWS SQS         ║
       ║  (Managed DB)     ║  ║  (Job Queue)      ║
       ╚═══════════════════╝  ╚═════════╤═════════╝
       ↑                                │
       │                        ┌───────┴────────┐
       │                        │                │
       │                   ┌─────────────┐  ┌─────────────┐
       │                   │ Lambda      │  │ Lambda      │
       │                   │ Worker 1    │  │ Worker 2    │
       │                   │ (gmail)     │  │ (classify)  │
       │                   └─────────────┘  └─────────────┘
       │
       └───────────────────────┐
                               │
         ╔═════════════════════════════════╗
         ║   AWS EventBridge (Scheduler)   ║
         ║   - Every 3 min: trigger        ║
         ║     unified dispatcher          ║
         ╚═════════════════╤═══════════════╝
                          │
                     ┌────▼─────────────┐
                     │ Lambda Dispatcher │
                     │ (queries users,   │
                     │  enqueues jobs)   │
                     └────┬──────────────┘
                          │
                     ┌────▼─────┐
                     │ SQS Queue │
                     └────┬─────┘
                          │
           ┌──────────────┴──────────────┐
           │  Workers process jobs       │
           │  (multiple Lambda invokes)  │
           └──────────────┬──────────────┘
                          │
                          ↓
          Gmail API + ML Inference API

Benefits: Auto-scaling, pay-per-use, decoupled components, resilient
```

---

## AWS Services in Detail

### 1. **API Gateway**
- **Role:** Frontend HTTP interface
- **Input:** HTTP requests from client
- **Output:** Routes to Lambda handlers
- **Scaling:** Automatic, built-in throttling

```
Client Request  →  API Gateway  →  Lambda Handler
(POST /sync)        (REST API)      (Python function)
```

---

### 2. **AWS Lambda**
Three types of Lambda functions:

#### **Type 1: HTTP Handlers** (Triggered by API Gateway)
```
API Gateway invokes → Lambda function exits
Response returned to client immediately
(Synchronous)
```

Example: `/gmail/sync` endpoint
```python
def handler(event, context):
    # Extract request data
    user_id = event['pathParameters']['user_id']
     # Enqueue async sync job (fast API response)
     sqs.send_message(
          QueueUrl=SYNC_QUEUE_URL,
          MessageBody=json.dumps({'job_type': 'gmail_sync', 'user_id': user_id})
     )

     # Return immediately
    return {
          'statusCode': 202,
          'body': json.dumps({'status': 'accepted', 'message': 'sync job queued'})
    }
```

#### **Type 2: SQS Workers** (Triggered by message queue)
```
SQS Message  →  AWS polls queue  →  Lambda Worker
                                   Does async work
(Asynchronous, concurrent; polling managed by AWS)
```

Example: Email classification
```python
def handler(event, context):
    # event contains SQS messages
    for record in event['Records']:
        message = json.loads(record['body'])
        # Classify email, save to DB
        # Lambda auto-deletes message on success
```

#### **Type 3: Dispatchers** (Triggered by EventBridge)
```
EventBridge (scheduled)  →  Lambda Dispatcher  →  Queries DB
                                                  Enqueues SQS jobs
```

Example: Every 3 minutes, check for unsynced emails
```python
def handler(event, context):
    # Query unsynced emails from DB
    emails = db.query(Email).filter(synced=False)
    # Enqueue them as SQS jobs
    for email in emails:
        sqs.send_message(MessageBody=json.dumps({...}))
```

---

### 3. **RDS PostgreSQL**
- **Role:** Managed relational database
- **Scaling:** Vertical (instance size)
- **Access:** Via VPC security group + RDS Proxy (connection pooling)

```
Lambda Functions  →  RDS Proxy  →  RDS PostgreSQL
(short-lived)      (pools conns)   (persistent DB)
```

**Connection Strategy:**
- Create **new SQLAlchemy session per Lambda invocation**
- Use **RDS Proxy** to pool connections (prevents exhaustion)
- Set short timeouts on queries

---

### 4. **EventBridge**
- **Role:** Cron scheduler + event dispatcher
- **Triggering:** Lambda functions on schedule
- **Use Case:** Replace background loops

```
Schedule Rule  →  EventBridge  →  Lambda Dispatcher
(every 3 min)      (triggers)      (enqueues work)
```

---

### 5. **SQS (Simple Queue Service)**
- **Role:** Async job queue
- **Decoupling:** Separate job creation from processing
- **Scaling:** Workers scale with queue depth

```
Dispatcher sends  →  SQS Queue  →  Multiple Workers
messages (fast)                    process (parallel)
```

---

### 6. **Secrets Manager** (Not shown in diagram)
- **Role:** Credential storage
- **Access:** Lambda reads at runtime
- **Rotation:** Automatic credential rotation support

```
Lambda needs  →  Secrets Manager  →  Returns credential
credential        (encrypted)        (auditable)
```

---

## Data Flow Examples

### Example 1: User Syncs Gmail (HTTP Request)

```
Client Browser
     │
     │ POST /gmail/sync
     │
     ↓
┌─────────────────────────────────────────┐
│      API Gateway (REST endpoint)        │
│  Validates request, extracts path params│
└────────────────────┬────────────────────┘
     │
     │ Calls Lambda (synchronous)
     │ event = {'pathParameters': {...}}
     │
     ↓
┌─────────────────────────────────────────┐
│    Lambda: gmail_sync_enqueue_handler   │
│  1. Query user from RDS                 │
│  2. Create SQS job (gmail_sync)         │
│  3. Return 202 Accepted                 │
└────────────────────┬────────────────────┘
     │
     │ Fast response body with job status
     │
     ↓
┌─────────────────────────────────────────┐
│      API Gateway (returns 202)          │
└────────────────────┬────────────────────┘
     │
     │ JSON response to client
     │
     ↓
Client Browser receives result in <1 sec

After response (asynchronous path):

SQS Queue
    │
    │ AWS polls queue and invokes worker
    │
    ↓
┌─────────────────────────────────────────┐
│    Lambda: gmail_sync_worker            │
│  1. Load user OAuth token               │
│  2. Fetch new emails from Gmail API     │
│  3. Insert emails into RDS              │
│  4. Mark job status in DB               │
└─────────────────────────────────────────┘
```

---

### Example 2: Background Email Classification (Event-Driven)

```
Time: 12:00 PM
     │
     ↓
╔─────────────────────────────────────────╗
║ EventBridge Rule triggers               ║
║ (Scheduled: every 5 minutes)            ║
╚─────────────────┬───────────────────────╝
     │
     │ Invokes Dispatcher Lambda
     │
     ↓
┌─────────────────────────────────────────┐
│ Lambda: classify_dispatcher             │
│ 1. Query unclassified emails from RDS   │ 
│    SELECT * FROM emails WHERE           │
│    classified = false LIMIT 100         │
│ 2. For each email:                      │
│    - Create SQS message                 │
│    - Enqueue to SQS                     │
└────────────────────┬────────────────────┘
     │
     │ 100 messages enqueued
     │
     ↓
╔═════════════════════════════════════╗
║    SQS: Email Classification Queue  ║
║  Messages waiting to be processed   ║
╚═════════════════════╤═══════════════╝
   │
     │ SQS triggers Lambda Workers (concurrent)
     │ AWS manages queue polling and invocation
   │
   ├─────────────────────────────────────────┤
   │                                         │
   ↓                                         ↓
Lambda Worker #1                       Lambda Worker #2
(processes message 1-50)               (processes message 51-100)
1. Get message body                    1. Get message body
2. Classify with ML model              2. Classify with ML model
3. Save to RDS                         3. Save to RDS
4. Return success                      4. Return success
5. SQS auto-deletes message            5. SQS auto-deletes message

Result: All 100 emails classified in parallel in ~30 seconds!
Without Lambda: Would take 2+ minutes sequentially in FastAPI
```

---

### Example 3: Database Connection Lifecycle

```
┌─────────────────────────────────────────────────────┐
│    Lambda Invocation (max 15 min lifespan)         │
│                                                     │
│  1. Lambda container starts                        │
│     (cold start: 1-2 sec)                         │
│                                                     │
│  2. SQLAlchemy session created                     │
│     SessionLocal = sessionmaker(...)               │
│     session = SessionLocal()                       │
│                                                     │
│  3. Execute DB queries                             │
│     user = session.query(User).get(123)            │
│                                                     │
│     ├─ Session connects to RDS Proxy              │
│     │  (Proxy manages connection pooling)         │
│     │                                              │
│     ├─ Proxy connects to RDS (if needed)          │
│     │  (Reuses existing connections)              │
│     │                                              │
│     └─ Query executes, results returned           │
│                                                     │
│  4. Session closed, Lambda returns                │
│     session.close()                               │
│     Lambda exits, container frozen                │
│                                                     │
└─────────────────────────────────────────────────────┘

Key Points:
- Each Lambda invocation gets 1-2 DB queries max
- No persistent connection needed
- RDS Proxy prevents connection exhaustion
- Cold start adds latency but acceptable for most use cases
```

---

## Service Relationship Matrix

| Service | Triggered By | Triggers | Role |
|---------|--------------|----------|------|
| **API Gateway** | HTTP request | Lambda (handlers) | REST API frontend |
| **Lambda Handlers** | API Gateway | RDS or SQS | Process HTTP requests quickly |
| **EventBridge** | Time/Schedule | Lambda (dispatchers) | Cron scheduler |
| **Lambda Dispatchers** | EventBridge | SQS | Enqueue async jobs |
| **SQS** | Dispatcher | Lambda (workers) | Job queue |
| **Lambda Workers** | SQS | Gmail API, RDS, ML API | Process async jobs |
| **RDS** | Lambdas | Data returned | Database |
| **Secrets Manager** | Lambdas | Credentials | Secure storage |

---

## Cost Model Comparison

### Before (FastAPI on EC2)
- EC2 instance: $10-30/month (always running)
- RDS: $15-50/month
- Data transfer: $5-10/month
- **Total: $30-90/month** (fixed, always paying)

### After (Lambda + Serverless)
- Lambda: $0.20 per 1M requests (pay-per-use)
- RDS: $15-50/month (same as before)
- API Gateway: $3.50 per 1M requests
- Data transfer: $0.01 per GB
- **Total: $5-30/month** (scales with usage)

Example: 1M requests/month
- Lambda: $0.20
- API Gateway: $3.50
- RDS: $20
- **Total: ~$24/month** (vs $60/month for EC2)

---

## Migration Phases

### Phase 1: Deploy First Lambda (1-2 days)
```
Goal: Deploy a simple /health endpoint
├─ Set up AWS account, IAM roles
├─ Create Lambda function (Python)
├─ Create API Gateway REST API
├─ Deploy and test
└─ Result: API Gateway → Lambda → Response (hardcoded)
```

### Phase 2: Add Database (1-2 days)
```
Goal: Lambda connects to RDS, queries data
├─ Set up RDS PostgreSQL + VPC
├─ Set up RDS Proxy (connection pooling)
├─ Create Lambda function (with DB access)
├─ Test DB connection, simple queries
└─ Result: Can query real data, handle connections properly
```

### Phase 3: Migrate One Real Route (2-3 days)
```
Goal: /gmail/sync works on Lambda
├─ Build enqueue-only API handler (returns 202)
├─ Build gmail_sync_worker (SQS-triggered)
├─ Connect API handler to SQS queue
├─ Test with real Gmail API via worker
├─ Load test (100+ concurrent requests)
├─ Monitor for issues
└─ Result: Production-ready async pipeline
```

### Phase 4: Background Jobs (2-3 days)
```
Goal: Classification pipeline runs on Lambda
├─ Set up EventBridge scheduler
├─ Create unified dispatcher Lambda
├─ Set up SQS queue
├─ Create worker Lambda
├─ Load test (high job volume)
└─ Result: Async pipeline auto-scales
```

### Phase 5: Full Migration (1+ week)
```
Goal: All routes and jobs on Lambda
├─ Migrate remaining handlers
├─ Optimize performance
├─ Add monitoring/alerts
├─ Cost optimization
└─ Result: Fully serverless, production-ready
```

---

## Next Steps

- 👉 Read [Part 1: Fundamentals](part-1-fundamentals) to understand each service
- 👉 Review [Part 3: Database](part-3-database) for connection patterns
- 👉 Follow [Part 4: Implementation](part-4-implementation) for hands-on steps

**You are here:** 📍 Architecture overview complete  
**Next:** Understanding Lambda fundamentals
