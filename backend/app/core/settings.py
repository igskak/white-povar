from pydantic_settings import BaseSettings
from typing import List, Optional
import os
import json


class Settings(BaseSettings):
    # Application
    app_name: str = "White Povar API"
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
    supabase_jwt_secret: Optional[str] = None  # JWT secret for token verification

    # OpenAI
    openai_api_key: str

    # RevenueCat is the managed mobile-billing provider selected for COM-02.
    # This value is server-only; it must never be supplied as a dart-define.
    revenuecat_webhook_authorization: Optional[str] = None

    # Firebase (deprecated - now using Supabase Auth)
    # Kept for backward compatibility, but no longer required
    firebase_project_id: Optional[str] = None

    # CORS - Production ready origins
    allowed_origins: str = "https://white-povar-p79r.onrender.com,http://localhost:3000,http://localhost:8080"

    # Database
    database_url: Optional[str] = None

    # File Storage
    supabase_storage_bucket: str = "recipe-images"
    max_file_size: int = 10 * 1024 * 1024  # 10MB

    # System Standardization Settings
    default_locale: str = "uk"
    default_unit_system: str = "metric"
    default_temperature_unit: str = "C"
    default_timezone: str = "UTC"
    default_currency: str = "EUR"
    canonical_date_format: str = "ISO_8601"
    data_normalize_input: bool = True
    supported_locales: str = "uk,en,it"

    # Measurement Settings
    ingredient_round_decimals: int = 1
    enable_unit_auto_convert: bool = True
    enable_auto_translate: bool = True

    # Search and AI Settings
    search_language: str = "uk"
    ai_target_lang: str = "uk"
    ai_recipe_generation_model: str = "gpt-4o-mini"
    ai_recipe_generation_requests_per_minute: int = 3
    ai_recipe_generation_daily_token_budget: int = 4400

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
        origins = [
            origin.strip()
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]
        if self.environment != "production":
            for origin in ("http://localhost:3000", "http://localhost:8080"):
                if origin not in origins:
                    origins.append(origin)
        return origins

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"

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
