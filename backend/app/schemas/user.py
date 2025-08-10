from pydantic import BaseModel, Field, EmailStr, validator
from typing import List, Optional
from datetime import datetime
from uuid import UUID
import uuid

class UserBase(BaseModel):
    email: EmailStr
    chef_id: Optional[UUID] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=100)
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one digit')
        return v

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    chef_id: Optional[UUID] = None

class User(UserBase):
    id: UUID = Field(default_factory=uuid.uuid4)
    favorites: List[UUID] = Field(default_factory=list)  # Recipe IDs
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True

class UserInDB(User):
    password_hash: str

class UserFavorites(BaseModel):
    user_id: UUID
    recipe_ids: List[UUID]

class AddFavoriteRequest(BaseModel):
    recipe_id: UUID

class RemoveFavoriteRequest(BaseModel):
    recipe_id: UUID
