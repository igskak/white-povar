#!/usr/bin/env python3
"""
Fix and normalize existing ingredient data
"""

import asyncio
import sys
import re

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

def parse_ingredient_text(ingredient_text):
    """Parse ingredient text to extract amount, unit, and name"""
    if not ingredient_text:
        return None, None, ingredient_text
    
    # Common patterns for ingredients
    patterns = [
        # "200g pasta" or "200 g pasta"
        r'^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)\s+(.+)$',
        # "2 cups flour"
        r'^(\d+(?:\.\d+)?)\s+(cups?|cup|tsp|tbsp|tablespoons?|teaspoons?|pieces?|pc|pcs)\s+(.+)$',
        # "1/2 cup sugar"
        r'^(\d+/\d+)\s+(cups?|cup|tsp|tbsp|tablespoons?|teaspoons?)\s+(.+)$',
        # "a pinch of salt"
        r'^(a pinch of|pinch of|some|a bit of)\s+(.+)$',
        # "salt to taste"
        r'^(.+)\s+(to taste|as needed)$',
    ]
    
    ingredient_text = ingredient_text.strip()
    
    for pattern in patterns:
        match = re.match(pattern, ingredient_text, re.IGNORECASE)
        if match:
            groups = match.groups()
            if len(groups) == 3:
                amount_str, unit, name = groups
                try:
                    # Handle fractions
                    if '/' in amount_str:
                        parts = amount_str.split('/')
                        amount = float(parts[0]) / float(parts[1])
                    else:
                        amount = float(amount_str)
                    return amount, unit.lower(), name.strip()
                except ValueError:
                    pass
            elif len(groups) == 2:
                # For patterns like "a pinch of salt"
                return None, groups[0], groups[1].strip()
    
    # If no pattern matches, return the whole text as ingredient name
    return None, None, ingredient_text

async def fix_ingredients():
    """Fix ingredient data for all recipes"""
    try:
        # Get all Max Mariola recipes
        result = await supabase_service.execute_query('recipes', 'select', 
            filters={'chef_id': 'a06dccc2-0e3d-45ee-9d16-cb348898dd7a'}
        )
        
        print(f"Found {len(result.data)} recipes to process")
        
        fixed_count = 0
        for recipe in result.data:
            recipe_id = recipe['id']
            title = recipe['title']

            # Skip problematic recipes
            if '403' in title or 'Forbidden' in title or not title.strip():
                print(f"Skipping problematic recipe: {title}")
                continue
            
            # Get current ingredients
            ingredients_result = await supabase_service.execute_query('ingredients', 'select',
                filters={'recipe_id': recipe_id}
            )
            
            if not ingredients_result.data:
                print(f"No ingredients found for: {title}")
                continue
            
            print(f"Processing: {title} ({len(ingredients_result.data)} ingredients)")
            
            # Process each ingredient
            updated_ingredients = []
            for ingredient in ingredients_result.data:
                original_text = ingredient.get('name', '')
                amount, unit, name = parse_ingredient_text(original_text)
                
                # Update ingredient with parsed data
                updated_ingredient = {
                    'id': ingredient['id'],
                    'name': name or original_text,
                    'amount': amount if amount is not None else 0.0,  # Default to 0 if no amount
                    'unit': unit or '',  # Default to empty string if no unit
                    'original_text': original_text
                }

                # Update in database
                update_data = {
                    'name': updated_ingredient['name'],
                    'unit': updated_ingredient['unit']
                }

                # Only update amount if we have a valid value
                if amount is not None:
                    update_data['amount'] = amount

                await supabase_service.execute_query('ingredients', 'update',
                    data=update_data,
                    filters={'id': ingredient['id']},
                    use_service_key=True
                )
                
                updated_ingredients.append(updated_ingredient)
            
            print(f"  ✓ Updated {len(updated_ingredients)} ingredients")
            fixed_count += 1
        
        print(f"✓ Fixed ingredients for {fixed_count} recipes")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(fix_ingredients())
