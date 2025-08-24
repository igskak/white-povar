#!/usr/bin/env python3
"""
Setup script for Recipe Ingestion System
"""

import os
import sys
import subprocess
from pathlib import Path


def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 8):
        print("❌ Python 3.8 or higher is required")
        return False
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor} detected")
    return True


def install_dependencies():
    """Install required dependencies"""
    print("\n📦 Installing dependencies...")
    
    try:
        # Install main requirements first
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", "backend/requirements.txt"], 
                      check=True, capture_output=True)
        print("✅ Main dependencies installed")
        
        # Install ingestion-specific requirements
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", "backend/requirements-ingestion.txt"], 
                      check=True, capture_output=True)
        print("✅ Ingestion dependencies installed")
        
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install dependencies: {e}")
        return False


def create_directories():
    """Create necessary directories"""
    print("\n📁 Creating directories...")
    
    directories = [
        "data/ingestion/inbox",
        "data/ingestion/processed", 
        "data/ingestion/failed",
        "data/ingestion/dlq",
        "logs"
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
        print(f"✅ Created {directory}")


def check_env_file():
    """Check if .env file exists and has required variables"""
    print("\n🔧 Checking environment configuration...")
    
    env_path = Path("backend/.env")
    if not env_path.exists():
        print("❌ .env file not found in backend/")
        print("📝 Please create backend/.env with the following variables:")
        print("""
OPENAI_API_KEY=your_openai_api_key_here
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_key
SECRET_KEY=your_secret_key
FIREBASE_PROJECT_ID=your_firebase_project_id
        """)
        return False
    
    # Check for required variables
    required_vars = [
        "OPENAI_API_KEY",
        "SUPABASE_URL", 
        "SUPABASE_KEY",
        "SUPABASE_SERVICE_KEY"
    ]
    
    env_content = env_path.read_text()
    missing_vars = []
    
    for var in required_vars:
        if f"{var}=" not in env_content:
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing environment variables: {', '.join(missing_vars)}")
        return False
    
    print("✅ Environment configuration looks good")
    return True


def check_database_schema():
    """Check if database schema is up to date"""
    print("\n🗄️  Database schema check...")
    print("⚠️  Please ensure you have run the database migrations:")
    print("   1. Connect to your Supabase database")
    print("   2. Execute the SQL commands from database_schema.sql")
    print("   3. Verify the following tables exist:")
    print("      - ingestion_jobs")
    print("      - recipe_fingerprints") 
    print("      - ingestion_reviews")
    
    response = input("\nHave you applied the database migrations? (y/n): ")
    return response.lower() in ['y', 'yes']


def create_sample_recipe():
    """Create a sample recipe file for testing"""
    print("\n📄 Creating sample recipe file...")
    
    sample_recipe = """
Chocolate Chip Cookies

A classic American cookie recipe that's perfect for any occasion.

Ingredients:
- 2 1/4 cups all-purpose flour
- 1 tsp baking soda
- 1 tsp salt
- 1 cup butter, softened
- 3/4 cup granulated sugar
- 3/4 cup brown sugar, packed
- 2 large eggs
- 2 tsp vanilla extract
- 2 cups chocolate chips

Instructions:
1. Preheat oven to 375°F (190°C).
2. In a medium bowl, whisk together flour, baking soda, and salt.
3. In a large bowl, cream together butter and both sugars until light and fluffy.
4. Beat in eggs one at a time, then add vanilla.
5. Gradually mix in the flour mixture until just combined.
6. Stir in chocolate chips.
7. Drop rounded tablespoons of dough onto ungreased baking sheets.
8. Bake for 9-11 minutes or until golden brown.
9. Cool on baking sheet for 2 minutes before transferring to wire rack.

Prep Time: 15 minutes
Cook Time: 10 minutes
Servings: 48 cookies
Difficulty: Easy
Cuisine: American
Category: Dessert
Tags: vegetarian, dessert, cookies, chocolate
    """
    
    sample_path = Path("data/ingestion/inbox/sample_chocolate_chip_cookies.txt")
    sample_path.write_text(sample_recipe.strip())
    print(f"✅ Created sample recipe: {sample_path}")


def main():
    """Main setup function"""
    print("🍳 Recipe Ingestion System Setup")
    print("=" * 40)
    
    # Check Python version
    if not check_python_version():
        return False
    
    # Install dependencies
    if not install_dependencies():
        return False
    
    # Create directories
    create_directories()
    
    # Check environment configuration
    if not check_env_file():
        return False
    
    # Check database schema
    if not check_database_schema():
        print("❌ Please apply database migrations before proceeding")
        return False
    
    # Create sample recipe
    create_sample_recipe()
    
    print("\n🎉 Setup completed successfully!")
    print("\nNext steps:")
    print("1. Start the application: cd backend && python -m uvicorn app.main:app --reload")
    print("2. Check service status: GET http://localhost:8000/api/v1/ingestion/status")
    print("3. The sample recipe should be automatically processed")
    print("4. Monitor processing: GET http://localhost:8000/api/v1/ingestion/jobs")
    print("\nFor detailed usage instructions, see RECIPE_INGESTION_GUIDE.md")
    
    return True


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
