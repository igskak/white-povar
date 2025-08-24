#!/usr/bin/env python3
"""
Create normalized tables manually
"""

import asyncio
import sys

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

async def create_tables():
    """Create normalized tables"""
    try:
        client = supabase_service.get_client(use_service_key=True)
        
        # Create units table
        print("Creating units table...")
        units_sql = """
        CREATE TABLE IF NOT EXISTS units (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name_en VARCHAR(50) NOT NULL UNIQUE,
            abbreviation_en VARCHAR(10) NOT NULL,
            unit_type VARCHAR(20) NOT NULL CHECK (unit_type IN ('mass', 'volume', 'count')),
            system VARCHAR(10) NOT NULL CHECK (system IN ('metric', 'imperial', 'us')),
            base_unit_id UUID REFERENCES units(id),
            conversion_factor DECIMAL(20,10),
            is_base_unit BOOLEAN DEFAULT FALSE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        # Create ingredient categories table
        print("Creating ingredient_categories table...")
        categories_sql = """
        CREATE TABLE IF NOT EXISTS ingredient_categories (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name_en VARCHAR(100) NOT NULL,
            description_en TEXT,
            sort_order INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        # Create base ingredients table
        print("Creating base_ingredients table...")
        base_ingredients_sql = """
        CREATE TABLE IF NOT EXISTS base_ingredients (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name_en VARCHAR(200) NOT NULL UNIQUE,
            category_id UUID REFERENCES ingredient_categories(id),
            density_g_per_ml DECIMAL(8,4),
            default_unit_id UUID REFERENCES units(id),
            aliases TEXT[],
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        # Execute table creation
        tables = [
            ("units", units_sql),
            ("ingredient_categories", categories_sql), 
            ("base_ingredients", base_ingredients_sql)
        ]
        
        for table_name, sql in tables:
            try:
                result = client.rpc('exec_sql', {'sql': sql}).execute()
                print(f"✓ Created {table_name} table")
            except Exception as e:
                print(f"✗ Error creating {table_name}: {e}")
        
        # Insert basic units
        print("Inserting basic units...")
        units_data = [
            {'name_en': 'gram', 'abbreviation_en': 'g', 'unit_type': 'mass', 'system': 'metric', 'is_base_unit': True},
            {'name_en': 'kilogram', 'abbreviation_en': 'kg', 'unit_type': 'mass', 'system': 'metric', 'is_base_unit': False},
            {'name_en': 'milliliter', 'abbreviation_en': 'ml', 'unit_type': 'volume', 'system': 'metric', 'is_base_unit': True},
            {'name_en': 'liter', 'abbreviation_en': 'l', 'unit_type': 'volume', 'system': 'metric', 'is_base_unit': False},
            {'name_en': 'piece', 'abbreviation_en': 'pc', 'unit_type': 'count', 'system': 'metric', 'is_base_unit': True},
            {'name_en': 'cup', 'abbreviation_en': 'cup', 'unit_type': 'volume', 'system': 'us', 'is_base_unit': False},
            {'name_en': 'teaspoon', 'abbreviation_en': 'tsp', 'unit_type': 'volume', 'system': 'us', 'is_base_unit': False},
            {'name_en': 'tablespoon', 'abbreviation_en': 'tbsp', 'unit_type': 'volume', 'system': 'us', 'is_base_unit': False},
        ]
        
        try:
            result = client.table('units').insert(units_data).execute()
            print(f"✓ Inserted {len(units_data)} units")
        except Exception as e:
            print(f"✗ Error inserting units: {e}")
        
        # Insert basic categories
        print("Inserting ingredient categories...")
        categories_data = [
            {'name_en': 'Vegetables', 'description_en': 'Fresh and preserved vegetables', 'sort_order': 1},
            {'name_en': 'Proteins', 'description_en': 'Meat, fish, poultry, and plant proteins', 'sort_order': 2},
            {'name_en': 'Dairy & Eggs', 'description_en': 'Milk products and eggs', 'sort_order': 3},
            {'name_en': 'Grains & Cereals', 'description_en': 'Rice, pasta, bread, and cereals', 'sort_order': 4},
            {'name_en': 'Herbs & Spices', 'description_en': 'Fresh and dried herbs and spices', 'sort_order': 5},
            {'name_en': 'Oils & Fats', 'description_en': 'Cooking oils, butter, and other fats', 'sort_order': 6},
            {'name_en': 'Other', 'description_en': 'Miscellaneous ingredients', 'sort_order': 99}
        ]
        
        try:
            result = client.table('ingredient_categories').insert(categories_data).execute()
            print(f"✓ Inserted {len(categories_data)} categories")
        except Exception as e:
            print(f"✗ Error inserting categories: {e}")
        
        print("✓ Normalized tables setup complete!")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(create_tables())
