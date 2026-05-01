# Uni-Dash AWS Migration Plan

This document describes how to move Uni-Dash from the current working Raspberry Pi deployment to an AWS-based production setup without rewriting the product into microservices.

The existing Raspberry Pi CI/CD pipeline, multi-stage Docker build, nginx, and ngrok setup are considered the current baseline and are working satisfactorily.

## 1. Current State

Uni-Dash is already a modular distributed system:

- Flutter web frontend
- FastAPI backend
- PostgreSQL database
- AI processing pipeline
- Raspberry Pi deployment target for the backend

Current production characteristics:

- Backend is deployed as a Docker container on a Raspberry Pi
- GitHub Actions handles CI/CD
- Multi-stage Docker build produces a small runtime image
- nginx and ngrok provide external access
- Supabase/PostgreSQL stores application state
- AI processing runs as part of the backend system and background workers

This means the current problem is not architecture chaos. The problem is that the deployment target is local/edge, while the career goal is AWS DevOps.

## 2. What AWS Migration Should Mean

The goal is to migrate the deployment and operations layer to AWS, not to redesign the product into dozens of services.

The correct AWS target is a **modular container-based system**:

- one backend container for the FastAPI API
- one worker container for background sync and AI jobs if needed
- managed PostgreSQL
- managed secrets
- managed logs and alarms

This keeps the codebase understandable and gives you a realistic AWS DevOps portfolio.

## 3. Recommended AWS Target Architecture

### Primary path

- **Frontend hosting:** S3 + CloudFront, or keep Flutter web hosting separate if needed
- **API backend:** ECS Fargate service behind an Application Load Balancer
- **Database:** RDS PostgreSQL
- **Secrets:** AWS Secrets Manager
- **Logs and metrics:** CloudWatch Logs and CloudWatch Alarms
- **Container registry:** ECR
- **Background jobs:** ECS worker service or scheduled tasks
- **Scheduled sync:** EventBridge scheduled task

### Optional later additions

- **SQS** for decoupling background job bursts
- **Lambda** only for very small utility tasks or webhooks if useful
- **RDS Proxy** if connection pressure becomes a real issue
- **S3** for CSV logs, artifacts, or exports

## 4. Why ECS First Instead Of Serverless First

Serverless is not wrong, but it is not the best first migration for this project.

Reasons:

- the backend already behaves like a long-running service
- background processing and SSE-style updates fit containerized services better than Lambda
- the current code has DB sessions, workers, and pipeline state that benefit from an always-on process
- ECS/Fargate teaches real AWS DevOps skills without forcing an unnecessary rewrite

Use Lambda only where it is a clear fit, not as the default answer.

## 5. Migration Phases

### Phase 1 - Lift and shift the backend container

Goal: run the existing FastAPI container on AWS with minimal code change.

Tasks:

- build and push the backend image to ECR
- deploy the API container to ECS Fargate
- attach an ALB
- configure health checks
- validate that auth, dashboard, Gmail sync, and AI pipeline endpoints still work

Success criteria:

- API works on AWS
- no feature regression compared to the Pi deployment
- logs are visible in CloudWatch

### Phase 2 - Move the database to AWS

Goal: switch the backend from the current database host to RDS PostgreSQL or equivalent managed AWS Postgres.

Tasks:

- provision RDS PostgreSQL
- migrate schema and data
- update environment variables and secrets
- confirm the backend still reads and writes correctly

Success criteria:

- backend starts cleanly against AWS Postgres
- no connection storms or session leaks
- migrations are repeatable

### Phase 3 - Move worker behavior into AWS-native runtime

Goal: run background sync and AI processing in a managed AWS runtime.

Options:

- keep workers inside the same ECS service if the load is small
- split workers into a second ECS service if needed
- use EventBridge for scheduled syncs

Success criteria:

- sync jobs run automatically
- AI processing runs without manual intervention
- dashboard data continues updating correctly

### Phase 4 - Add observability and safe operations

Goal: make the system production-grade from an ops perspective.

Tasks:

- structured logging
- CloudWatch alarms for backend health and worker failures
- deployment rollback strategy
- secret rotation policy
- dashboard for operational health

Success criteria:

- failures are visible quickly
- deploys are reversible
- you can reason about the system during incidents

### Phase 5 - Optional queue-based decoupling

Only do this if the workload justifies it.

Tasks:

- introduce SQS for AI jobs or sync tasks
- keep the API responsive while workers process backlog
- add retry handling and dead-letter queues

Success criteria:

- burst handling improves
- the API is less sensitive to worker spikes

## 6. Suggested AWS Service Mapping

| Current Role | AWS Equivalent |
| --- | --- |
| FastAPI backend container | ECS Fargate service |
| Reverse proxy / ingress | ALB |
| Container image build | GitHub Actions or CodeBuild |
| Container registry | ECR |
| PostgreSQL | RDS PostgreSQL |
| Secrets / credentials | Secrets Manager |
| Logs | CloudWatch Logs |
| Metrics / alerts | CloudWatch Alarms |
| Scheduled sync | EventBridge |
| Background tasks | ECS worker service |
| Optional queueing | SQS |
| Optional object storage | S3 |

## 7. What Should Stay In The Codebase

Keep the code modular, but do not over-fragment it.

Keep:

- `app/routers/`
- `app/services/`
- `app/models/`
- `app/core/database.py`
- worker/scheduler code if it still runs in the backend container

Do not rush to split into separate repositories or microservices unless there is a concrete scaling reason.

## 8. What Should Be Cleaned Up Before Migration

Before migrating to AWS, reduce confusion in the current codebase:

- keep one canonical academic pipeline
- keep one dashboard source of truth
- remove or deprecate legacy score-heavy paths
- keep compatibility shims only where the Flutter app still needs them
- make sure documentation matches the real runtime

## 9. What To Learn From This For AWS DevOps

This project is good AWS DevOps practice because it exercises:

- Docker image design
- CI/CD
- environment and secret management
- managed database migration
- load balancer and health check setup
- logs and alarms
- worker scheduling
- rollback discipline

That is a better portfolio story than "I decomposed one app into ten Lambda functions."

## 10. Concrete Next Steps

1. Keep the Raspberry Pi deployment as the live baseline until AWS parity exists.
2. Mirror the backend container to ECR.
3. Deploy the backend container to ECS Fargate.
4. Move the database to RDS PostgreSQL.
5. Add CloudWatch logs and alarms.
6. Migrate the worker/sync flow next.
7. Only then consider queue decoupling or Lambda for small jobs.

## 11. Final Recommendation

For this project, AWS migration should be:

- **container-first**
- **ops-first**
- **incremental**
- **monolith-friendly**

That is the fastest path to becoming credible as an AWS DevOps engineer while keeping Uni-Dash stable.
