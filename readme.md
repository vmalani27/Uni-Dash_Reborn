# Uni-Dash: AI-Powered Academic Email Platform

> **Status: Production Profile Management + AWS Serverless Architecture**  
> Core authentication, profile management endpoints (POST/GET/PUT), and CORS handling are production-ready on AWS (Cognito, API Gateway, Lambda, Supabase). Email ingestion and AI classification pipelines operational on local backend. OAuth integration (Google Gmail) in development.

---

## Current Implementation Status

### Completed: Authentication & Profile Management

| Component | Status | Technology | Endpoint |
|-----------|--------|-----------|----------|
| User Authentication | Production | AWS Cognito + API Gateway JWT Authorizer | `POST /auth/*` |
| Profile Creation | Production | Lambda + Supabase REST | `POST /user/profile` |
| Profile Retrieval | Production | Lambda + Supabase REST | `GET /user/profile` |
| Profile Update | Production | Lambda + Supabase REST | `PUT /user/profile` |
| CORS Handling | Production | API Gateway + Lambda headers | All endpoints |
| Field Validation | Production | Lambda business logic | POST/PUT |
| Immutable Field Enforcement | Production | Lambda validation | `sid`, `uid`, `email` |

### Working Data Flow

```
Next.js Frontend
       |
       v
AWS Cognito (SignIn/SignUp) --> ID Token (JWT)
       |
       v
API Gateway (HTTP API)
       |
       +-- JWT Authorizer validates token
       |
       v
Lambda Function (Python 3.11)
       |
       +-- Extracts claims from JWT (uid, email)
       +-- Normalizes camelCase to snake_case
       +-- Validates required fields
       +-- Enforces immutable field rules
       |
       v
Supabase PostgreSQL (via REST API)
       |
       +-- Query: SELECT/INSERT/UPDATE users WHERE uid = :uid
       +-- Returns JSON representation
       |
       v
Lambda --> API Gateway --> Next.js Frontend
```

### Lambda Configuration Details

| Setting | Value | Notes |
|---------|-------|-------|
| Runtime | Python 3.11 | Compatible with requests, cryptography |
| Memory | 128 MB | Sufficient for REST proxy operations |
| Timeout | 30 seconds | Handles Supabase network latency |
| Layers | `requests`, `cryptography` | Pre-bundled to reduce cold start |
| Environment Variables | `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `ALLOWED_ORIGINS` | Injected at deployment |
| Cold Start | ~1-2 seconds (unprovisioned) | Acceptable for user-facing profile ops |
| Deployment | AWS SAM / Terraform | Infrastructure as code |

### API Contract: Profile Endpoints

#### POST /user/profile (Create)
```json
Request:
{
  "fullName": "Vansh Malani",
  "degree": "BTech",
  "branch": "CSE",
  "admissionYear": 2024,
  "sid": "23dcs056"
}

Response (201 Created):
{
  "uid": "01934d4a-9081-708a-32c6-da7e24a172fd",
  "email": "vanshmalani9@gmail.com",
  "full_name": "Vansh Malani",
  "degree": "BTech",
  "branch": "CSE",
  "admission_year": 2024,
  "sid": "23dcs056",
  "profile_completed": true,
  "oauth_connected": false
}

Error Responses:
400: {"error": "Missing field: <field_name>"}
409: {"error": "User already exists"}
409: {"error": "SID already registered"}
```

#### GET /user/profile (Retrieve)
```json
Response (200 OK):
{
  "uid": "...",
  "email": "...",
  "full_name": "...",
  "degree": "...",
  "branch": "...",
  "admission_year": 2024,
  "sid": "23dcs056",
  "profile_completed": true,
  "oauth_connected": false
}

Error Responses:
404: {"error": "User not found"}
```

#### PUT /user/profile (Update)
**Note:** Only `branch` and `admission_year` are mutable. Fields like `sid`, `uid`, `email`, `full_name`, and `degree` are immutable after profile creation.

```json
Request (partial update allowed):
{
  "branch": "AI/ML"
}

Response (200 OK):
{
  "uid": "...",
  "email": "...",
  "full_name": "...",
  "degree": "...",
  "branch": "AI/ML",
  "admission_year": 2024,
  "sid": "23dcs056",
  "profile_completed": true,
  "oauth_connected": false
}

Error Responses:
400: {"error": "Field 'sid' cannot be updated"}
400: {"error": "Invalid admission_year"}
404: {"error": "User not found"}
```

---

## Next: OAuth Integration (In Development)

### Objective
Enable users to connect their Google accounts for read-only access to Gmail and Google Classroom APIs, automating academic email ingestion.

### Planned Endpoints
| Endpoint | Purpose | Status |
|----------|---------|--------|
| `GET /auth/google/url` | Generate OAuth authorization URL | Not implemented |
| `GET /auth/google/callback` | Exchange authorization code for tokens | Not implemented |
| `POST /auth/google/disconnect` | Revoke and delete stored refresh token | Not implemented |

### Security Approach
- Google OAuth credentials stored in AWS Secrets Manager
- Refresh tokens encrypted with Fernet before Supabase storage
- CSRF protection via state parameter validation
- Scopes limited to `gmail.readonly` and classroom read access
- User-initiated disconnect triggers token revocation

## Architecture

### Current State
| Component | Technology | Status |
|-----------|-----------|--------|
| Frontend | Next.js 14 (App Router) | ✓ Production |
| Authentication | AWS Cognito | ✓ Production |
| API Gateway | AWS API Gateway (HTTP) | ✓ Production |
| Profile API | Lambda (Python 3.11) | ✓ Production |
| Database | Supabase PostgreSQL | ✓ Production |
| Email Sync | FastAPI + asyncio | ✓ Functional |
| AI Inference | Ollama + Llama 3 | ✓ Functional |
| OAuth (Gmail) | Lambda integration | ⚠️ In Development |

### Future: Cloud-Native
- Email Sync: Celery + Redis on Kubernetes HPA
- AI Inference: FastAPI + GPU Scheduling on Kubernetes StatefulSet
- API Gateway: FastAPI with Istio sidecar
- Object Storage: S3-compatible bucket
- Observability: CloudWatch + X-Ray

## Getting Started

### Prerequisites
- Node.js 18+ (Next.js frontend)
- AWS CLI configured with appropriate permissions
- Supabase project with users table configured
- Python 3.11+ (optional, for Lambda local testing)

### Frontend
```bash
cd web
npm install
cp .env.example .env.local
# Set NEXT_PUBLIC_API_BASE_URL to your API Gateway endpoint
npm run dev
```

### Lambda Deployment
```bash
# Using AWS SAM (from infra/lambda/profile-api directory)
sam build
sam deploy --guided

# Requires environment variables:
# - SUPABASE_URL
# - SUPABASE_SERVICE_KEY
# - ALLOWED_ORIGINS
```

### Testing the API
```bash
# After obtaining ID token from Cognito login
export TOKEN="eyJ..."

# Create profile
curl -X POST https://YOUR_API/user/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fullName":"Test User","degree":"BTech","branch":"CSE","admissionYear":2024,"sid":"test123"}'

# Retrieve profile
curl -X GET https://YOUR_API/user/profile \
  -H "Authorization: Bearer $TOKEN"

# Update profile
curl -X PUT https://YOUR_API/user/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"branch":"AI/ML"}'
```

---

## Resources & Contributing

**Documentation & Reference**
- [OpenAPI Specification](./api/openapi.yaml)
- [Lambda Build Instructions](./infra/lambda/README.md)
- [Supabase Schema](./docs/database.md)
- [Cognito Setup Guide](./docs/auth.md)

**Development Guidelines**
- Trunk-based development with backward-compatible API changes
- Updated OpenAPI specs for all endpoint modifications
- Integration tests covering POST/GET/PUT flows
- Manual verification against Supabase test project

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed contribution guidelines.

---

## Summary

Uni-Dash is evolving from a functional monolith to a resilient, cloud-native system. The profile management layer demonstrates the target architecture pattern: stateless compute, managed identity, and decoupled data access. OAuth integration is the next step toward enabling the core academic email ingestion pipeline.
