from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.models.user import User
from app.models.schemas.user_schema import UserOut, UserProfileSetup
from app.utils.firebase_util import verify_firebase_token
from app.models.oauthToken import OAuthToken

"""
User-related routes.

Security model:
- All routes depend on `verify_firebase_token`
- Backend NEVER trusts a UID sent explicitly by the client
- UID is always derived from a verified Firebase ID token
- Each request is scoped to the authenticated user's own resources

This prevents:
- UID spoofing
- Cross-user data access
- Unauthorized API usage via direct HTTP calls
"""

router = APIRouter(prefix="/user", tags=["User"])


@router.get("/profile", response_model=UserOut)
def get_or_create_user(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Fetch the authenticated user's profile.

    Behavior:
    - If the user exists in the database, return their profile
    - If the user does NOT exist, create a minimal user record

    Rationale:
    - Firebase guarantees identity, but does not manage application-level profiles
    - This lazy-creation pattern avoids a separate "signup" backend flow
    - First authenticated request initializes backend state for the user

    Example use case:
    - Frontend calls this endpoint immediately after Firebase login
    - Backend ensures a corresponding User row exists
    """

    # UID is extracted from a verified Firebase ID token
    # This UID cannot be forged by the client
    uid = firebase_data["uid"]

    # Optional fields depending on Firebase auth provider
    email = firebase_data.get("email", "")
    name = firebase_data.get("name", "")

    # User records are always queried by UID to enforce ownership
    user = db.query(User).filter(User.uid == uid).first()

    if not user:
        # Create a backend user record on first login
        user = User(
            uid=uid,
            email=email,
            name=name,
            profile_completed=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    # Check whether the user has completed Gmail OAuth
    # This is used by the frontend to decide whether to prompt for Gmail connection
    oauth_connected = (
        db.query(OAuthToken)
        .filter(OAuthToken.uid == uid)
        .first()
        is not None
    )

    # Explicitly shape the response rather than returning the ORM object
    # This prevents accidental exposure of internal fields
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
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Update an existing user's profile.

    Security considerations:
    - UID is derived from the Firebase token, not request input
    - A user can only update their own profile
    - No route allows updating another user's data

    Example use case:
    - User edits profile details after initial setup
    """

    uid = firebase_data["uid"]

    user = db.query(User).filter(User.uid == uid).first()
    if not user:
        # This should rarely happen because profiles are created lazily on login
        raise HTTPException(status_code=404, detail="User not found")

    # Apply validated profile fields
    user.name = data.name
    user.branch = data.branch
    user.semester = data.semester
    user.sid = data.sid

    # Profile is considered completed once these fields are set
    user.profile_completed = True

    db.commit()
    db.refresh(user)
    return user


@router.post("/profile-setup", response_model=UserOut)
def create_profile(
    data: UserProfileSetup,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Initial profile setup endpoint.

    Note:
    - Functionally similar to PUT /profile-setup
    - Exists to support frontend flows that distinguish
      between "first-time setup" and "edit profile"

    This endpoint does NOT create a new user record.
    User records are created during the first authenticated request.
    """

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


@router.post("/logout")
def logout(
    firebase_data=Depends(verify_firebase_token),
):
    """
    Logout endpoint.

    Important clarification:
    - Firebase authentication is handled client-side
    - Backend cannot invalidate Firebase ID tokens directly
    - Token expiration and revocation are managed by Firebase

    Purpose of this endpoint:
    - Validate that the request comes from an authenticated user
    - Allow frontend to notify backend of logout events (optional)
    - Placeholder for future audit logging or session tracking

    This endpoint does NOT revoke authentication by itself.
    """

    uid = firebase_data["uid"]
    return {"status": "logged_out", "uid": uid}
