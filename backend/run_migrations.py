#!/usr/bin/env python3
"""
Script to run database migrations using Supabase client.
"""
import os
import sys
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_supabase_client() -> Client:
    """Create and return a Supabase client."""
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY")  # Use service key for admin operations
    
    if not url or not key:
        print("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env file")
        sys.exit(1)
    
    return create_client(url, key)

def run_migration(client: Client, migration_file: Path):
    """Run a single migration file."""
    print(f"\n{'='*60}")
    print(f"Running migration: {migration_file.name}")
    print(f"{'='*60}\n")
    
    # Read the migration file
    with open(migration_file, 'r') as f:
        sql = f.read()
    
    # Execute the SQL
    try:
        # Note: Supabase Python client doesn't have a direct SQL execution method
        # We need to use the REST API or PostgREST
        # For now, we'll print instructions
        print("SQL to execute:")
        print("-" * 60)
        print(sql)
        print("-" * 60)
        print("\nPlease run this SQL in your Supabase SQL Editor:")
        print(f"1. Go to https://supabase.com/dashboard/project/YOUR_PROJECT/sql")
        print(f"2. Copy and paste the SQL above")
        print(f"3. Click 'Run'")
        print("\nAlternatively, use psql:")
        print(f"psql $DATABASE_URL -f {migration_file}")
        
    except Exception as e:
        print(f"Error running migration: {e}")
        sys.exit(1)

def main():
    """Main function to run all migrations."""
    # Get migrations directory
    migrations_dir = Path(__file__).parent / "migrations"
    
    if not migrations_dir.exists():
        print(f"Error: Migrations directory not found: {migrations_dir}")
        sys.exit(1)
    
    # Get all SQL files in migrations directory
    migration_files = sorted(migrations_dir.glob("*.sql"))
    
    if not migration_files:
        print("No migration files found")
        return
    
    print(f"Found {len(migration_files)} migration file(s)")
    
    # Create Supabase client
    client = get_supabase_client()
    
    # Run each migration
    for migration_file in migration_files:
        run_migration(client, migration_file)
        print()

if __name__ == "__main__":
    main()

