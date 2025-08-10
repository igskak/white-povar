#!/usr/bin/env python3
"""
Development server runner for White-Label Cooking App Backend
"""

import uvicorn
import os
from pathlib import Path

def main():
    """Run the development server"""
    
    # Ensure we're in the backend directory
    backend_dir = Path(__file__).parent
    os.chdir(backend_dir)
    
    # Check if .env file exists
    env_file = backend_dir / ".env"
    if not env_file.exists():
        print("❌ .env file not found!")
        print("📝 Please copy .env.example to .env and configure your settings:")
        print("   cp .env.example .env")
        print("   nano .env")
        return
    
    print("🚀 Starting White-Label Cooking App Backend...")
    print("📍 API Documentation: http://localhost:8000/docs")
    print("📍 Alternative Docs: http://localhost:8000/redoc")
    print("📍 Health Check: http://localhost:8000/health")
    print()
    
    # Run the server
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        reload_dirs=["app"],
        log_level="info",
        access_log=True
    )

if __name__ == "__main__":
    main()
