from pydantic import BaseModel, Field, HttpUrl, validator
from typing import Dict, Any, Optional
from datetime import datetime
from uuid import UUID
import uuid

class SocialLinks(BaseModel):
    instagram: Optional[HttpUrl] = None
    facebook: Optional[HttpUrl] = None
    twitter: Optional[HttpUrl] = None
    youtube: Optional[HttpUrl] = None
    website: Optional[HttpUrl] = None

class ThemeConfig(BaseModel):
    primary_color: str = Field(..., regex=r'^#[0-9A-Fa-f]{6}$')
    secondary_color: str = Field(..., regex=r'^#[0-9A-Fa-f]{6}$')
    accent_color: str = Field(..., regex=r'^#[0-9A-Fa-f]{6}$')
    background_color: str = Field(..., regex=r'^#[0-9A-Fa-f]{6}$')
    text_color: str = Field(..., regex=r'^#[0-9A-Fa-f]{6}$')
    font_family: str = Field(default="Inter", min_length=1, max_length=50)
    
    @validator('primary_color', 'secondary_color', 'accent_color', 'background_color', 'text_color')
    def validate_hex_color(cls, v):
        if not v.startswith('#') or len(v) != 7:
            raise ValueError('Color must be a valid hex color (e.g., #FF5733)')
        return v.upper()

class ChefBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    bio: str = Field(..., min_length=1, max_length=1000)
    app_name: str = Field(..., min_length=1, max_length=50)
    avatar_url: Optional[HttpUrl] = None
    logo_url: Optional[HttpUrl] = None

class ChefCreate(ChefBase):
    theme_config: ThemeConfig
    social_links: Optional[SocialLinks] = None

class ChefUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    bio: Optional[str] = Field(None, min_length=1, max_length=1000)
    app_name: Optional[str] = Field(None, min_length=1, max_length=50)
    avatar_url: Optional[HttpUrl] = None
    logo_url: Optional[HttpUrl] = None
    theme_config: Optional[ThemeConfig] = None
    social_links: Optional[SocialLinks] = None

class Chef(ChefBase):
    id: UUID = Field(default_factory=uuid.uuid4)
    theme_config: ThemeConfig
    social_links: Optional[SocialLinks] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        from_attributes = True

class ChefConfig(BaseModel):
    """Simplified chef configuration for mobile app"""
    chef_id: UUID
    name: str
    app_name: str
    avatar_url: Optional[str] = None
    logo_url: Optional[str] = None
    theme: ThemeConfig
    social_links: Optional[SocialLinks] = None
