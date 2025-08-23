#!/usr/bin/env python3
"""
Add missing images to Max Mariola recipes
"""

import asyncio
import sys
import os

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class ImageAdder:
    def __init__(self):
        self.chef_id = "a06dccc2-0e3d-45ee-9d16-cb348898dd7a"
        
    async def update_recipe_images(self, recipe_id: str, title: str, images: list):
        """Update recipe with images"""
        try:
            # Use the supabase client directly for update
            from app.core.config import settings
            from supabase import create_client
            
            supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
            
            result = supabase.table('recipes').update({'images': images}).eq('id', recipe_id).execute()
            
            if result.data:
                print(f"✓ Added images to: {title}")
                return True
            else:
                print(f"✗ Failed to update images for {title}")
                return False
        except Exception as e:
            print(f"✗ Error updating images for {title}: {e}")
            return False

    def get_recipe_images(self, title: str) -> list:
        """Get appropriate images for a recipe based on title"""
        image_mapping = {
            "pancotto con verdure e bottarga": ["https://images.unsplash.com/photo-1547592180-85f173990554?w=800"],
            "pasta con verdure e tonno": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
            "pasta e fagioli estiva": ["https://images.unsplash.com/photo-1551218808-94e220e084d2?w=800"],
        }
        
        title_lower = title.lower()
        for key, images in image_mapping.items():
            if key in title_lower:
                return images
        
        # Default image for Italian recipes
        return ["https://images.unsplash.com/photo-1551218808-94e220e084d2?w=800"]

    async def run(self):
        """Main method"""
        try:
            print("=== Adding Missing Images to Max Mariola Recipes ===\n")
            
            # Specific recipes that need images
            recipes_to_update = [
                {
                    "id": "ec6b5301-592e-490e-8f57-a848121f3d05",
                    "title": "Pancotto con verdure e bottarga"
                },
                {
                    "id": "07803374-3eb7-48e3-9ac1-9e542c2102ad", 
                    "title": "Pasta con verdure e tonno"
                },
                {
                    "id": "f43c1648-e637-4628-a7f3-e891355f242b",
                    "title": "Pasta e fagioli estiva"
                }
            ]
            
            updated_count = 0
            
            for recipe in recipes_to_update:
                images = self.get_recipe_images(recipe['title'])
                if await self.update_recipe_images(recipe['id'], recipe['title'], images):
                    updated_count += 1
            
            print(f"\n=== Image Update Complete ===")
            print(f"✓ Updated: {updated_count} recipes with images")
            
        except Exception as e:
            print(f"✗ Error: {e}")
            raise

if __name__ == "__main__":
    adder = ImageAdder()
    asyncio.run(adder.run())
