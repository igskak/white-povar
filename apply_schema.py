#!/usr/bin/env python3
"""
Apply ingestion schema to Supabase database
"""

import sys
import os
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent / "backend"))

from supabase import create_client, Client
from app.core.settings import settings

def apply_schema():
    """Apply the ingestion schema to the database"""
    print("🗄️  Applying ingestion schema to Supabase database...")
    
    try:
        # Create Supabase client with service key for admin operations
        supabase: Client = create_client(settings.supabase_url, settings.supabase_service_key)
        
        # Read the schema file
        schema_file = Path("apply_ingestion_schema.sql")
        if not schema_file.exists():
            print("❌ Schema file not found: apply_ingestion_schema.sql")
            return False
        
        schema_sql = schema_file.read_text()
        
        # Split into individual statements
        statements = [stmt.strip() for stmt in schema_sql.split(';') if stmt.strip()]
        
        print(f"📝 Executing {len(statements)} SQL statements...")
        
        for i, statement in enumerate(statements, 1):
            if not statement:
                continue
                
            try:
                # Execute each statement
                result = supabase.rpc('exec_sql', {'sql': statement}).execute()
                print(f"✅ Statement {i}/{len(statements)} executed successfully")
                
            except Exception as e:
                # Some statements might fail if tables already exist, that's okay
                if "already exists" in str(e).lower() or "does not exist" in str(e).lower():
                    print(f"⚠️  Statement {i}/{len(statements)}: {str(e)}")
                else:
                    print(f"❌ Statement {i}/{len(statements)} failed: {str(e)}")
                    # Continue with other statements
        
        print("✅ Schema application completed!")
        return True
        
    except Exception as e:
        print(f"❌ Failed to apply schema: {str(e)}")
        print("\n📝 Manual steps required:")
        print("1. Go to your Supabase dashboard")
        print("2. Navigate to SQL Editor")
        print("3. Copy and paste the contents of 'apply_ingestion_schema.sql'")
        print("4. Execute the SQL commands")
        return False

def test_schema():
    """Test if the schema was applied correctly"""
    print("\n🧪 Testing schema application...")
    
    try:
        supabase: Client = create_client(settings.supabase_url, settings.supabase_service_key)
        
        # Test if tables exist by trying to select from them
        tables_to_test = ['ingestion_jobs', 'recipe_fingerprints', 'ingestion_reviews']
        
        for table in tables_to_test:
            try:
                result = supabase.table(table).select('*').limit(1).execute()
                print(f"✅ Table '{table}' exists and is accessible")
            except Exception as e:
                print(f"❌ Table '{table}' test failed: {str(e)}")
                return False
        
        print("✅ All ingestion tables are ready!")
        return True
        
    except Exception as e:
        print(f"❌ Schema test failed: {str(e)}")
        return False

if __name__ == "__main__":
    print("🚀 Supabase Ingestion Schema Setup")
    print("=" * 40)
    
    # Apply schema
    schema_success = apply_schema()
    
    if schema_success:
        # Test schema
        test_success = test_schema()
        
        if test_success:
            print("\n🎉 Database schema is ready!")
            print("You can now start the application.")
        else:
            print("\n⚠️  Schema applied but tests failed.")
            print("Please check your Supabase dashboard to verify the tables exist.")
    else:
        print("\n❌ Schema application failed.")
        print("Please apply the schema manually using the Supabase dashboard.")
    
    sys.exit(0 if schema_success else 1)
