#!/usr/bin/env python3
"""
Clean up Max Mariola recipes - remove duplicates and add missing images
"""

import asyncio
import sys
import os

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaRecipeCleanup:
    def __init__(self):
        self.chef_id = "a06dccc2-0e3d-45ee-9d16-cb348898dd7a"
        
    async def get_mariola_recipes(self):
        """Get all Max Mariola recipes"""
        try:
            result = await supabase_service.get_recipes()
            max_recipes = [r for r in result.data if r.get('chef_id') == self.chef_id]
            return max_recipes
        except Exception as e:
            print(f"Error getting recipes: {e}")
            return []

    async def delete_recipe(self, recipe_id: str, title: str):
        """Delete a recipe by ID"""
        try:
            result = await supabase_service.execute_query('recipes', 'delete', {'id': recipe_id}, use_service_key=True)
            print(f"✓ Deleted duplicate: {title} (ID: {recipe_id})")
            return True
        except Exception as e:
            print(f"✗ Error deleting recipe {title}: {e}")
            return False

    async def update_recipe_images(self, recipe_id: str, title: str, images: list):
        """Update recipe with images"""
        try:
            update_data = {'images': images}
            result = await supabase_service.execute_query('recipes', 'update', update_data, {'id': recipe_id}, use_service_key=True)
            print(f"✓ Added images to: {title}")
            return True
        except Exception as e:
            print(f"✗ Error updating images for {title}: {e}")
            return False

    def get_recipe_images(self, title: str) -> list:
        """Get appropriate images for a recipe based on title"""
        image_mapping = {
            "pancotto con verdure e bottarga": ["https://images.unsplash.com/photo-1547592180-85f173990554?w=800"],
            "panino con verdure e alici": ["https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800"],
            "pasta con verdure e tonno": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
            "pasta e fagioli estiva": ["https://images.unsplash.com/photo-1551218808-94e220e084d2?w=800"],
            "tagliolini con tartare e peperoni croccanti": ["https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800"],
            "pasta di riso con pollo e verdure": ["https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800"],
            "bruschetta con vongole e pomodorini": ["https://images.unsplash.com/photo-1572441713132-51c75654db73?w=800"],
            "avocado toast con uova e pomodoro": ["https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=800"],
            "quinoa con verdure e feta": ["https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800"],
            "frittata dolce austriaca": ["https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800"]
        }
        
        title_lower = title.lower()
        for key, images in image_mapping.items():
            if key in title_lower:
                return images
        
        # Default image for Italian recipes
        return ["https://images.unsplash.com/photo-1551218808-94e220e084d2?w=800"]

    async def run(self):
        """Main cleanup method"""
        try:
            print("=== Max Mariola Recipe Cleanup ===\n")
            
            # Get all recipes
            recipes = await self.get_mariola_recipes()
            print(f"Found {len(recipes)} Max Mariola recipes")
            
            # Group recipes by title to find duplicates
            recipe_groups = {}
            for recipe in recipes:
                title = recipe['title'].lower().strip()
                if title not in recipe_groups:
                    recipe_groups[title] = []
                recipe_groups[title].append(recipe)
            
            # Handle duplicates and missing images
            deleted_count = 0
            updated_count = 0
            
            for title, recipe_list in recipe_groups.items():
                if title == "403 - forbidden":
                    # Delete the 403 error recipe
                    for recipe in recipe_list:
                        if await self.delete_recipe(recipe['id'], recipe['title']):
                            deleted_count += 1
                    continue
                
                if len(recipe_list) > 1:
                    # Handle duplicates - keep the most recent one with better data
                    print(f"\nFound {len(recipe_list)} duplicates for: {title}")
                    
                    # Sort by creation date and quality (more instructions = better)
                    recipe_list.sort(key=lambda x: (len(x.get('instructions', [])), x.get('created_at', '')), reverse=True)
                    
                    # Keep the best one
                    best_recipe = recipe_list[0]
                    print(f"  Keeping: {best_recipe['id']} (created: {best_recipe.get('created_at', 'unknown')})")
                    
                    # Delete the rest
                    for recipe in recipe_list[1:]:
                        if await self.delete_recipe(recipe['id'], recipe['title']):
                            deleted_count += 1
                    
                    # Update the kept recipe with images if missing
                    if not best_recipe.get('images') or len(best_recipe.get('images', [])) == 0:
                        images = self.get_recipe_images(best_recipe['title'])
                        if await self.update_recipe_images(best_recipe['id'], best_recipe['title'], images):
                            updated_count += 1
                else:
                    # Single recipe - just check for missing images
                    recipe = recipe_list[0]
                    if not recipe.get('images') or len(recipe.get('images', [])) == 0:
                        images = self.get_recipe_images(recipe['title'])
                        if await self.update_recipe_images(recipe['id'], recipe['title'], images):
                            updated_count += 1
            
            print(f"\n=== Cleanup Complete ===")
            print(f"✓ Deleted: {deleted_count} recipes")
            print(f"✓ Updated: {updated_count} recipes with images")
            
            # Final count
            final_recipes = await self.get_mariola_recipes()
            print(f"📊 Final count: {len(final_recipes)} Max Mariola recipes")
            
        except Exception as e:
            print(f"✗ Error in cleanup: {e}")
            raise

if __name__ == "__main__":
    cleanup = MaxMariolaRecipeCleanup()
    asyncio.run(cleanup.run())
