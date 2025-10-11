#!/usr/bin/env python3
"""
Script to run database migrations directly using psycopg2.
"""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def run_migrations():
    """Run all migration files."""
    try:
        import psycopg2
    except ImportError:
        print("Error: psycopg2 not installed. Installing...")
        os.system("pip install psycopg2-binary")
        import psycopg2
    
    # Get database URL
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("Error: DATABASE_URL not set in .env file")
        sys.exit(1)
    
    print(f"Connecting to database...")
    
    # Connect to database
    try:
        conn = psycopg2.connect(database_url)
        conn.autocommit = True
        cursor = conn.cursor()
        print("✅ Connected to database successfully!\n")
    except Exception as e:
        print(f"❌ Error connecting to database: {e}")
        sys.exit(1)
    
    # Get migrations directory
    migrations_dir = Path(__file__).parent / "migrations"
    migration_files = sorted(migrations_dir.glob("*.sql"))
    
    if not migration_files:
        print("No migration files found")
        return
    
    print(f"Found {len(migration_files)} migration file(s)\n")
    
    # Run each migration
    for migration_file in migration_files:
        print(f"{'='*60}")
        print(f"Running: {migration_file.name}")
        print(f"{'='*60}")
        
        # Read migration file
        with open(migration_file, 'r') as f:
            sql = f.read()
        
        # Execute migration
        try:
            cursor.execute(sql)
            print(f"✅ Migration completed successfully!\n")
        except Exception as e:
            print(f"❌ Error running migration: {e}\n")
            conn.rollback()
            continue
    
    # Close connection
    cursor.close()
    conn.close()
    print("\n" + "="*60)
    print("All migrations completed!")
    print("="*60)

if __name__ == "__main__":
    run_migrations()

