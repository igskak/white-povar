#!/usr/bin/env python3
"""
Run database migrations
"""

import asyncio
import sys
import os

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

async def run_migration_sql(file_path: str):
    """Run SQL migration file"""
    try:
        with open(file_path, 'r') as f:
            sql_content = f.read()
        
        # Split by semicolons and execute each statement
        statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
        
        print(f"Running migration: {file_path}")
        print(f"Found {len(statements)} SQL statements")
        
        for i, statement in enumerate(statements):
            if statement.strip():
                try:
                    # Use the service client for admin operations
                    client = supabase_service.get_client(use_service_key=True)
                    result = client.rpc('exec_sql', {'sql': statement}).execute()
                    print(f"  ✓ Statement {i+1} executed successfully")
                except Exception as e:
                    print(f"  ✗ Statement {i+1} failed: {e}")
                    # Continue with other statements
        
        print(f"Migration {file_path} completed")
        
    except Exception as e:
        print(f"Error running migration {file_path}: {e}")

async def main():
    """Run all migrations"""
    migrations = [
        'migrations/001_add_normalized_tables.sql',
        'migrations/002_migrate_existing_ingredients.sql'
    ]
    
    for migration in migrations:
        if os.path.exists(migration):
            await run_migration_sql(migration)
        else:
            print(f"Migration file not found: {migration}")

if __name__ == "__main__":
    asyncio.run(main())
