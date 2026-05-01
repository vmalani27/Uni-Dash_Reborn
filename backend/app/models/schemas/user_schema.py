from pydantic import BaseModel

class UserCreate(BaseModel):
    uid: str
    email: str
    name: str


from typing import Optional


class UserOut(BaseModel):
    uid: str
    email: str
    full_name: str
    degree: str
    branch: str
    admission_year: int
    sid: Optional[str] = None
    profile_completed: bool
    oauth_connected: bool
    admin_connected: bool
    reauth_required: bool = False
    reauth_reason: Optional[str] = None

    class Config:
        from_attributes = True


class UserProfileSetup(BaseModel):
    full_name: str
    degree: str
    branch: str
    admission_year: int
    sid: str


class ProfileCreate(BaseModel):
    """Schema for creating a new user profile (POST /user/profile-setup)."""
    full_name: str
    degree: str
    branch: str
    admission_year: int
    sid: str


class ProfileUpdate(BaseModel):
    """Schema for updating an existing user profile (PATCH /user/profile-setup).
    
    All fields are optional. Only provided fields will be updated.
    This allows partial updates without requiring the full profile payload.
    """
    branch: Optional[str] = None
    admission_year: Optional[int] = None


class UserOAuthStatusOut(BaseModel):
    oauth_connected: bool
    admin_connected: bool
    reauth_required: bool
    reauth_reason: Optional[str] = None
    sync_status: Optional[str] = None
    sync_error_message: Optional[str] = None
    last_sync_at: Optional[str] = None
