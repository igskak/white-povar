from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn

from app.core.settings import settings
from app.api.v1.endpoints import recipes, search, auth, ai

# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description="Backend API for White-Label Cooking App",
    debug=settings.debug,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(auth.router, prefix="/auth", tags=["authentication"])
app.include_router(recipes.router, prefix="/recipes", tags=["recipes"])
app.include_router(search.router, prefix="/search", tags=["search"])
app.include_router(ai.router, prefix="/ai", tags=["ai-assistant"])

@app.get("/")
async def root():
    """Root endpoint - API health check"""
    return {
        "message": "White-Label Cooking App API",
        "version": settings.version,
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "environment": settings.environment}

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "error": str(exc) if settings.debug else "Something went wrong"}
    )

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level="debug" if settings.debug else "info"
    )
