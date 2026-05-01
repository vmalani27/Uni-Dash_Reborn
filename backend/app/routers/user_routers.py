from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_supabase_db
from app.models.user import User
from app.models.schemas.user_schema import UserOut, UserProfileSetup, UserOAuthStatusOut, ProfileCreate, ProfileUpdate
from app.utils.firebase_util import verify_firebase_token
from app.models.oauthToken import OAuthToken
from app.models.gmail.gmail_sync_status import GmailSyncStatus

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
    full_name = firebase_data.get("name", "") or firebase_data.get("full_name", "")
    # Provide sensible defaults for required fields if not present
    degree = "BTech"
    branch = "CSE"
    admission_year = 2023

    # User records are always queried by UID to enforce ownership
    user = db.query(User).filter(User.uid == uid).first()

    if not user:
        # Create a backend user record on first login
        user = User(
            uid=uid,
            email=email,
            full_name=full_name,
            degree=degree,
            branch=branch,
            admission_year=admission_year,
            profile_completed=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    # Check whether the user has completed Gmail OAuth
    # This is used by the frontend to decide whether to prompt for Gmail connection
    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    has_token = token is not None

    if has_token and not user.oauth_connected and not getattr(user, "reauth_required", False):
        user.oauth_connected = True
        db.commit()
        db.refresh(user)

    oauth_connected = bool(user.oauth_connected)

    # Determine whether the user connected an admin-capable Gmail account
    # (i.e. token scopes include gmail.send)
    admin_connected = False
    if token and token.scopes:
        try:
            if "gmail.send" in token.scopes:
                admin_connected = True
        except Exception:
            admin_connected = False

    # Explicitly shape the response rather than returning the ORM object
    # This prevents accidental exposure of internal fields
    return UserOut(
        uid=user.uid,
        email=user.email,
        full_name=user.full_name,
        degree=user.degree,
        branch=user.branch,
        admission_year=user.admission_year,
        sid=user.sid,
        profile_completed=user.profile_completed,
        oauth_connected=oauth_connected,
        admin_connected=admin_connected,
        reauth_required=bool(getattr(user, "reauth_required", False)),
        reauth_reason=getattr(user, "reauth_reason", None),
    )


@router.get("/oauth/status", response_model=UserOAuthStatusOut)
def get_oauth_status(
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    uid = firebase_data["uid"]
    user = db.query(User).filter(User.uid == uid).first()
    token = db.query(OAuthToken).filter(OAuthToken.uid == uid).first()
    sync = db.query(GmailSyncStatus).filter(GmailSyncStatus.uid == uid).first()

    admin_connected = False
    if token and token.scopes:
        admin_connected = "gmail.send" in token.scopes

    return UserOAuthStatusOut(
        oauth_connected=bool(user.oauth_connected) if user else False,
        admin_connected=admin_connected,
        reauth_required=bool(getattr(user, "reauth_required", False)) if user else False,
        reauth_reason=getattr(user, "reauth_reason", None) if user else None,
        sync_status=getattr(sync, "status", None),
        sync_error_message=getattr(sync, "error_message", None),
        last_sync_at=sync.last_sync_date.isoformat() if (sync and sync.last_sync_date) else None,
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

    user.full_name = data.full_name
    user.degree = data.degree
    user.branch = data.branch
    user.admission_year = data.admission_year
    user.sid = data.sid

    # Profile is considered completed once these fields are set
    user.profile_completed = True

    db.commit()
    db.refresh(user)
    return user


@router.patch("/profile-setup", response_model=UserOut)
def update_profile_partial(
    data: ProfileUpdate,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Partially update an existing user's profile.

    Behavior:
    - Only fields explicitly provided in the request are updated
    - Omitted fields remain unchanged
    - At least one field must be provided

    Security considerations:
    - UID is derived from the Firebase token, not request input
    - A user can only update their own profile
    - Immutable fields (full_name, degree, sid) cannot be updated via this endpoint

    Use case:
    - User modifies branch or admission_year after profile creation
    - Minimal payload sent to backend (only changed fields)
    - No 422 validation errors due to missing immutable fields

    Example payloads:
    - {"branch": "ECE"}
    - {"admission_year": 2023}
    - {"branch": "ECE", "admission_year": 2023}
    """

    uid = firebase_data["uid"]

    user = db.query(User).filter(User.uid == uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Only update fields that are explicitly provided (not None)
    if data.branch is not None:
        user.branch = data.branch
    if data.admission_year is not None:
        user.admission_year = data.admission_year

    db.commit()
    db.refresh(user)
    return user


@router.post("/profile-setup", response_model=UserOut)
def create_profile(
    data: ProfileCreate,
    firebase_data=Depends(verify_firebase_token),
    db: Session = Depends(get_supabase_db),
):
    """
    Initial profile setup endpoint.

    Note:
    - Functionally similar to PUT /profile-setup
    - Exists to support frontend flows that distinguish
      between "first-time setup" and "edit profile"
    - This endpoint does NOT create a new user record.
      User records are created during the first authenticated request.
    """

    uid = firebase_data["uid"]

    user = db.query(User).filter(User.uid == uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.full_name = data.full_name
    user.degree = data.degree
    user.branch = data.branch
    user.admission_year = data.admission_year
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
