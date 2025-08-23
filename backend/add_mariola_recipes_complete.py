#!/usr/bin/env python3
"""
Add complete Max Mariola recipes to the database with proper formatting and images
"""

import asyncio
import sys
import os
import uuid

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaRecipeAdder:
    def __init__(self):
        self.chef_id = None
        
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
        """Return all Max Mariola recipes with complete data"""
        return [
            {
                "title": "Pancotto con verdure e bottarga",
                "description": "Una bella zappetta con verdure di stagione e bottarga da gustare in estate. Un piatto della tradizione pugliese rivisitato con ingredienti freschi e di qualità.",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 3,
                "prep_time_minutes": 20,
                "cook_time_minutes": 30,
                "servings": 4,
                "instructions": [
                    "Tagliate il pane raffermo a pezzi e tostatelo in padella con olio e aglio. Condite con origano e paprika dolce.",
                    "Pelate e tagliate a dadini una patata e cuocetela in un wok con olio caldo.",
                    "Aggiungete una cipolla affettata al wok e cuocete con un po' d'acqua calda fino a che non si sfaldi.",
                    "Pulite un peperone rosso, togliete semi e picciolo, e tagliatelo a listarelle. Aggiungetelo al wok con acqua calda, sale e peperoncino.",
                    "Tagliate una zucchina, togliendo la polpa in eccesso, e alcuni pomodorini rossi e gialli. Aggiungeteli in padella e cuocete per circa 10 minuti.",
                    "Una volta pronta la zuppa, impiattate una porzione, aggiungete il pane croccante, la rucola e una bella grattugiata di bottarga."
                ],
                "ingredients": [
                    {"name": "Pane raffermo", "amount": 200, "unit": "g", "notes": "", "order": 0},
                    {"name": "Patate", "amount": 300, "unit": "g", "notes": "", "order": 1},
                    {"name": "Peperone rosso", "amount": 1, "unit": "pezzo", "notes": "", "order": 2},
                    {"name": "Zucchine", "amount": 1, "unit": "pezzo", "notes": "", "order": 3},
                    {"name": "Rucola", "amount": 50, "unit": "g", "notes": "", "order": 4},
                    {"name": "Bottarga", "amount": 50, "unit": "g", "notes": "", "order": 5},
                    {"name": "Origano", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 6},
                    {"name": "Paprika dolce", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 7},
                    {"name": "Cipolla", "amount": 1, "unit": "pezzo", "notes": "", "order": 8},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 9},
                    {"name": "Aglio", "amount": 2, "unit": "spicchi", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11}
                ],
                "images": ["https://images.unsplash.com/photo-1547592180-85f173990554?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "pugliese", "bottarga"]
            },
            {
                "title": "Pasta con verdure e tonno",
                "description": "Una pasta pazzesca con il tonno e le verdure di stagione perfetta per l'estate! Un piatto completo e saporito che unisce mare e terra.",
                "category": "Primi Piatti", 
                "cuisine": "Italiana",
                "difficulty": 2,
                "prep_time_minutes": 15,
                "cook_time_minutes": 25,
                "servings": 4,
                "instructions": [
                    "Pelate e tagliate a dadini una patata, poi cuocetela in acqua bollente salata insieme alla pasta.",
                    "Tagliate una zucchina trombetta a rondelle.",
                    "Affettate una cipollina fresca e fatela soffriggere in un wok con olio.",
                    "Aggiungete la zucchina, sale e peperoncino in polvere al wok e cuocete.",
                    "Tagliate a metà i pomodorini rossi e gialli e aggiungeteli al wok.",
                    "Aggiungete il tonno sott'olio e le olive al wok, mescolate e spegnete il fuoco.",
                    "Circa 3 minuti prima che la pasta sia pronta, aggiungete i fagiolini puliti nell'acqua della pasta.",
                    "Scolate pasta, patate e fagiolini e aggiungeteli al wok con il condimento.",
                    "Aggiungete qualche foglia di basilico fresco e mantecate tutto insieme."
                ],
                "ingredients": [
                    {"name": "Spaghettoni", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Zucchina trombetta", "amount": 1, "unit": "pezzo", "notes": "", "order": 1},
                    {"name": "Pomodorini rossi e gialli", "amount": 200, "unit": "g", "notes": "", "order": 2},
                    {"name": "Tonno sott'olio", "amount": 200, "unit": "g", "notes": "", "order": 3},
                    {"name": "Cipollina fresca", "amount": 1, "unit": "pezzo", "notes": "", "order": 4},
                    {"name": "Fagiolini", "amount": 150, "unit": "g", "notes": "", "order": 5},
                    {"name": "Patate", "amount": 200, "unit": "g", "notes": "", "order": 6},
                    {"name": "Basilico fresco", "amount": 10, "unit": "foglie", "notes": "", "order": 7},
                    {"name": "Peperoncino", "amount": 1, "unit": "pizzico", "notes": "", "order": 8},
                    {"name": "Olive", "amount": 50, "unit": "g", "notes": "", "order": 9},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 10},
                    {"name": "Olio extravergine d'oliva", "amount": 50, "unit": "ml", "notes": "", "order": 11}
                ],
                "images": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "tonno", "verdure"]
            },
            {
                "title": "Pasta e fagioli estiva",
                "description": "Prova la ricetta perfetta della pasta e fagioli estiva realizzata con ingredienti di qualità e tanto amore per mangiare legumi anche d'estate.",
                "category": "Primi Piatti",
                "cuisine": "Italiana", 
                "difficulty": 3,
                "prep_time_minutes": 20,
                "cook_time_minutes": 40,
                "servings": 4,
                "instructions": [
                    "Se usate fagioli secchi, metteteli in ammollo una notte intera e poi cuoceteli per circa 2 ore fino a che siano teneri.",
                    "In una wok mettete dell'olio con l'aglio e fate rosolare bene. Poi aggiungete i pomodori a pera, schiacciateli con una forchetta e fate cuocere per qualche minuto.",
                    "Aggiungete i fagioli già cotti al sugo di pomodoro e fate insaporire bene.",
                    "Nel frattempo fate cuocere la pasta mista in acqua bollente salata.",
                    "Scolate la pasta e versatela nella wok con i fagioli. Aggiungete abbondante pecorino e mantecate tutto insieme."
                ],
                "ingredients": [
                    {"name": "Pasta mista artigianale", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Fagioli", "amount": 400, "unit": "g", "notes": "secchi o precotti", "order": 1},
                    {"name": "Pomodori a pera", "amount": 300, "unit": "g", "notes": "", "order": 2},
                    {"name": "Pecorino grattugiato", "amount": 100, "unit": "g", "notes": "", "order": 3},
                    {"name": "Basilico fresco", "amount": 10, "unit": "foglie", "notes": "", "order": 4},
                    {"name": "Aglio fresco", "amount": 3, "unit": "spicchi", "notes": "", "order": 5},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 6},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 7}
                ],
                "images": ["https://images.unsplash.com/photo-1551218808-94e220e084d2?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "fagioli", "tradizionale"]
            },
            {
                "title": "Tagliolini con tartare e peperoni croccanti",
                "description": "Un primo piatto godereccio, con ciccia bona e peperoni croccanti da leccarsi i baffi! Una ricetta gourmet che unisce la delicatezza dei tagliolini con la sapidità della tartare.",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 4,
                "prep_time_minutes": 30,
                "cook_time_minutes": 20,
                "servings": 4,
                "instructions": [
                    "Preparate la tartare di carne fresca tagliandola finemente a coltello e conditela con olio, sale, pepe e erbe aromatiche.",
                    "Tagliate i peperoni a listarelle e friggeteli in olio caldo fino a renderli croccanti.",
                    "Preparate una crema zabaione salata montando tuorli d'uovo con vino bianco a bagnomaria.",
                    "Cuocete i tagliolini in abbondante acqua salata fino a cottura al dente.",
                    "Mantecate la pasta con la crema zabaione e impiattate.",
                    "Completate con la tartare di carne e i peperoni croccanti."
                ],
                "ingredients": [
                    {"name": "Tagliolini freschi", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Carne di manzo per tartare", "amount": 200, "unit": "g", "notes": "", "order": 1},
                    {"name": "Peperoni", "amount": 2, "unit": "pezzi", "notes": "", "order": 2},
                    {"name": "Tuorli d'uovo", "amount": 3, "unit": "pezzi", "notes": "", "order": 3},
                    {"name": "Vino bianco", "amount": 50, "unit": "ml", "notes": "", "order": 4},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 5},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 6},
                    {"name": "Pepe nero", "amount": 1, "unit": "q.b.", "notes": "", "order": 7}
                ],
                "images": ["https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "tartare", "gourmet"]
            },
            {
                "title": "Pasta di riso con pollo e verdure",
                "description": "Una ricetta completa e leggera, perfetta per mangiare bene e con gusto a pranzo o a cena. Un piatto fusion che unisce la tradizione italiana con sapori orientali.",
                "category": "Primi Piatti",
                "cuisine": "Fusion",
                "difficulty": 3,
                "prep_time_minutes": 25,
                "cook_time_minutes": 20,
                "servings": 4,
                "instructions": [
                    "Lavate bene tutte le verdure. Potete usare un po' di bicarbonato per una pulizia extra.",
                    "Tagliate le melanzane a fette e poi a cubetti. Salatele per far uscire l'acqua amara.",
                    "Affettate le zucchine e i peperoni a cubetti dopo aver tolto semi e picciolo.",
                    "Pelate un pezzo di zenzero e uno spicchio d'aglio. Affettate finemente un cipollotto.",
                    "Tagliate il petto di pollo a strisce e marinatelo con salsa di soia e succo di limone.",
                    "Scaldate l'olio in un wok con cipollotto e zenzero grattugiato a fuoco basso.",
                    "Aggiungete zucchine e melanzane al wok, poi il pollo marinato.",
                    "Quando il pollo è ben cotto, aggiungete i peperoni che devono rimanere croccanti.",
                    "Tagliate i pomodorini a metà e un peperoncino piccante a pezzetti.",
                    "Cuocete la pasta di riso in acqua bollente salata, scolatela e aggiungetela al wok.",
                    "Unite pomodorini e peperoncino, mantecate tutto insieme e servite."
                ],
                "ingredients": [
                    {"name": "Pasta di riso", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Petto di pollo", "amount": 300, "unit": "g", "notes": "", "order": 1},
                    {"name": "Peperoni", "amount": 2, "unit": "pezzi", "notes": "", "order": 2},
                    {"name": "Melanzane", "amount": 1, "unit": "pezzo", "notes": "", "order": 3},
                    {"name": "Zucchine", "amount": 1, "unit": "pezzo", "notes": "", "order": 4},
                    {"name": "Zenzero fresco", "amount": 20, "unit": "g", "notes": "", "order": 5},
                    {"name": "Salsa di soia", "amount": 30, "unit": "ml", "notes": "", "order": 6},
                    {"name": "Cipollotto", "amount": 1, "unit": "pezzo", "notes": "", "order": 7},
                    {"name": "Limone", "amount": 1, "unit": "pezzo", "notes": "", "order": 8},
                    {"name": "Aglio", "amount": 1, "unit": "spicchio", "notes": "", "order": 9},
                    {"name": "Olio extravergine d'oliva", "amount": 50, "unit": "ml", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11}
                ],
                "images": ["https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800"],
                "tags": ["max mariola", "fusion", "primi piatti", "pollo", "verdure", "leggero"]
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
            print("=== Adding Complete Max Mariola Recipes ===\n")
            
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
            
            print(f"\n=== Recipe Addition Complete ===")
            print(f"✓ Successful: {successful}")
            print(f"✗ Failed: {failed}")
            print(f"📊 Total: {len(recipes)}")
            
        except Exception as e:
            print(f"✗ Error in main execution: {e}")
            raise

if __name__ == "__main__":
    adder = MaxMariolaRecipeAdder()
    asyncio.run(adder.run())
