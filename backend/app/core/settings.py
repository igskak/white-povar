from pydantic_settings import BaseSettings
from typing import List, Optional
import os


class Settings(BaseSettings):
    # Application
    app_name: str = "White-Label Cooking App API"
    version: str = "1.0.0"
    debug: bool = False
    environment: str = "production"
    
    # Security
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    # Supabase
    supabase_url: str
    supabase_key: str
    supabase_service_key: str
    
    # OpenAI
    openai_api_key: str
    
    # Firebase
    firebase_project_id: str
    
    # CORS
    allowed_origins: List[str] = ["*"]
    
    # Database
    database_url: Optional[str] = None
    
    class Config:
        env_file = ".env"
        case_sensitive = False
        
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Construct database URL from Supabase URL if not provided
        if not self.database_url and self.supabase_url:
            # Convert Supabase URL to PostgreSQL connection string
            # Format: postgresql://postgres:[password]@[host]:5432/postgres
            supabase_host = self.supabase_url.replace("https://", "").replace("http://", "")
            # Note: In production, you'd get the actual DB password from Supabase dashboard
            self.database_url = f"postgresql://postgres:password@{supabase_host}:5432/postgres"


# Global settings instance
settings = Settings()
