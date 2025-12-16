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
    oauth_connected: bool  # <-- Add this line

    class Config:
        orm_mode = True

class UserProfileSetup(BaseModel):
    name: str
    branch: str
    semester: int
    sid: str
