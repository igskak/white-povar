from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from contextlib import asynccontextmanager
import uvicorn
import os

from app.core.settings import settings
from app.api.v1.endpoints import analytics, recipes, search, auth, ai, config, ingestion, videos, subscription, pantry, collections, commerce, studio, lifecycle
from app.middleware.localization import LocalizationMiddleware
from app.ingestion.service import startup_ingestion, shutdown_ingestion

# Lifespan manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await startup_ingestion()
    yield
    # Shutdown
    await shutdown_ingestion()

# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description="Backend API for White Povar",
    debug=settings.debug,
    lifespan=lifespan,
    docs_url=None if settings.is_production else "/docs",
    redoc_url=None if settings.is_production else "/redoc",
    openapi_url=None if settings.is_production else "/openapi.json",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add localization middleware
app.add_middleware(LocalizationMiddleware)

# Include API routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["authentication"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["analytics"])
app.include_router(lifecycle.router, prefix="/api/v1/lifecycle", tags=["lifecycle"])
app.include_router(recipes.router, prefix="/api/v1/recipes", tags=["recipes"])
app.include_router(search.router, prefix="/api/v1/search", tags=["search"])
app.include_router(ai.router, prefix="/api/v1/ai", tags=["ai-assistant"])
app.include_router(config.router, prefix="/api/v1/config", tags=["configuration"])
app.include_router(config.bootstrap_router, prefix="/api/v1", tags=["bootstrap"])
app.include_router(ingestion.router, prefix="/api/v1/ingestion", tags=["ingestion"])
app.include_router(videos.router, prefix="/api/v1/videos", tags=["videos"])
app.include_router(subscription.router, prefix="/api/v1/subscription", tags=["subscription"])
app.include_router(pantry.router, prefix="/api/v1", tags=["pantry"])
app.include_router(collections.router, prefix="/api/v1/collections", tags=["collections"])
app.include_router(commerce.router, prefix="/api/v1/commerce", tags=["commerce"])
app.include_router(studio.router, prefix="/api/v1/studio", tags=["internal-studio"])

@app.get("/")
async def root():
    """Root endpoint for API service identity checks."""
    return {
        "message": "White Povar API",
        "version": settings.version,
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Liveness probe; intentionally exposes neither configuration nor tenant data."""
    return {"status": "healthy", "service": "api"}

@app.get("/health/ready")
async def readiness_check():
    """Readiness check for required production configuration."""
    missing = []
    for key, value in {
        "SUPABASE_URL": settings.supabase_url,
        "SUPABASE_KEY": settings.supabase_key,
        "SUPABASE_SERVICE_KEY": settings.supabase_service_key,
        "OPENAI_API_KEY": settings.openai_api_key,
    }.items():
        if not value:
            missing.append(key)

    if missing:
        raise HTTPException(
            status_code=503,
            detail={"status": "not_ready", "missing": missing},
        )

    return {"status": "ready", "environment": settings.environment}

if settings.environment == "development":
    @app.get("/admin_video_upload.html", include_in_schema=False)
    async def admin_video_upload():
        """Serve the local-only video upload interface."""
        file_path = os.path.join(
            os.path.dirname(__file__), "..", "admin_video_upload.html"
        )
        if os.path.exists(file_path):
            return FileResponse(file_path, media_type="text/html")
        raise HTTPException(status_code=404, detail="Admin interface not found")

# Import standardized exceptions
from app.core.exceptions import (
    BaseAPIException,
    DatabaseException,
    ValidationException,
    AuthenticationException,
    AuthorizationException,
    NotFoundException,
    ConflictException,
    BusinessLogicException,
    RateLimitException,
    InternalServerException,
)
from app.core.premium_access import PremiumAccessDenied
from pydantic import ValidationError
import logging

logger = logging.getLogger(__name__)

# Standardized exception handlers
@app.exception_handler(PremiumAccessDenied)
async def premium_access_denied_handler(request, exc: PremiumAccessDenied):
    """Handle premium access denied exceptions with upgrade prompt"""
    logger.warning(f"🚨 PremiumAccessDenied: {exc.detail} - Path: {request.url.path}")

    # The detail is already a dict with error, message, and upgrade_prompt
    # Just return it as-is with the proper status code
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.detail,
        headers=exc.headers
    )

@app.exception_handler(BaseAPIException)
async def base_api_exception_handler(request, exc: BaseAPIException):
    """Handle custom API exceptions with consistent structure"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "error_code": exc.error_code,
            "type": "api_error"
        },
        headers=exc.headers
    )

@app.exception_handler(ValidationError)
async def validation_exception_handler(request, exc: ValidationError):
    """Handle Pydantic validation errors"""
    logger.warning(f"Validation error: {exc}")
    return JSONResponse(
        status_code=422,
        content={
            "detail": "Validation error",
            "error_code": "VALIDATION_ERROR",
            "type": "validation_error",
            "errors": exc.errors()
        }
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc: HTTPException):
    """Handle FastAPI HTTP exceptions"""
    logger.warning(f"🚨 HTTPException: {exc.status_code} - {exc.detail} - Path: {request.url.path}")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "error_code": f"HTTP_{exc.status_code}",
            "type": "http_error"
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(request, exc: Exception):
    """Handle unexpected exceptions"""
    # Do not put request bodies or exception text in error tracking: those can
    # contain search transcripts, health data or authentication material.
    logger.error("Unhandled request error path=%s type=%s", request.url.path,
                 type(exc).__name__, exc_info=True)

    # In debug mode, show the actual error
    if settings.debug:
        return JSONResponse(
            status_code=500,
            content={
                "detail": f"Internal server error: {str(exc)}",
                "error_code": "INTERNAL_ERROR",
                "type": "internal_error",
                "debug_info": {
                    "exception_type": type(exc).__name__,
                    "exception_message": str(exc)
                }
            }
        )

    # In production, hide implementation details
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An unexpected error occurred. Please try again later.",
            "error_code": "INTERNAL_ERROR",
            "type": "internal_error"
        }
    )

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level="debug" if settings.debug else "info"
    )
