#!/usr/bin/env python3
"""
Add Max Mariola sandwich and main course recipes to the database
"""

import asyncio
import sys
import os
import uuid

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaSandwiches:
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
        """Return sandwich and main course recipes"""
        return [
            {
                "title": "Panino con Frittata di Patate e Salsiccia",
                "description": "Un panino sostanzioso e godereccio con frittata di patate, salsiccia e formaggio. Perfetto per una merenda o un pranzo veloce ma saporito!",
                "category": "Panini",
                "cuisine": "Italiana",
                "difficulty": 3,
                "prep_time_minutes": 20,
                "cook_time_minutes": 25,
                "servings": 4,
                "instructions": [
                    "Pelate le patate e tagliatele a cubetti. Friggetele in padella antiaderente con olio.",
                    "Tagliate la cipolla rossa a rondelle e aggiungetela alle patate con la salsiccia sbriciolata.",
                    "Tagliate il formaggio a fette, poi a dadini e tenetelo da parte.",
                    "In una ciotola sbattete 4-5 uova e versateci le patate con salsiccia e i pezzetti di formaggio.",
                    "Cuocete la frittata in padella antiaderente calda con olio, muovendola leggermente. Aggiungete basilico spezzettato e pezzetti di 'nduja se gradite.",
                    "Coprite con un piatto, girate la frittata e fatela scivolare in padella per cuocerla uniformemente.",
                    "Tagliate il pane a fette e tostatelo con olio in padella fino a doratura.",
                    "Tagliate il pomodoro a fette, mettetelo sul pane, aggiungete un pezzo di frittata e chiudete con l'altra fetta."
                ],
                "ingredients": [
                    {"name": "Pane", "amount": 8, "unit": "fette", "notes": "", "order": 0},
                    {"name": "Patate", "amount": 400, "unit": "g", "notes": "", "order": 1},
                    {"name": "Cipolla rossa", "amount": 1, "unit": "pezzo", "notes": "", "order": 2},
                    {"name": "Salsiccia", "amount": 200, "unit": "g", "notes": "", "order": 3},
                    {"name": "Uova", "amount": 5, "unit": "pezzi", "notes": "", "order": 4},
                    {"name": "Formaggio morbido", "amount": 150, "unit": "g", "notes": "", "order": 5},
                    {"name": "Pomodoro", "amount": 2, "unit": "pezzi", "notes": "", "order": 6},
                    {"name": "Basilico", "amount": 10, "unit": "foglie", "notes": "", "order": 7},
                    {"name": "'Nduja", "amount": 30, "unit": "g", "notes": "opzionale", "order": 8},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 9},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 10}
                ],
                "images": ["https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800"],
                "tags": ["max mariola", "cucina italiana", "panini", "frittata", "salsiccia"]
            },
            {
                "title": "Spiedini di Manzo",
                "description": "Spiedini di carne macinata speziati con curry e zenzero, serviti con broccoli saltati e salsa cremosa. Un secondo piatto fusion dal sapore esotico!",
                "category": "Secondi Piatti",
                "cuisine": "Fusion",
                "difficulty": 3,
                "prep_time_minutes": 30,
                "cook_time_minutes": 25,
                "servings": 4,
                "instructions": [
                    "Mettete la carne macinata in una ciotola con aglio grattugiato, scorza di lime, prezzemolo tritato e peperoncino battuto.",
                    "Impastate bene con le mani. Se la carne è secca, aggiungete un uovo.",
                    "Prendete il cipollotto verde e avvolgete la carne intorno, compattando bene. Fate lo stesso con la citronella se gradite.",
                    "Pulite i broccoli tagliando le cimette e bolliteli in acqua salata. Pulite anche il gambo e tagliatelo a pezzetti.",
                    "Tritate la cipolla rossa per la salsa. In un tegame mettete burro chiarificato con cipollotto e pezzetti di mela.",
                    "Aggiungete il curry e sfumate con acqua di cottura dei broccoli. Aggiungete la panna e frullate. Aggiustate di sale.",
                    "Cuocete gli spiedini in padella antiaderente con burro chiarificato fino a doratura.",
                    "Saltate i broccoli nella stessa padella con salsa di soia.",
                    "Impiattate con 4-5 spiedini, salsa e broccoli saltati."
                ],
                "ingredients": [
                    {"name": "Carne macinata di manzo", "amount": 500, "unit": "g", "notes": "", "order": 0},
                    {"name": "Broccoli", "amount": 400, "unit": "g", "notes": "", "order": 1},
                    {"name": "Cipolla rossa", "amount": 1, "unit": "pezzo", "notes": "", "order": 2},
                    {"name": "Citronella", "amount": 2, "unit": "steli", "notes": "opzionale", "order": 3},
                    {"name": "Cipollotto verde", "amount": 2, "unit": "pezzi", "notes": "", "order": 4},
                    {"name": "Peperoncino", "amount": 1, "unit": "pezzo", "notes": "", "order": 5},
                    {"name": "Prezzemolo", "amount": 20, "unit": "g", "notes": "", "order": 6},
                    {"name": "Paprika", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 7},
                    {"name": "Zenzero", "amount": 10, "unit": "g", "notes": "", "order": 8},
                    {"name": "Lime", "amount": 1, "unit": "pezzo", "notes": "", "order": 9},
                    {"name": "Mela", "amount": 1, "unit": "pezzo", "notes": "", "order": 10},
                    {"name": "Curry in polvere", "amount": 1, "unit": "cucchiaio", "notes": "", "order": 11},
                    {"name": "Panna liquida", "amount": 200, "unit": "ml", "notes": "", "order": 12},
                    {"name": "Uova", "amount": 1, "unit": "pezzo", "notes": "se necessario", "order": 13},
                    {"name": "Aglio", "amount": 1, "unit": "spicchio", "notes": "", "order": 14},
                    {"name": "Burro chiarificato", "amount": 50, "unit": "g", "notes": "", "order": 15},
                    {"name": "Salsa di soia", "amount": 2, "unit": "cucchiai", "notes": "", "order": 16},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 17}
                ],
                "images": ["https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=800"],
                "tags": ["max mariola", "fusion", "secondi piatti", "spiedini", "curry"]
            },
            {
                "title": "Tramezzino con Uova, Salame e Carciofi",
                "description": "Un tramezzino gourmet con uova sode, salame e crema di carciofi. Elegante e saporito, perfetto per un aperitivo o pranzo veloce!",
                "category": "Antipasti",
                "cuisine": "Italiana",
                "difficulty": 2,
                "prep_time_minutes": 25,
                "cook_time_minutes": 15,
                "servings": 4,
                "instructions": [
                    "Bollite le uova in acqua fredda con aceto per 8 minuti. Poi mettetele in acqua fredda.",
                    "Pulite i carciofi togliendo le foglie esterne, tagliate la punta e il gambo. Tagliateli a metà, togliete la barba e metteteli in acqua con limone.",
                    "Grattugiate aglio in padella con olio e cuocete i carciofi a spicchi. Salate, pepate, aggiungete acqua e cuocete a fuoco alto con coperchio.",
                    "Sgusciate le uova battendole leggermente per creare crepe e togliete il guscio. Tagliatele a fette sottili.",
                    "Frullate i carciofi cotti per fare la crema.",
                    "Tagliate il salame a fette sottili.",
                    "Prendete il pane per tramezzini e spalmate la crema di carciofi, aggiungete pecorino grattugiato e fette di salame.",
                    "Aggiungete le uova sode, altro salame e chiudete con l'altra metà del tramezzino.",
                    "Tagliate i bordi con coltello liscio e dividete orizzontalmente."
                ],
                "ingredients": [
                    {"name": "Pane per tramezzini", "amount": 8, "unit": "fette", "notes": "", "order": 0},
                    {"name": "Salame", "amount": 150, "unit": "g", "notes": "", "order": 1},
                    {"name": "Carciofi", "amount": 4, "unit": "pezzi", "notes": "", "order": 2},
                    {"name": "Uova", "amount": 4, "unit": "pezzi", "notes": "", "order": 3},
                    {"name": "Pecorino", "amount": 50, "unit": "g", "notes": "", "order": 4},
                    {"name": "Aglio", "amount": 1, "unit": "spicchio", "notes": "", "order": 5},
                    {"name": "Olio extravergine d'oliva", "amount": 50, "unit": "ml", "notes": "", "order": 6},
                    {"name": "Basilico", "amount": 6, "unit": "foglie", "notes": "", "order": 7},
                    {"name": "Limone", "amount": 1, "unit": "pezzo", "notes": "", "order": 8},
                    {"name": "Aceto", "amount": 1, "unit": "cucchiaio", "notes": "", "order": 9},
                    {"name": "Pepe", "amount": 1, "unit": "q.b.", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11}
                ],
                "images": ["https://images.unsplash.com/photo-1572441713132-51c75654db73?w=800"],
                "tags": ["max mariola", "cucina italiana", "antipasti", "tramezzino", "carciofi"]
            },
            {
                "title": "Panino con Pulled Pork",
                "description": "Un panino americano con maiale sfilacciato, cavolo stufato, cetrioli marinati e uovo in camicia. Un'esplosione di sapori e consistenze!",
                "category": "Panini",
                "cuisine": "Americana",
                "difficulty": 4,
                "prep_time_minutes": 30,
                "cook_time_minutes": 90,
                "servings": 4,
                "instructions": [
                    "Tagliate il lonza di maiale a pezzi grandi e conditela generosamente con paprika dolce.",
                    "In padella antiaderente sciogliete burro chiarificato e rosolate la carne su tutti i lati. Aggiungete zenzero grattugiato.",
                    "Affettate le cipolle e aggiungetele alla carne, mescolando bene.",
                    "Salate, aggiungete acqua e cuocete a fuoco basso con coperchio per circa un'ora e mezza.",
                    "Affettate sottilmente i cetrioli con pelapatate. Conditeli con aceto bianco, sale, zucchero e coriandolo macinato.",
                    "Affettate il cavolo verza e saltatelo in padella con olio e aglio. Salate, aggiungete peperoncino e funghi a spicchi.",
                    "Tostate il panino in padella con burro. Nella stessa padella cuocete un uovo in camicia.",
                    "Affettate il formaggio e fatelo fondere nella stessa padella.",
                    "Assemblate: cavolo stufato, pulled pork sfilacciato, cetrioli, formaggio fuso, uovo in camicia e pepe."
                ],
                "ingredients": [
                    {"name": "Panino rotondo", "amount": 4, "unit": "pezzi", "notes": "", "order": 0},
                    {"name": "Lonza di maiale", "amount": 800, "unit": "g", "notes": "", "order": 1},
                    {"name": "Formaggio", "amount": 120, "unit": "g", "notes": "", "order": 2},
                    {"name": "Zenzero", "amount": 15, "unit": "g", "notes": "", "order": 3},
                    {"name": "Cetrioli", "amount": 2, "unit": "pezzi", "notes": "", "order": 4},
                    {"name": "Uova", "amount": 4, "unit": "pezzi", "notes": "", "order": 5},
                    {"name": "Cavolo verza", "amount": 300, "unit": "g", "notes": "", "order": 6},
                    {"name": "Burro chiarificato", "amount": 50, "unit": "g", "notes": "", "order": 7},
                    {"name": "Paprika dolce", "amount": 2, "unit": "cucchiai", "notes": "", "order": 8},
                    {"name": "Funghi", "amount": 150, "unit": "g", "notes": "", "order": 9},
                    {"name": "Aceto bianco", "amount": 3, "unit": "cucchiai", "notes": "", "order": 10},
                    {"name": "Cipolle", "amount": 2, "unit": "pezzi", "notes": "", "order": 11},
                    {"name": "Aglio", "amount": 2, "unit": "spicchi", "notes": "", "order": 12},
                    {"name": "Zucchero", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 13},
                    {"name": "Coriandolo macinato", "amount": 1, "unit": "pizzico", "notes": "", "order": 14},
                    {"name": "Olio extravergine d'oliva", "amount": 40, "unit": "ml", "notes": "", "order": 15},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 16},
                    {"name": "Pepe", "amount": 1, "unit": "q.b.", "notes": "", "order": 17}
                ],
                "images": ["https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=800"],
                "tags": ["max mariola", "americana", "panini", "pulled pork", "maiale"]
            },
            {
                "title": "Panino Zingara",
                "description": "Il panino zingara di Max Mariola con pane fatto in casa, maionese artigianale, prosciutto crudo e mozzarella fior di latte. Un classico rivisitato!",
                "category": "Panini",
                "cuisine": "Italiana",
                "difficulty": 2,
                "prep_time_minutes": 15,
                "cook_time_minutes": 10,
                "servings": 2,
                "instructions": [
                    "Immergete due fette di pane in olio condito con aglio e tostatele su piastra calda fino a doratura e leggera bruciatura.",
                    "Spalmate generosa maionese fatta in casa su una fetta di pane tostato.",
                    "Aggiungete qualche foglia di insalata lavata e fette di pomodoro Marinda. Salate.",
                    "Aggiungete fette di mozzarella fior di latte ben sgocciolata.",
                    "Aggiungete foglie di basilico fresco e le fette di mozzarella, poi fatele fondere su teglia in forno. Riscaldate anche l'altra fetta.",
                    "Aggiungete fette di prosciutto crudo (Max usa Zuarina) e chiudete il panino con l'altra fetta, anch'essa spalmata di maionese.",
                    "Premete il panino con le mani, tagliatelo a metà e servite con kimchi o insalatina e patate fritte doppie."
                ],
                "ingredients": [
                    {"name": "Pane fatto in casa", "amount": 4, "unit": "fette", "notes": "", "order": 0},
                    {"name": "Maionese", "amount": 4, "unit": "cucchiai", "notes": "preferibilmente fatta in casa", "order": 1},
                    {"name": "Prosciutto crudo", "amount": 100, "unit": "g", "notes": "", "order": 2},
                    {"name": "Pomodori Marinda", "amount": 2, "unit": "pezzi", "notes": "", "order": 3},
                    {"name": "Insalata verde", "amount": 50, "unit": "g", "notes": "", "order": 4},
                    {"name": "Mozzarella fior di latte", "amount": 150, "unit": "g", "notes": "", "order": 5},
                    {"name": "Basilico fresco", "amount": 8, "unit": "foglie", "notes": "", "order": 6},
                    {"name": "Olio extravergine d'oliva", "amount": 30, "unit": "ml", "notes": "", "order": 7},
                    {"name": "Aglio", "amount": 1, "unit": "spicchio", "notes": "", "order": 8},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 9},
                    {"name": "Pepe", "amount": 1, "unit": "q.b.", "notes": "", "order": 10}
                ],
                "images": ["https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800"],
                "tags": ["max mariola", "cucina italiana", "panini", "prosciutto", "mozzarella"]
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
            print("=== Adding Max Mariola Sandwich & Main Course Recipes ===\n")
            
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
            
            print(f"\n=== Sandwich & Main Course Addition Complete ===")
            print(f"✓ Successful: {successful}")
            print(f"✗ Failed: {failed}")
            print(f"📊 Total: {len(recipes)}")
            
        except Exception as e:
            print(f"✗ Error in main execution: {e}")
            raise

if __name__ == "__main__":
    adder = MaxMariolaSandwiches()
    asyncio.run(adder.run())
