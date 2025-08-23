#!/usr/bin/env python3
"""
Add second batch of Max Mariola recipes to the database
"""

import asyncio
import sys
import os
import uuid

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaRecipeBatch2:
    def __init__(self):
        self.chef_id = "a06dccc2-0e3d-45ee-9d16-cb348898dd7a"
        
    async def get_chef_id(self) -> str:
        """Get Max Mariola chef ID"""
        try:
            result = await supabase_service.execute_query('chefs', 'select')
            for chef in result.data:
                if 'max' in chef['name'].lower() and 'mariola' in chef['name'].lower():
                    print(f"✓ Found Max Mariola chef: {chef['id']}")
                    return chef['id']
            
            print("✗ Max Mariola chef not found")
            return None
            
        except Exception as e:
            print(f"✗ Error getting chef: {e}")
            return None

    def get_recipes_data(self):
        """Return batch 2 of Max Mariola recipes"""
        return [
            {
                "title": "Pasta al Formaggio",
                "description": "Una pasta al formaggio goduriosa con sei formaggi diversi e guanciale croccante. Un primo piatto cremoso e saporito che sa di tradizione italiana!",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 3,
                "prep_time_minutes": 20,
                "cook_time_minutes": 25,
                "servings": 4,
                "instructions": [
                    "Preparate una besciamella con burro, farina e latte intero.",
                    "Grattugiate i formaggi Piave, Casera, Groviera, Caciocavallo Silano ed Emmental in una ciotola e incorporateli nella besciamella.",
                    "Tagliate il guanciale a pezzetti e fatelo rosolare in padella fino a renderlo croccante.",
                    "Cuocete la pasta al dente in acqua salata con qualche foglia di basilico.",
                    "Scolate la pasta e unitela in una ciotola con il guanciale, la salsa ai formaggi, pepe nero e altro basilico.",
                    "Trasferite il composto in pirottini individuali.",
                    "Completate con panko, Grana Padano e burro e infornate fino a doratura."
                ],
                "ingredients": [
                    {"name": "Ditalini rigati", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Piave", "amount": 50, "unit": "g", "notes": "", "order": 1},
                    {"name": "Casera", "amount": 50, "unit": "g", "notes": "", "order": 2},
                    {"name": "Groviera", "amount": 50, "unit": "g", "notes": "", "order": 3},
                    {"name": "Caciocavallo Silano", "amount": 50, "unit": "g", "notes": "", "order": 4},
                    {"name": "Emmental", "amount": 50, "unit": "g", "notes": "", "order": 5},
                    {"name": "Grana Padano", "amount": 80, "unit": "g", "notes": "", "order": 6},
                    {"name": "Basilico fresco", "amount": 10, "unit": "foglie", "notes": "", "order": 7},
                    {"name": "Guanciale", "amount": 150, "unit": "g", "notes": "", "order": 8},
                    {"name": "Latte intero", "amount": 500, "unit": "ml", "notes": "", "order": 9},
                    {"name": "Burro", "amount": 50, "unit": "g", "notes": "", "order": 10},
                    {"name": "Farina", "amount": 50, "unit": "g", "notes": "", "order": 11},
                    {"name": "Panko", "amount": 30, "unit": "g", "notes": "", "order": 12}
                ],
                "images": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "formaggi", "guanciale"]
            },
            {
                "title": "Cheeseburger Fatto in Casa",
                "description": "Il cheeseburger perfetto fatto in casa con ketchup artigianale, cetrioli marinati e fontina fusa. Un panino godereccio che batte qualsiasi fast food!",
                "category": "Panini",
                "cuisine": "Americana",
                "difficulty": 4,
                "prep_time_minutes": 45,
                "cook_time_minutes": 20,
                "servings": 4,
                "instructions": [
                    "Per il ketchup: tagliate il cipollotto a rondelle e fatelo rosolare con olio. Aggiungete zenzero e aglio grattugiati, cannella, paprika dolce, concentrato di pomodoro, noce moscata e passata di pomodoro.",
                    "In una ciotolina mescolate amido di patate, zucchero e aceto di mele. Aggiungete al pomodoro, salate e frullate tutto.",
                    "Tagliate i cetrioli a fette sottili con un pelapatate e conditeli con zucchero di canna, aceto, sale e zenzero.",
                    "Tritate la pancetta e unitela alla carne macinata. Lavorate bene con le mani e formate hamburger da 150g.",
                    "Cuocete gli hamburger in padella antiaderente con olio. Quando li girate, aggiungete la fontina a fette e coprite per farla fondere.",
                    "Scaldate i panini nella stessa padella, dal lato della mollica.",
                    "Assemblate il cheeseburger: cetrioli, senape, ketchup fatto in casa, hamburger con fontina e chiudete."
                ],
                "ingredients": [
                    {"name": "Panini per hamburger", "amount": 4, "unit": "pezzi", "notes": "", "order": 0},
                    {"name": "Carne macinata di manzo", "amount": 600, "unit": "g", "notes": "", "order": 1},
                    {"name": "Pancetta", "amount": 100, "unit": "g", "notes": "", "order": 2},
                    {"name": "Cetrioli", "amount": 2, "unit": "pezzi", "notes": "", "order": 3},
                    {"name": "Fontina", "amount": 120, "unit": "g", "notes": "", "order": 4},
                    {"name": "Senape", "amount": 2, "unit": "cucchiai", "notes": "", "order": 5},
                    {"name": "Cipollotto fresco", "amount": 1, "unit": "pezzo", "notes": "", "order": 6},
                    {"name": "Concentrato di pomodoro", "amount": 2, "unit": "cucchiai", "notes": "", "order": 7},
                    {"name": "Passata di pomodoro", "amount": 200, "unit": "ml", "notes": "", "order": 8},
                    {"name": "Amido di patate", "amount": 1, "unit": "cucchiaio", "notes": "", "order": 9},
                    {"name": "Zucchero", "amount": 1, "unit": "cucchiaio", "notes": "", "order": 10},
                    {"name": "Aceto di mele", "amount": 2, "unit": "cucchiai", "notes": "", "order": 11},
                    {"name": "Paprika dolce", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 12},
                    {"name": "Zenzero fresco", "amount": 10, "unit": "g", "notes": "", "order": 13},
                    {"name": "Cannella in polvere", "amount": 1, "unit": "pizzico", "notes": "", "order": 14},
                    {"name": "Aglio", "amount": 1, "unit": "spicchio", "notes": "", "order": 15},
                    {"name": "Noce moscata", "amount": 1, "unit": "pizzico", "notes": "", "order": 16},
                    {"name": "Olio extravergine d'oliva", "amount": 50, "unit": "ml", "notes": "", "order": 17},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 18}
                ],
                "images": ["https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800"],
                "tags": ["max mariola", "americana", "panini", "hamburger", "fatto in casa"]
            },
            {
                "title": "Pasta ai 4 Formaggi e Limone",
                "description": "Un primo piatto classico ed elegante con quattro formaggi pregiati e il profumo fresco del limone. Cremoso, raffinato e irresistibile!",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 2,
                "prep_time_minutes": 15,
                "cook_time_minutes": 20,
                "servings": 4,
                "instructions": [
                    "Tostate i semi misti in padella per aggiungere croccantezza.",
                    "In una padella scaldate delicatamente latte e panna con la scorza di limone a fuoco basso. Non deve bollire.",
                    "Tagliate i formaggi a pezzetti e aggiungeteli al latte caldo con qualche foglia di salvia. Mescolate fino a ottenere una salsa liscia.",
                    "Cuocete le mafalde in acqua bollente salata e scolatele al dente.",
                    "Unite la pasta alla salsa ai formaggi e mantecate bene.",
                    "Servite guarnendo con i semi tostati, scorza di limone grattugiata e pepe nero."
                ],
                "ingredients": [
                    {"name": "Mafalde", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Grana Padano", "amount": 80, "unit": "g", "notes": "", "order": 1},
                    {"name": "Gorgonzola", "amount": 80, "unit": "g", "notes": "", "order": 2},
                    {"name": "Asiago", "amount": 80, "unit": "g", "notes": "", "order": 3},
                    {"name": "Gruyere", "amount": 80, "unit": "g", "notes": "", "order": 4},
                    {"name": "Panna fresca", "amount": 200, "unit": "ml", "notes": "", "order": 5},
                    {"name": "Latte", "amount": 100, "unit": "ml", "notes": "", "order": 6},
                    {"name": "Limone", "amount": 1, "unit": "pezzo", "notes": "scorza", "order": 7},
                    {"name": "Salvia", "amount": 6, "unit": "foglie", "notes": "", "order": 8},
                    {"name": "Semi misti", "amount": 30, "unit": "g", "notes": "", "order": 9},
                    {"name": "Pepe nero", "amount": 1, "unit": "q.b.", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11}
                ],
                "images": ["https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "formaggi", "limone"]
            }
        ]

    async def save_recipe(self, recipe_data: dict) -> bool:
        """Save recipe to database"""
        try:
            # Prepare recipe data for database
            db_recipe_data = {
                'id': str(uuid.uuid4()),
                'chef_id': self.chef_id,
                'title': recipe_data['title'],
                'description': recipe_data['description'],
                'cuisine': recipe_data['cuisine'],
                'category': recipe_data['category'],
                'difficulty': recipe_data['difficulty'],
                'prep_time_minutes': recipe_data['prep_time_minutes'],
                'cook_time_minutes': recipe_data['cook_time_minutes'],
                'servings': recipe_data['servings'],
                'instructions': recipe_data['instructions'],
                'images': recipe_data['images'],
                'tags': recipe_data['tags'],
                'is_featured': False,
                'ingredients': recipe_data['ingredients']
            }
            
            # Save to database
            result = await supabase_service.create_recipe(db_recipe_data)
            
            if result.data:
                recipe_id = result.data[0]['id']
                print(f"✓ Saved recipe: {recipe_data['title']} (ID: {recipe_id})")
                return True
            else:
                print(f"✗ Failed to save recipe: {recipe_data['title']}")
                return False
                
        except Exception as e:
            print(f"✗ Error saving recipe {recipe_data['title']}: {e}")
            return False

    async def run(self):
        """Main execution method"""
        try:
            print("=== Adding Max Mariola Recipes Batch 2 ===\n")
            
            # Get chef ID
            self.chef_id = await self.get_chef_id()
            if not self.chef_id:
                print("✗ Cannot proceed without chef ID")
                return
            
            # Get recipes data
            recipes = self.get_recipes_data()
            
            # Process each recipe
            successful = 0
            failed = 0
            
            for recipe_data in recipes:
                print(f"\nProcessing: {recipe_data['title']}")
                if await self.save_recipe(recipe_data):
                    successful += 1
                else:
                    failed += 1
            
            print(f"\n=== Batch 2 Addition Complete ===")
            print(f"✓ Successful: {successful}")
            print(f"✗ Failed: {failed}")
            print(f"📊 Total: {len(recipes)}")
            
        except Exception as e:
            print(f"✗ Error in main execution: {e}")
            raise

if __name__ == "__main__":
    adder = MaxMariolaRecipeBatch2()
    asyncio.run(adder.run())
