from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.models.ai_layer import AcademicEntity, EntityActionState
from app.services.sync_event_bus import invalidate_dashboard_snapshot, publish_user_event
from app.utils.firebase_util import verify_firebase_token


router = APIRouter(prefix="/items", tags=["Items"])


def _publish_item_updated(uid: str, item_id: int, action: str) -> None:
    invalidate_dashboard_snapshot(uid)
    publish_user_event(
        uid,
        {
            "type": "item_updated",
            "item_id": item_id,
            "action": action,
            "at": datetime.utcnow().isoformat(),
        },
    )


def _get_entity_action_state(db: Session, uid: str, entity_id: int) -> EntityActionState:
    state = db.query(EntityActionState).filter(
        EntityActionState.entity_id == entity_id,
        EntityActionState.uid == uid,
    ).first()
    if state is None:
        state = EntityActionState(entity_id=entity_id, uid=uid)
        db.add(state)
        db.flush()
    return state


def _resolve_entity_state(
    db: Session,
    uid: str,
    item_id: int,
) -> tuple[AcademicEntity | None, EntityActionState | None]:
    entity = db.query(AcademicEntity).filter(
        AcademicEntity.id == item_id,
        AcademicEntity.uid == uid,
    ).first()
    if entity is not None:
        return entity, _get_entity_action_state(db, uid, entity.id)

    state = db.query(EntityActionState).join(
        AcademicEntity, AcademicEntity.id == EntityActionState.entity_id
    ).filter(
        EntityActionState.entity_id == item_id,
        EntityActionState.uid == uid,
        AcademicEntity.uid == uid,
    ).first()
    if state is None:
        return None, None
    entity = db.query(AcademicEntity).filter(
        AcademicEntity.id == state.entity_id,
        AcademicEntity.uid == uid,
    ).first()
    return entity, state


@router.post("/{item_id}/complete")
def complete_item(
    item_id: int,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    entity, state = _resolve_entity_state(db, uid, item_id)
    if entity is None or state is None:
        raise HTTPException(status_code=404, detail="Item not found")

    state.completed = True
    state.dismissed = False
    db.commit()
    _publish_item_updated(uid, item_id, "complete")
    return {
        "status": "success",
        "item_id": item_id,
        "is_completed": True,
        "is_dismissed": False,
    }


@router.post("/{item_id}/dismiss")
def dismiss_item(
    item_id: int,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    entity, state = _resolve_entity_state(db, uid, item_id)
    if entity is None or state is None:
        raise HTTPException(status_code=404, detail="Item not found")

    state.completed = False
    state.dismissed = True
    db.commit()
    _publish_item_updated(uid, item_id, "dismiss")
    return {
        "status": "success",
        "item_id": item_id,
        "is_completed": False,
        "is_dismissed": True,
    }
