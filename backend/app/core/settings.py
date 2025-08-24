from pydantic_settings import BaseSettings
from typing import List, Optional
import os
import json


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

    # CORS - Production ready origins
    allowed_origins: str = "https://white-povar.web.app,https://white-povar.firebaseapp.com,http://localhost:3000,http://localhost:8080"

    # Database
    database_url: Optional[str] = None

    # File Storage
    supabase_storage_bucket: str = "recipe-images"
    max_file_size: int = 10 * 1024 * 1024  # 10MB

    # System Standardization Settings
    default_locale: str = "en"
    default_unit_system: str = "metric"
    default_temperature_unit: str = "C"
    default_timezone: str = "UTC"
    default_currency: str = "EUR"
    canonical_date_format: str = "ISO_8601"
    data_normalize_input: bool = True
    supported_locales: str = "en,it"

    # Measurement Settings
    ingredient_round_decimals: int = 1
    enable_unit_auto_convert: bool = True
    enable_auto_translate: bool = True

    # Search and AI Settings
    search_language: str = "en"
    ai_target_lang: str = "en"

    # Pagination
    default_page_size: int = 20

    # Ingestion Settings
    ingestion_workers: int = 2
    ingestion_base_path: str = "data/ingestion"
    ingestion_max_retries: int = 3
    ingestion_confidence_threshold: float = 0.75
    
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
    
    @property
    def cors_origins(self) -> List[str]:
        """Parse allowed_origins string into a list for CORS configuration"""
        return [origin.strip() for origin in self.allowed_origins.split(",")]

    @property
    def supported_locales_list(self) -> List[str]:
        """Parse supported_locales string into a list"""
        return [locale.strip() for locale in self.supported_locales.split(",")]

    @property
    def is_metric_system(self) -> bool:
        """Check if using metric system"""
        return self.default_unit_system.lower() == "metric"

    @property
    def is_celsius(self) -> bool:
        """Check if using Celsius for temperature"""
        return self.default_temperature_unit.upper() == "C"


# Global settings instance
settings = Settings()
