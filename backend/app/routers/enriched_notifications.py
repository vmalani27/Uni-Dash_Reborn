"""
Example endpoint showing how to use enriched AcademicContextEngine.
Add this to your FastAPI app (e.g., backend/app/routers/notifications.py).
"""

from fastapi import APIRouter, Query, HTTPException
from datetime import datetime, timezone
from typing import Optional, List
from app.services.academic_context_engine import AcademicContextEngine
import httpx

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("/enriched/{gmail_id}")
async def get_enriched_notification(
    gmail_id: str,
    use_llm: bool = Query(False, description="Enable small LLM enrichment for high-priority emails"),
):
    """
    Fetch a single notification with structured insights.
    
    Returns notification + instructor/course/action_items extracted.
    
    - use_llm=True: Use Ollama for semantic analysis (requires Ollama running)
    - use_llm=False: Fast pattern-based extraction
    
    Example:
    GET /api/notifications/enriched/<gmail_id>?use_llm=true
    """
    
    # TODO: Fetch from your DB or Gmail API
    notification = {
        'id': 1,
        'gmail_id': gmail_id,
        'subject': 'CS101 Assignment 3 - Due Friday 5PM',
        'body_text': '''
        Dear Student,
        
        Please submit your Assignment 3 by Friday 5PM. 
        The assignment should be submitted as a single PDF file to the course portal.
        
        Requirements:
        - Complete all 5 problems
        - Show all work
        - Include references
        
        Questions? Email me at prof@university.edu
        
        Dr. Smith
        Department of Computer Science
        ''',
        'snippet': 'Please submit your Assignment 3 by Friday 5PM...',
        'normalized_topic': 'ASSIGNMENT',
        'academic_score': 85.5,
    }
    
    # Optionally initialize LLM client
    llm_client = None
    if use_llm:
        try:
            from ollama import Client
            llm_client = Client(host='http://localhost:11434')
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="LLM enrichment requested but Ollama not available. Install: pip install ollama"
            )
    
    # Enrich with insights
    enriched = AcademicContextEngine.enrich_notification_with_insights(
        notification,
        use_llm=use_llm,
        llm_client=llm_client,
    )
    
    return enriched


@router.get("/dashboard/high-priority")
async def get_high_priority_dashboard(
    limit: int = Query(20, ge=1, le=100),
    enrich_with_llm: bool = Query(False, description="Deep enrichment for top N items"),
    enrich_count: int = Query(5, ge=1, le=20, description="How many top items to enrich with LLM"),
):
    """
    Unified dashboard endpoint: combines scoring + optional LLM enrichment.
    
    Strategy:
    1. Fetch all notifications (score-sorted by AcademicContextEngine)
    2. Return top `limit` items
    3. If enrich_with_llm=True, enrich top `enrich_count` with small LLM
    
    This balances speed (most items use fast patterns) with insight (top items get LLM attention).
    
    Example:
    GET /api/notifications/dashboard/high-priority?limit=50&enrich_with_llm=true&enrich_count=5
    
    Response:
    {
        "notifications": [
            {
                "id": 1,
                "gmail_id": "...",
                "subject": "CS101 Assignment 3 - Due Friday",
                "academic_score": 92.5,
                "normalized_topic": "ASSIGNMENT",
                "structured_insights": {
                    "instructor_name": "Dr. Smith",
                    "course_code": "CS101",
                    "action_items": ["Submit assignment as PDF"],
                    "submission_required": true,
                    "confidence": 0.85,
                    "enriched_by_llm": true
                }
            },
            ...
        ],
        "summary": {
            "total_count": 23,
            "high_priority_count": 8,
            "llm_enriched_count": 5
        }
    }
    """
    
    # TODO: Fetch from DB, sorted by academic_score DESC
    notifications = [
        {
            'id': 1,
            'gmail_id': 'msg_123',
            'subject': 'CS101 Assignment 3 - Due Friday 5PM',
            'snippet': 'Please submit your Assignment 3...',
            'body_text': 'Full body here...',
            'normalized_topic': 'ASSIGNMENT',
            'academic_score': 92.5,
            'sender': 'prof@university.edu',
        },
        {
            'id': 2,
            'gmail_id': 'msg_124',
            'subject': 'Mid-term Exam - March 22',
            'snippet': 'The mid-term exam is scheduled...',
            'body_text': 'Full body here...',
            'normalized_topic': 'EXAM',
            'academic_score': 88.0,
            'sender': 'registrar@university.edu',
        },
    ]
    
    # Initialize LLM client if needed
    llm_client = None
    if enrich_with_llm:
        try:
            from ollama import Client
            llm_client = Client(host='http://localhost:11434')
        except ImportError:
            # Gracefully degrade: skip LLM enrichment
            enrich_with_llm = False
    
    # Enrich top items with LLM
    enriched_notifications = []
    for idx, notif in enumerate(notifications[:limit]):
        should_use_llm = enrich_with_llm and idx < enrich_count
        
        enriched = AcademicContextEngine.enrich_notification_with_insights(
            notif,
            use_llm=should_use_llm,
            llm_client=llm_client,
        )
        enriched_notifications.append(enriched)
    
    return {
        'notifications': enriched_notifications,
        'summary': {
            'total_count': len(notifications),
            'high_priority_count': sum(1 for n in notifications if n.get('academic_score', 0) >= 70),
            'llm_enriched_count': sum(1 for n in enriched_notifications
                                     if n.get('structured_insights', {}).get('enriched_by_llm')),
        }
    }


@router.post("/batch-enrich")
async def batch_enrich_notifications(
    gmail_ids: List[str],
    use_llm: bool = False,
):
    """
    Batch enrich multiple notifications.
    
    Useful for:
    - Bulk processing after initial sync
    - Re-enriching with new LLM every N hours
    - Testing LLM quality on inbox
    
    POST /api/notifications/batch-enrich
    {
        "gmail_ids": ["msg_123", "msg_124", "msg_125"],
        "use_llm": true
    }
    """
    
    # TODO: Fetch from DB
    results = []
    
    llm_client = None
    if use_llm:
        try:
            from ollama import Client
            llm_client = Client(host='http://localhost:11434')
        except ImportError:
            pass
    
    for gmail_id in gmail_ids[:100]:  # Cap at 100 to prevent abuse
        # Fetch notification from DB
        notification = {
            'gmail_id': gmail_id,
            'subject': f'Sample email {gmail_id}',
            'body_text': 'Sample body...',
            'academic_score': 75.0,
        }
        
        enriched = AcademicContextEngine.enrich_notification_with_insights(
            notification,
            use_llm=use_llm,
            llm_client=llm_client,
        )
        results.append(enriched)
    
    return {
        'processed': len(results),
        'notifications': results,
    }
