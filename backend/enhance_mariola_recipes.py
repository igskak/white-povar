#!/usr/bin/env python3
"""
Enhance Max Mariola recipes with better descriptions and complete ingredients
"""

import asyncio
import sys
import os

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaEnhancer:
    def __init__(self):
        self.chef_id = "a06dccc2-0e3d-45ee-9d16-cb348898dd7a"
        
    def get_enhanced_recipes(self):
        """Return enhanced recipe data with better descriptions and complete ingredients"""
        return {
            "Rice Pasta with Chicken and Vegetables": {
                "description": "Chef Max Mariola's signature fusion masterpiece! This vibrant rice pasta dish brings together the best of Italian tradition with exotic Asian flavors. Tender marinated chicken mingles with crispy vegetables in a symphony of colors and textures. The secret? A perfect balance of soy sauce, fresh ginger, and aromatic herbs that will transport your taste buds on a culinary journey. Light yet satisfying, this is comfort food reimagined for the modern palate.",
                "ingredients": [
                    {"name": "Rice pasta", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Chicken breast", "amount": 400, "unit": "g", "notes": "", "order": 1},
                    {"name": "Eggplant", "amount": 1, "unit": "medium", "notes": "", "order": 2},
                    {"name": "Zucchini", "amount": 2, "unit": "medium", "notes": "", "order": 3},
                    {"name": "Bell peppers", "amount": 2, "unit": "pieces", "notes": "mixed colors", "order": 4},
                    {"name": "Cherry tomatoes", "amount": 200, "unit": "g", "notes": "", "order": 5},
                    {"name": "Fresh ginger", "amount": 20, "unit": "g", "notes": "", "order": 6},
                    {"name": "Garlic", "amount": 3, "unit": "cloves", "notes": "", "order": 7},
                    {"name": "Spring onion", "amount": 2, "unit": "pieces", "notes": "", "order": 8},
                    {"name": "Soy sauce", "amount": 3, "unit": "tablespoons", "notes": "", "order": 9},
                    {"name": "Lemon juice", "amount": 2, "unit": "tablespoons", "notes": "", "order": 10},
                    {"name": "Hot chili pepper", "amount": 1, "unit": "small", "notes": "", "order": 11},
                    {"name": "Extra virgin olive oil", "amount": 60, "unit": "ml", "notes": "", "order": 12},
                    {"name": "Baking soda", "amount": 1, "unit": "teaspoon", "notes": "for cleaning vegetables", "order": 13},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 14},
                    {"name": "Black pepper", "amount": 1, "unit": "to taste", "notes": "", "order": 15}
                ]
            },
            
            "Cheese Pasta": {
                "description": "Indulge in the ultimate cheese lover's dream! This decadent pasta showcases six premium Italian cheeses - Piave, Casera, Gruyère, Caciocavallo Silano, Emmental, and Grana Padano - melted into a velvety béchamel that coats every strand of pasta. Crispy guanciale adds a smoky, savory crunch that perfectly balances the rich creaminess. Finished with golden panko and baked to perfection, this is comfort food elevated to an art form.",
                "ingredients": [
                    {"name": "Ditalini rigati pasta", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Piave cheese", "amount": 50, "unit": "g", "notes": "", "order": 1},
                    {"name": "Casera cheese", "amount": 50, "unit": "g", "notes": "", "order": 2},
                    {"name": "Gruyère cheese", "amount": 50, "unit": "g", "notes": "", "order": 3},
                    {"name": "Caciocavallo Silano", "amount": 50, "unit": "g", "notes": "", "order": 4},
                    {"name": "Emmental cheese", "amount": 50, "unit": "g", "notes": "", "order": 5},
                    {"name": "Grana Padano", "amount": 80, "unit": "g", "notes": "", "order": 6},
                    {"name": "Guanciale", "amount": 150, "unit": "g", "notes": "", "order": 7},
                    {"name": "Whole milk", "amount": 500, "unit": "ml", "notes": "", "order": 8},
                    {"name": "Butter", "amount": 50, "unit": "g", "notes": "", "order": 9},
                    {"name": "All-purpose flour", "amount": 50, "unit": "g", "notes": "", "order": 10},
                    {"name": "Fresh basil", "amount": 10, "unit": "leaves", "notes": "", "order": 11},
                    {"name": "Panko breadcrumbs", "amount": 30, "unit": "g", "notes": "", "order": 12},
                    {"name": "Black pepper", "amount": 1, "unit": "to taste", "notes": "freshly ground", "order": 13},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 14}
                ]
            },
            
            "Homemade Cheeseburger": {
                "description": "Forget fast food forever! Chef Max Mariola's gourmet cheeseburger is a masterclass in homemade perfection. Every element is crafted from scratch - from the aromatic homemade ketchup infused with ginger and warm spices, to the perfectly seasoned beef patties enhanced with crispy pancetta. Tangy pickled cucumbers and melted fontina cheese create layers of flavor that will make you wonder why you ever settled for anything less.",
                "ingredients": [
                    {"name": "Hamburger buns", "amount": 4, "unit": "pieces", "notes": "", "order": 0},
                    {"name": "Ground beef", "amount": 600, "unit": "g", "notes": "", "order": 1},
                    {"name": "Pancetta", "amount": 100, "unit": "g", "notes": "", "order": 2},
                    {"name": "Fontina cheese", "amount": 120, "unit": "g", "notes": "", "order": 3},
                    {"name": "Cucumbers", "amount": 2, "unit": "medium", "notes": "", "order": 4},
                    {"name": "Dijon mustard", "amount": 2, "unit": "tablespoons", "notes": "", "order": 5},
                    {"name": "Fresh spring onion", "amount": 1, "unit": "piece", "notes": "", "order": 6},
                    {"name": "Tomato paste", "amount": 2, "unit": "tablespoons", "notes": "", "order": 7},
                    {"name": "Tomato puree", "amount": 200, "unit": "ml", "notes": "", "order": 8},
                    {"name": "Potato starch", "amount": 1, "unit": "tablespoon", "notes": "", "order": 9},
                    {"name": "Brown sugar", "amount": 1, "unit": "tablespoon", "notes": "", "order": 10},
                    {"name": "Apple cider vinegar", "amount": 2, "unit": "tablespoons", "notes": "", "order": 11},
                    {"name": "Sweet paprika", "amount": 1, "unit": "teaspoon", "notes": "", "order": 12},
                    {"name": "Fresh ginger", "amount": 10, "unit": "g", "notes": "", "order": 13},
                    {"name": "Ground cinnamon", "amount": 1, "unit": "pinch", "notes": "", "order": 14},
                    {"name": "Garlic", "amount": 2, "unit": "cloves", "notes": "", "order": 15},
                    {"name": "Nutmeg", "amount": 1, "unit": "pinch", "notes": "", "order": 16},
                    {"name": "Extra virgin olive oil", "amount": 50, "unit": "ml", "notes": "", "order": 17},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 18}
                ]
            },
            
            "Four Cheese and Lemon Pasta": {
                "description": "Elegance meets comfort in this sophisticated pasta creation. Four premium cheeses - Grana Padano, Gorgonzola, Asiago, and Gruyère - melt into a silky sauce brightened by the fresh zing of lemon zest. Toasted mixed seeds add a delightful crunch, while fresh sage leaves infuse the dish with aromatic earthiness. This is refined Italian cooking at its finest - simple ingredients transformed into something truly extraordinary.",
                "ingredients": [
                    {"name": "Mafalde pasta", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Grana Padano", "amount": 80, "unit": "g", "notes": "", "order": 1},
                    {"name": "Gorgonzola cheese", "amount": 80, "unit": "g", "notes": "", "order": 2},
                    {"name": "Asiago cheese", "amount": 80, "unit": "g", "notes": "", "order": 3},
                    {"name": "Gruyère cheese", "amount": 80, "unit": "g", "notes": "", "order": 4},
                    {"name": "Heavy cream", "amount": 200, "unit": "ml", "notes": "", "order": 5},
                    {"name": "Whole milk", "amount": 100, "unit": "ml", "notes": "", "order": 6},
                    {"name": "Fresh lemon", "amount": 1, "unit": "large", "notes": "zest only", "order": 7},
                    {"name": "Fresh sage", "amount": 6, "unit": "leaves", "notes": "", "order": 8},
                    {"name": "Mixed seeds", "amount": 30, "unit": "g", "notes": "pumpkin, sesame, sunflower", "order": 9},
                    {"name": "Black pepper", "amount": 1, "unit": "to taste", "notes": "freshly ground", "order": 10},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 11}
                ]
            },
            
            "Sandwich with Potato and Sausage Frittata": {
                "description": "This isn't just a sandwich - it's a celebration of Italian comfort food! A golden, fluffy frittata packed with crispy potatoes, savory sausage, and melted cheese becomes the star of this hearty creation. Fresh basil and a touch of spicy 'nduja elevate every bite, while ripe tomatoes add a burst of freshness. Perfect for breakfast, lunch, or whenever you need serious comfort food satisfaction.",
                "ingredients": [
                    {"name": "Rustic bread", "amount": 8, "unit": "thick slices", "notes": "", "order": 0},
                    {"name": "Potatoes", "amount": 400, "unit": "g", "notes": "", "order": 1},
                    {"name": "Italian sausage", "amount": 200, "unit": "g", "notes": "", "order": 2},
                    {"name": "Red onion", "amount": 1, "unit": "medium", "notes": "", "order": 3},
                    {"name": "Large eggs", "amount": 5, "unit": "pieces", "notes": "", "order": 4},
                    {"name": "Soft cheese", "amount": 150, "unit": "g", "notes": "mozzarella or similar", "order": 5},
                    {"name": "Ripe tomatoes", "amount": 2, "unit": "medium", "notes": "", "order": 6},
                    {"name": "Fresh basil", "amount": 10, "unit": "leaves", "notes": "", "order": 7},
                    {"name": "'Nduja", "amount": 30, "unit": "g", "notes": "optional", "order": 8},
                    {"name": "Extra virgin olive oil", "amount": 60, "unit": "ml", "notes": "", "order": 9},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 10},
                    {"name": "Black pepper", "amount": 1, "unit": "to taste", "notes": "", "order": 11}
                ]
            },

            "Bread Soup with Vegetables and Bottarga": {
                "description": "Discover the soul of Pugliese cuisine with this rustic pancotto! This traditional bread soup transforms humble stale bread into a comforting masterpiece. Seasonal vegetables meld with aromatic garlic and golden olive oil, while the crowning touch of grated bottarga adds an elegant briny depth that elevates this peasant dish to gourmet status. It's summer comfort food that tells the story of Italian resourcefulness and flavor.",
                "ingredients": [
                    {"name": "Stale bread", "amount": 300, "unit": "g", "notes": "preferably day-old", "order": 0},
                    {"name": "Seasonal vegetables", "amount": 500, "unit": "g", "notes": "zucchini, tomatoes, peppers", "order": 1},
                    {"name": "Garlic", "amount": 3, "unit": "cloves", "notes": "", "order": 2},
                    {"name": "Extra virgin olive oil", "amount": 80, "unit": "ml", "notes": "", "order": 3},
                    {"name": "Vegetable broth", "amount": 500, "unit": "ml", "notes": "", "order": 4},
                    {"name": "Bottarga", "amount": 30, "unit": "g", "notes": "grated", "order": 5},
                    {"name": "Fresh basil", "amount": 8, "unit": "leaves", "notes": "", "order": 6},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 7},
                    {"name": "Black pepper", "amount": 1, "unit": "to taste", "notes": "", "order": 8}
                ]
            },

            "Summer Pasta and Beans": {
                "description": "Experience the magic of Italian summer cooking! This beloved pasta e fagioli gets a seasonal makeover with the freshest ingredients and Chef Max's signature touch. Creamy cannellini beans swim in a vibrant tomato sauce enriched with aromatic herbs, while mixed pasta shapes create delightful textural variety. Finished with generous Pecorino Romano, this dish proves that simple ingredients, when treated with love and respect, create extraordinary flavors.",
                "ingredients": [
                    {"name": "Mixed pasta", "amount": 320, "unit": "g", "notes": "ditalini, tubetti mix", "order": 0},
                    {"name": "Cannellini beans", "amount": 400, "unit": "g", "notes": "cooked or canned", "order": 1},
                    {"name": "Pear tomatoes", "amount": 400, "unit": "g", "notes": "canned", "order": 2},
                    {"name": "Garlic", "amount": 3, "unit": "cloves", "notes": "", "order": 3},
                    {"name": "Extra virgin olive oil", "amount": 60, "unit": "ml", "notes": "", "order": 4},
                    {"name": "Pecorino Romano", "amount": 80, "unit": "g", "notes": "grated", "order": 5},
                    {"name": "Fresh basil", "amount": 10, "unit": "leaves", "notes": "", "order": 6},
                    {"name": "Vegetable broth", "amount": 300, "unit": "ml", "notes": "", "order": 7},
                    {"name": "Salt", "amount": 1, "unit": "to taste", "notes": "", "order": 8},
                    {"name": "Black pepper", "amount": 1, "unit": "to taste", "notes": "", "order": 9}
                ]
            }
        }

    async def get_max_mariola_recipes(self):
        """Get all Max Mariola recipes from database"""
        try:
            result = await supabase_service.get_recipes()
            max_recipes = [r for r in result.data if r.get('chef_id') == self.chef_id and r['title'] != '403 - Forbidden']
            return max_recipes
        except Exception as e:
            print(f"✗ Error getting recipes: {e}")
            return []

    async def get_recipe_ingredients(self, recipe_id: str):
        """Get ingredients for a specific recipe"""
        try:
            def _execute():
                client = supabase_service.get_client(use_service_key=True)
                result = client.table('ingredients').select('*').eq('recipe_id', recipe_id).execute()
                return result

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(None, _execute)
            return result.data if result.data else []
        except Exception as e:
            print(f"✗ Error getting ingredients: {e}")
            return []

    async def update_recipe(self, recipe_id: str, updates: dict) -> bool:
        """Update a recipe with new data"""
        try:
            # Separate ingredients from other updates
            ingredients = updates.pop('ingredients', None)

            def _execute():
                client = supabase_service.get_client(use_service_key=True)

                # Update recipe description
                if updates:
                    result = client.table('recipes').update(updates).eq('id', recipe_id).execute()
                    if not result.data:
                        print(f"✗ Failed to update recipe data")
                        return False

                # Update ingredients if provided
                if ingredients:
                    # First, delete existing ingredients
                    client.table('ingredients').delete().eq('recipe_id', recipe_id).execute()

                    # Then insert new ingredients
                    ingredients_data = []
                    for ingredient in ingredients:
                        ingredient_data = {
                            'recipe_id': recipe_id,
                            'name': ingredient['name'],
                            'amount': ingredient['amount'],
                            'unit': ingredient['unit'],
                            'notes': ingredient.get('notes', ''),
                            'order': ingredient['order']
                        }
                        ingredients_data.append(ingredient_data)

                    if ingredients_data:
                        result = client.table('ingredients').insert(ingredients_data).execute()
                        if not result.data:
                            print(f"✗ Failed to insert ingredients")
                            return False

                return True

            loop = asyncio.get_event_loop()
            return await loop.run_in_executor(None, _execute)

        except Exception as e:
            print(f"✗ Error updating recipe: {e}")
            return False

    async def run(self):
        """Main execution method"""
        try:
            print("=== Enhancing Max Mariola Recipes ===\n")
            
            # Get all Max Mariola recipes
            recipes = await self.get_max_mariola_recipes()
            print(f"Found {len(recipes)} Max Mariola recipes to enhance\n")
            
            # Get enhanced data
            enhanced_data = self.get_enhanced_recipes()
            
            updated_count = 0
            skipped_count = 0
            
            for recipe in recipes:
                title = recipe['title']
                recipe_id = recipe['id']

                if title in enhanced_data:
                    enhancement = enhanced_data[title]

                    # Check existing ingredients
                    existing_ingredients = await self.get_recipe_ingredients(recipe_id)

                    # Prepare updates
                    updates = {
                        'description': enhancement['description'],
                        'ingredients': enhancement['ingredients']
                    }

                    print(f"Enhancing: {title}")
                    print(f"  Current description length: {len(recipe.get('description', ''))} chars")
                    print(f"  New description length: {len(enhancement['description'])} chars")
                    print(f"  Current ingredients count: {len(existing_ingredients)}")
                    print(f"  New ingredients count: {len(enhancement['ingredients'])}")

                    if await self.update_recipe(recipe_id, updates):
                        updated_count += 1
                        print(f"  ✓ Enhanced successfully")
                    else:
                        print(f"  ✗ Failed to enhance")
                else:
                    print(f"⚠ No enhancement found for: {title}")
                    skipped_count += 1

                print()
            
            print(f"=== Enhancement Complete ===")
            print(f"✓ Enhanced: {updated_count} recipes")
            print(f"⚠ Skipped: {skipped_count} recipes")
            print(f"📊 Total processed: {len(recipes)} recipes")
            
        except Exception as e:
            print(f"✗ Error in main execution: {e}")
            raise

if __name__ == "__main__":
    enhancer = MaxMariolaEnhancer()
    asyncio.run(enhancer.run())
