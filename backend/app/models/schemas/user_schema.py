from pydantic import BaseModel

class UserCreate(BaseModel):
    uid: str
    email: str
    name: str


from typing import Optional

class UserOut(BaseModel):
    uid: str
    email: str
    name: str
    semester: Optional[int] = None
    branch: Optional[str] = None
    sid: Optional[str] = None
    profile_completed: bool
    oauth_connected: bool
    admin_connected: bool  # indicates whether the user connected an admin (send) capable Gmail account
    reauth_required: bool = False
    reauth_reason: Optional[str] = None

    class Config:
        from_attributes = True

class UserProfileSetup(BaseModel):
    name: str
    branch: str
    semester: int
    sid: str


class UserOAuthStatusOut(BaseModel):
    oauth_connected: bool
    admin_connected: bool
    reauth_required: bool
    reauth_reason: Optional[str] = None
    sync_status: Optional[str] = None
    sync_error_message: Optional[str] = None
    last_sync_at: Optional[str] = None
