from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.models.ai_layer import AcademicEntity, EntityActionState, EntitySourceMap
from app.services.sync_event_bus import invalidate_dashboard_snapshot, publish_user_event
from app.utils.firebase_util import verify_firebase_token


router = APIRouter(prefix="/entities", tags=["Entities"])

ALLOWED_ENTITY_TYPES = {"ASSIGNMENT", "EXAM", "OPPORTUNITY", "ACADEMIC_ADMIN", "INFORMATION"}


class ManualEntityCreateRequest(BaseModel):
    canonical_title: str = Field(..., min_length=1)
    entity_type: str = Field(..., min_length=1)
    summary: Optional[str] = None
    best_deadline: Optional[datetime] = None
    confidence_score: float = 0.0


class ManualEntityUpdateRequest(BaseModel):
    canonical_title: Optional[str] = None
    entity_type: Optional[str] = None
    summary: Optional[str] = None
    best_deadline: Optional[datetime] = None
    confidence_score: Optional[float] = None


def _publish_entity_updated(uid: str, entity_id: int, action: str) -> None:
    invalidate_dashboard_snapshot(uid)
    publish_user_event(
        uid,
        {
            "type": "entity_updated",
            "entity_id": entity_id,
            "action": action,
            "at": datetime.utcnow().isoformat(),
        },
    )


def _serialize_entity(entity: AcademicEntity) -> dict:
    return {
        "id": entity.id,
        "uid": entity.uid,
        "origin": getattr(entity, "origin", "system") or "system",
        "canonical_title": entity.canonical_title,
        "summary": entity.summary,
        "entity_type": entity.entity_type,
        "best_deadline": entity.best_deadline.isoformat() if entity.best_deadline else None,
        "confidence_score": entity.confidence_score,
        "created_at": entity.created_at.isoformat() if entity.created_at else None,
        "updated_at": entity.updated_at.isoformat() if entity.updated_at else None,
    }


def _normalize_entity_type(entity_type: str) -> str:
    normalized = entity_type.strip().upper()
    if normalized not in ALLOWED_ENTITY_TYPES:
        raise HTTPException(status_code=400, detail="Invalid entity_type")
    return normalized


@router.get("/manual")
def list_manual_entities(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    entities = (
        db.query(AcademicEntity)
        .filter(AcademicEntity.uid == uid, AcademicEntity.origin == "manual")
        .order_by(AcademicEntity.updated_at.desc())
        .all()
    )
    return {"items": [_serialize_entity(entity) for entity in entities]}


@router.post("/manual", status_code=201)
def create_manual_entity(
    request: ManualEntityCreateRequest,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    entity = AcademicEntity(
        uid=uid,
        origin="manual",
        canonical_title=request.canonical_title.strip(),
        summary=request.summary.strip() if request.summary else None,
        entity_type=_normalize_entity_type(request.entity_type),
        best_deadline=request.best_deadline,
        confidence_score=float(request.confidence_score or 0.0),
    )
    db.add(entity)
    db.commit()
    db.refresh(entity)
    _publish_entity_updated(uid, entity.id, "create")
    return _serialize_entity(entity)


@router.patch("/manual/{entity_id}")
def update_manual_entity(
    entity_id: int,
    request: ManualEntityUpdateRequest,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    entity = db.query(AcademicEntity).filter(
        AcademicEntity.id == entity_id,
        AcademicEntity.uid == uid,
        AcademicEntity.origin == "manual",
    ).first()
    if entity is None:
        raise HTTPException(status_code=404, detail="Manual entity not found")

    if request.canonical_title is not None:
        entity.canonical_title = request.canonical_title.strip()
    if request.entity_type is not None:
        entity.entity_type = _normalize_entity_type(request.entity_type)
    if request.summary is not None:
        entity.summary = request.summary.strip() or None
    if request.best_deadline is not None:
        entity.best_deadline = request.best_deadline
    if request.confidence_score is not None:
        entity.confidence_score = float(request.confidence_score)

    db.commit()
    db.refresh(entity)
    _publish_entity_updated(uid, entity.id, "update")
    return _serialize_entity(entity)


@router.delete("/manual/{entity_id}")
def delete_manual_entity(
    entity_id: int,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    entity = db.query(AcademicEntity).filter(
        AcademicEntity.id == entity_id,
        AcademicEntity.uid == uid,
        AcademicEntity.origin == "manual",
    ).first()
    if entity is None:
        raise HTTPException(status_code=404, detail="Manual entity not found")

    db.query(EntityActionState).filter(EntityActionState.entity_id == entity.id).delete(synchronize_session=False)
    db.query(EntitySourceMap).filter(EntitySourceMap.entity_id == entity.id).delete(synchronize_session=False)
    db.delete(entity)
    db.commit()
    _publish_entity_updated(uid, entity_id, "delete")
    return {"status": "success", "entity_id": entity_id}
