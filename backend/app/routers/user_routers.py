from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.user import User
from app.models.schemas.user_schema import UserOut, UserProfileSetup
from app.utils.firebase_util import verify_firebase_token
from app.models.oauthToken import OAuthToken  # Add this import

router = APIRouter(prefix="/user", tags=["User"])

@router.get("/profile", response_model=UserOut)
def get_or_create_user(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    uid = firebase_data["uid"]
    email = firebase_data.get("email", "")
    name = firebase_data.get("name", "")

    user = db.query(User).filter(User.uid == uid).first()

    if not user:
        user = User(
            uid=uid,
            email=email,
            name=name,
            profile_completed=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    oauth_connected = (
        db.query(OAuthToken)
        .filter(OAuthToken.uid == uid)
        .first()
        is not None
    )

    return UserOut(
        uid=user.uid,
        email=user.email,
        name=user.name,
        semester=user.semester,
        branch=user.branch,
        sid=user.sid,
        profile_completed=user.profile_completed,
        oauth_connected=oauth_connected,
    )


@router.put("/profile-setup", response_model=UserOut)
def update_profile(
    data: UserProfileSetup,
    firebase_data = Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    uid = firebase_data["uid"]
    user = db.query(User).filter(User.uid == uid).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Apply updates
    user.name = data.name
    user.branch = data.branch
    user.semester = data.semester
    user.sid = data.sid

    # Ensure profile stays marked as completed
    user.profile_completed = True

    db.commit()
    db.refresh(user)
    return user


@router.post("/profile-setup", response_model=UserOut)
def create_profile(
    data: UserProfileSetup,
    firebase_data = Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):

    uid = firebase_data["uid"]
    user = db.query(User).filter(User.uid == uid).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.name = data.name
    user.branch = data.branch
    user.semester = data.semester
    user.sid = data.sid
    user.profile_completed = True

    db.commit()
    db.refresh(user)
    return user
