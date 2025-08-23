#!/usr/bin/env python3
"""
Verify that the recipe enhancements are working correctly
"""

import asyncio
import sys

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

async def verify_enhancements():
    """Verify the enhanced recipes"""
    try:
        print("=== VERIFYING RECIPE ENHANCEMENTS ===\n")
        
        # Get all recipes
        result = await supabase_service.get_recipes()
        max_mariola_chef_id = 'a06dccc2-0e3d-45ee-9d16-cb348898dd7a'
        max_recipes = [r for r in result.data if r.get('chef_id') == max_mariola_chef_id and r['title'] != '403 - Forbidden']
        
        print(f"Found {len(max_recipes)} Max Mariola recipes\n")
        
        # Check specific enhanced recipes
        enhanced_recipes = [
            "Rice Pasta with Chicken and Vegetables",
            "Cheese Pasta", 
            "Bread Soup with Vegetables and Bottarga",
            "Summer Pasta and Beans",
            "Four Cheese and Lemon Pasta"
        ]
        
        for recipe_title in enhanced_recipes:
            recipe = next((r for r in max_recipes if r['title'] == recipe_title), None)
            if recipe:
                print(f"✅ {recipe_title}")
                print(f"   Description length: {len(recipe['description'])} chars")
                print(f"   Description preview: {recipe['description'][:100]}...")
                
                # Get ingredients for this recipe
                def _get_ingredients():
                    client = supabase_service.get_client(use_service_key=True)
                    result = client.table('ingredients').select('*').eq('recipe_id', recipe['id']).execute()
                    return result.data if result.data else []
                
                loop = asyncio.get_event_loop()
                ingredients = await loop.run_in_executor(None, _get_ingredients)
                
                print(f"   Ingredients count: {len(ingredients)}")
                if ingredients:
                    print(f"   Sample ingredients:")
                    for i, ingredient in enumerate(ingredients[:3]):
                        print(f"     {i+1}. {ingredient['name']} - {ingredient['amount']} {ingredient['unit']}")
                    if len(ingredients) > 3:
                        print(f"     ... and {len(ingredients) - 3} more")
                print()
            else:
                print(f"❌ {recipe_title} - NOT FOUND")
                print()
        
        # Check if any recipes still have short descriptions
        short_descriptions = [r for r in max_recipes if len(r.get('description', '')) < 200]
        if short_descriptions:
            print(f"⚠️  Recipes with short descriptions ({len(short_descriptions)}):")
            for recipe in short_descriptions:
                print(f"   - {recipe['title']} ({len(recipe.get('description', ''))} chars)")
        else:
            print(f"✅ All recipes have enhanced descriptions!")
        
        print(f"\n=== SUMMARY ===")
        print(f"Total Max Mariola recipes: {len(max_recipes)}")
        print(f"Enhanced recipes verified: {len([r for r in max_recipes if r['title'] in enhanced_recipes])}")
        print(f"Average description length: {sum(len(r.get('description', '')) for r in max_recipes) // len(max_recipes)} chars")
        
        # Check ingredients coverage
        total_with_ingredients = 0
        for recipe in max_recipes:
            def _get_ingredients():
                client = supabase_service.get_client(use_service_key=True)
                result = client.table('ingredients').select('*').eq('recipe_id', recipe['id']).execute()
                return result.data if result.data else []
            
            ingredients = await loop.run_in_executor(None, _get_ingredients)
            if ingredients:
                total_with_ingredients += 1
        
        print(f"Recipes with ingredients: {total_with_ingredients}/{len(max_recipes)}")
        print(f"Ingredients coverage: {(total_with_ingredients/len(max_recipes)*100):.1f}%")
        
        print(f"\n🎉 Enhancement verification complete!")
        print(f"📱 Frontend is running at: http://localhost:3000")
        print(f"🔧 Backend is running at: http://localhost:8000")
        
    except Exception as e:
        print(f"❌ Error during verification: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(verify_enhancements())
