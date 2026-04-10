# Uni-Dash Cloud-Native Migration Tutorial

## 🎯 What You'll Learn

This comprehensive tutorial walks you through **migrating a FastAPI backend to AWS serverless** architecture. You'll learn how to:

- ✅ Deploy Python code on AWS Lambda
- ✅ Create REST APIs with API Gateway
- ✅ Schedule background jobs with EventBridge
- ✅ Handle PostgreSQL databases in Lambda (with connection pooling)
- ✅ Move from monolithic background loops to event-driven processing
- ✅ Monitor, optimize, and cost-manage serverless apps

**Target:** Convert Uni-Dash backend from FastAPI + background loops → Lambda + API Gateway + EventBridge + RDS

---

## 📚 Tutorial Structure

This tutorial is organized into **6 progressive parts**, each building on the previous:

### **Part 1: Fundamentals** (2-3 hours)
Start here if you're new to serverless/AWS.
- Lambda execution model, handlers, context
- API Gateway REST API basics
- EventBridge & scheduling
- RDS PostgreSQL overview

👉 **Start:** [`part-1-fundamentals/`](part-1-fundamentals)

---

### **Part 2: Architecture Design** (2 hours)
Understand how to decompose your FastAPI app.
- Current architecture vs. serverless
- Mapping FastAPI routes → Lambda handlers
- Event flow & service decomposition
- Keeping code DRY with shared modules

👉 **Start:** [`part-2-architecture/`](part-2-architecture)

---

### **Part 3: Database Handling** ⚡ **CRITICAL**
Master PostgreSQL + Lambda interaction.
- Choosing RDS, setting up security groups
- Connection pooling with RDS Proxy
- Lambda connection management, timeouts, retries
- Migrating existing data
- Cost & performance tradeoffs

👉 **Start:** [`part-3-database/`](part-3-database)

---

### **Part 4: Step-by-Step Implementation** (5-8 hours, hands-on)
Actually deploy to AWS.
- **Phase 1:** Setup AWS account, deploy first Lambda
- **Phase 2:** Migrate a real route (Gmail sync)
- **Phase 3:** Implement background job pipeline
- **Phase 4:** Migrate remaining routes

👉 **Start:** [`part-4-implementation/`](part-4-implementation)

---

### **Part 5: Optimization & Best Practices** (2 hours)
Make it production-ready.
- Lambda memory sizing, cold starts
- Security (Secrets Manager, IAM)
- Monitoring & debugging (CloudWatch)
- Cost optimization

👉 **Start:** [`part-5-optimization/`](part-5-optimization)

---

### **Part 6: Reference & Templates**
Quick lookup for code samples, architecture diagrams, troubleshooting.

👉 **Start:** [`part-6-reference/`](part-6-reference)

---

## 🚀 Quick Start (30 min)

If you just want a **super quick overview** before diving in:

1. Read [`ARCHITECTURE.md`](ARCHITECTURE.md) for high-level diagrams
2. Skim [`part-1-fundamentals/01-lambda-basics.md`](part-1-fundamentals/01-lambda-basics.md) 
3. Look at [`code-templates/lambda-handler-template.py`](code-templates/lambda-handler-template.py)
4. Then jump to [`part-4-implementation/`](part-4-implementation) to start building

---

## 📋 Prerequisites

Before you start, ensure you have:

- ✅ **AWS Account** (free tier works for learning)
- ✅ **AWS CLI** installed and configured ([guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- ✅ **Python 3.9+** locally
- ✅ **PostgreSQL client** tools (psql)
- ✅ Basic AWS knowledge (IAM roles, VPC concepts)
- ✅ Existing FastAPI backend (the Uni-Dash app)

**Time commitment:** 10-15 hours for full migration (varies by complexity)

---

## 🎓 Learning Path

**Beginner (New to serverless):**
```
Part 1 → Part 2 → Part 3 → Part 4 (Phase 1) → Part 5
```

**Experienced (Know AWS, want practical steps):**
```
ARCHITECTURE.md → Part 3 → Part 4 → Part 5
```

**Advanced (Just need reference):**
```
Part 6 (Reference & templates)
```

---

## 💡 Key Concepts You'll Master

| Concept | What | Why |
|---------|------|-----|
| **Lambda Handler** | Entry point function | Every Lambda needs one |
| **API Gateway Integration** | REST API → Lambda | Expose Lambda as HTTP endpoint |
| **EventBridge Rules** | Trigger Lambda on schedule/event | Replace background loops |
| **RDS Proxy** | Connection pool | Prevent DB connection exhaustion |
| **SQS + Lambda** | Async job processing | Decouple heavy work from API |
| **Secrets Manager** | Secure credential storage | Keep API keys safe |
| **CloudWatch** | Logs & monitoring | Debug Lambda in production |

---

## 📁 Code Templates & Examples

All code examples are in [`code-templates/`](code-templates):
- `lambda-handler-template.py` - Basic Lambda structure
- `db-connection-template.py` - RDS + SQLAlchemy setup
- `rds-proxy-config.json` - RDS Proxy configuration
- `cloudformation-templates/` - Infrastructure-as-Code templates

**Copy, tweak, deploy!**

---

## 🧪 Hands-On Exercises

Each part includes **exercises** to practice:
- Deploy a simple Lambda
- Connect Lambda to RDS
- Migrate a real route
- Setup event-driven pipeline

Check [`exercises/`](exercises) for step-by-step labs.

---

## ⚠️ Common Pitfalls (Spoiler Alert!)

You'll learn how to avoid:
- ❌ Connection pooling mistakes → DB connection exhaustion
- ❌ Hardcoded credentials → Security breach
- ❌ Long-running Lambdas → Timeout failures
- ❌ Missing IAM permissions → Access denied errors
- ❌ Streaming responses → Not supported in Lambda
- ❌ Cold start delays → Slow API responses

---

## 📊 What You'll Build

By the end, you'll have:
- ✅ Multiple Lambda functions (handlers, workers, dispatchers)
- ✅ REST API exposed via API Gateway
- ✅ Background jobs triggered by EventBridge/SQS
- ✅ PostgreSQL data safely managed in RDS
- ✅ Monitoring & alerts in CloudWatch
- ✅ Secure credential management
- ✅ Scalable, pay-per-use architecture

**Cost:** ~$10-20/month for learning (free tier covers most)

---

## 📖 Document Index

| Document | Purpose | Time |
|----------|---------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design visuals | 15 min |
| Part 1 | Concepts & theory | 2-3 hours |
| Part 2 | Design your migration | 2 hours |
| Part 3 | Database deep-dive | 2-3 hours |
| Part 4 | Actual implementation | 5-8 hours |
| Part 5 | Optimization | 2 hours |
| Part 6 | Reference lookup | As needed |

---

## ✍️ Notes

- Each exercise builds on the previous ✅
- All code examples tested and working
- Database section is **critical** - don't skip!
- You'll hit AWS limits/errors - that's normal 💪
- Read the troubleshooting section in Part 6

---

## 🤝 Next Steps

1. **Pick your starting point** based on experience level above
2. **Read sequentially** - each part assumes prior knowledge
3. **Do the exercises** - don't just read!
4. **Deploy to AWS** in Phase 1 to see it work live
5. **Ask questions** - serverless has unique challenges

---

## 🎯 Final Goal

By completing this tutorial, you'll understand:
- ✅ How serverless works and when to use it
- ✅ How to migrate a real FastAPI app to Lambda
- ✅ Database best practices for Lambda
- ✅ Event-driven architecture patterns
- ✅ Production-ready monitoring & security

Ready? Let's start! 👉 [Part 1: Fundamentals →](part-1-fundamentals)

---

**Last Updated:** April 2026  
**Status:** Active (Uni-Dash migration in progress)
