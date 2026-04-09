"""
Global search router for academic items.
Supports keyword search across titles, summaries, and categories.
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from datetime import datetime, timedelta
from app.core.database import get_supabase_db
from app.models.gmail.gmail_message import GmailMessage
from app.core.firebase_auth import verify_firebase_token
from typing import Optional

router = APIRouter(prefix="/search", tags=["search"])


@router.get("/academic")
def search_academic_items(
    q: str = Query(..., min_length=1, max_length=200),
    db: Session = Depends(get_supabase_db),
    firebase_data=Depends(verify_firebase_token),
):
    """
    Global search across academic items.
    
    Searches:
    - Subject title
    - AI summary
    - Category/topic
    - Special keywords: "today", "this week", "assignment", "exam", "opportunity"
    
    Returns results grouped by time period and sorted by urgency.
    """
    uid = firebase_data.get("uid")
    if not uid:
        return {"error": "Unauthorized", "results": []}
    
    q_lower = q.lower().strip()
    
    # Start with base query for user's items
    query = db.query(GmailMessage).filter(GmailMessage.uid == uid)
    
    # Check for special keywords
    is_today_search = "today" in q_lower
    is_week_search = "this week" in q_lower or "week" in q_lower
    
    category_filters = {
        "assignment": "ASSIGNMENT",
        "exam": "EXAM",
        "opportunity": "OPPORTUNITY",
        "admin": "ACADEMIC_ADMIN",
        "announcement": "ACADEMIC_ADMIN",
        "event": "OPPORTUNITY",
        "hackathon": "OPPORTUNITY",
    }
    
    category_keyword = None
    for keyword, category in category_filters.items():
        if keyword in q_lower:
            category_keyword = category
            break
    
    # Apply category filter if keyword found
    if category_keyword:
        query = query.filter(GmailMessage.normalized_topic == category_keyword)
    
    # Apply time-based filters
    now = datetime.utcnow()
    today_start = datetime(now.year, now.month, now.day)
    today_end = today_start + timedelta(days=1)
    
    if is_today_search:
        query = query.filter(
            and_(
                GmailMessage.deadline_iso >= today_start,
                GmailMessage.deadline_iso < today_end
            )
        )
    elif is_week_search:
        week_end = today_start + timedelta(days=7)
        query = query.filter(
            and_(
                GmailMessage.deadline_iso >= today_start,
                GmailMessage.deadline_iso <= week_end
            )
        )
    else:
        # Text-based search: match title, summary, or category
        search_term = f"%{q_lower}%"
        query = query.filter(
            or_(
                GmailMessage.subject.ilike(search_term),
                GmailMessage.ai_summary.ilike(search_term),
                GmailMessage.ai_label_topic.ilike(search_term),
            )
        )
    
    # Fetch results
    results = query.all()
    
    if not results:
        return {
            "query": q,
            "total": 0,
            "groups": {}
        }
    
    # Group by time period
    today_items = []
    tomorrow_items = []
    week_items = []
    other_items = []
    
    tomorrow_start = today_start + timedelta(days=1)
    tomorrow_end = tomorrow_start + timedelta(days=1)
    week_end = today_start + timedelta(days=7)
    
    for item in results:
        if not item.deadline_iso:
            other_items.append(item)
            continue
        
        if today_start <= item.deadline_iso < today_end:
            today_items.append(item)
        elif tomorrow_start <= item.deadline_iso < tomorrow_end:
            tomorrow_items.append(item)
        elif today_start <= item.deadline_iso <= week_end:
            week_items.append(item)
        else:
            other_items.append(item)
    
    # Sort by academic score (urgency proxy)
    def sort_by_score(items):
        return sorted(items, key=lambda x: x.academic_score, reverse=True)
    
    today_items = sort_by_score(today_items)
    tomorrow_items = sort_by_score(tomorrow_items)
    week_items = sort_by_score(week_items)
    other_items = sort_by_score(other_items)
    
    # Format response
    def format_item(item):
        return {
            "id": item.id,
            "gmail_id": item.gmail_id,
            "subject": item.subject,
            "summary": item.ai_summary,
            "topic": item.ai_label_topic,
            "urgency": item.ai_label_urgency,
            "category": item.normalized_topic,
            "deadline": item.deadline_iso.isoformat() if item.deadline_iso else None,
            "score": item.academic_score,
            "sender": item.sender,
        }
    
    return {
        "query": q,
        "total": len(results),
        "groups": {
            "today": [format_item(i) for i in today_items],
            "tomorrow": [format_item(i) for i in tomorrow_items],
            "thisWeek": [format_item(i) for i in week_items],
            "others": [format_item(i) for i in other_items],
        }
    }


@router.get("/academic/suggestions")
def get_search_suggestions(
    q: str = Query(..., min_length=1, max_length=50),
    db: Session = Depends(get_supabase_db),
    firebase_data=Depends(verify_firebase_token),
    limit: int = Query(5, ge=1, le=10),
):
    """
    Get autocomplete suggestions for search.
    Returns unique subjects and topics matching the query.
    """
    uid = firebase_data.get("uid")
    if not uid:
        return {"suggestions": []}
    
    q_lower = q.lower()
    search_term = f"%{q_lower}%"
    
    # Get matching subjects
    subjects = (
        db.query(GmailMessage.subject)
        .filter(
            and_(
                GmailMessage.uid == uid,
                GmailMessage.subject.ilike(search_term),
            )
        )
        .distinct()
        .limit(limit)
        .all()
    )
    
    # Get matching topics
    topics = (
        db.query(GmailMessage.ai_label_topic)
        .filter(
            and_(
                GmailMessage.uid == uid,
                GmailMessage.ai_label_topic.ilike(search_term),
            )
        )
        .distinct()
        .limit(limit // 2)
        .all()
    )
    
    suggestions = []
    suggestions.extend([s[0] for s in subjects if s[0]])
    suggestions.extend([t[0] for t in topics if t[0]])
    
    return {
        "suggestions": list(set(suggestions))[:limit]  # Deduplicate and limit
    }
