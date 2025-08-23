#!/usr/bin/env python3
"""
Add Max Mariola appetizers and other dishes to the database
"""

import asyncio
import sys
import os
import uuid

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaAppetizerAdder:
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
        """Return appetizers and other dishes"""
        return [
            {
                "title": "Bruschetta con vongole e pomodorini",
                "description": "Una bruschetta goduriosa con vongole lupini e pomodorini datterini. Un antipasto di mare che sa di estate e tradizione napoletana!",
                "category": "Antipasti",
                "cuisine": "Italiana",
                "difficulty": 2,
                "prep_time_minutes": 15,
                "cook_time_minutes": 10,
                "servings": 4,
                "instructions": [
                    "Lavate bene le vongole per togliere l'acqua in eccesso.",
                    "Aprite le vongole in un wok con abbondante olio extravergine, uno spicchio d'aglio e i gambi del prezzemolo. Coprite e cuocete per qualche minuto, lasciandole belle succose.",
                    "Nel frattempo tagliate i pomodorini a pezzetti e conditeli con un filo d'olio e un po' d'aglio grattugiato. Aggiungete anche una goccia dell'acqua di cottura delle vongole e il prezzemolo tritato fresco.",
                    "Appena le vongole si aprono, mettetele in una ciotola e sgusciatele una ad una, poi irroratele con il liquido di cottura per mantenerle morbide.",
                    "Tagliate qualche fetta di pane cafone e tostatelo in padella calda con un po' d'olio buono.",
                    "Componete la bruschetta: mettete sui pezzi di pane i pomodorini conditi, aggiungete le vongole cotte, guarnite con prezzemolo e finite con una bella colata d'olio."
                ],
                "ingredients": [
                    {"name": "Pane cafone", "amount": 4, "unit": "fette", "notes": "", "order": 0},
                    {"name": "Vongole lupini", "amount": 500, "unit": "g", "notes": "", "order": 1},
                    {"name": "Prezzemolo fresco", "amount": 20, "unit": "g", "notes": "", "order": 2},
                    {"name": "Pomodorini datterini rossi", "amount": 200, "unit": "g", "notes": "", "order": 3},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 4},
                    {"name": "Aglio", "amount": 2, "unit": "spicchi", "notes": "", "order": 5},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 6}
                ],
                "images": ["https://images.unsplash.com/photo-1572441713132-51c75654db73?w=800"],
                "tags": ["max mariola", "cucina italiana", "antipasti", "vongole", "bruschetta", "mare"]
            },
            {
                "title": "Avocado Toast con uova e pomodoro",
                "description": "Un toast moderno e salutare con avocado, uova e pomodoro. Perfetto per una colazione nutriente o un brunch godereccio!",
                "category": "Colazioni",
                "cuisine": "Moderna",
                "difficulty": 2,
                "prep_time_minutes": 15,
                "cook_time_minutes": 10,
                "servings": 2,
                "instructions": [
                    "Tagliate il pane fatto in casa a fette, conditelo con un filo d'olio e tostatelo in padella calda.",
                    "Prendete un avocado leggermente maturo, tagliatelo a metà e ricavate la polpa con un cucchiaio. Affettatelo.",
                    "In una ciotolina mescolate il succo di mezzo limone con olio, paprika dolce, curcuma e zenzero. Aggiungete un pizzico di sale e mescolate bene.",
                    "In una padella calda con un filo d'olio, cuocete le uova in camicia con un pizzico di sale. Tenetele da parte ancora morbide.",
                    "In una padella tostate un mix di semi (zucca, sesamo, lino) fino a che iniziano a scoppiettare. Poi pestateli in un mortaio o in un sacchetto per liberare gli oli.",
                    "Su un piatto disponete due fette di pane tostato. Sopra mettete le fette di avocado e qualche fetta di pomodoro spesso. Condite con la salsina per dare sapore. Appoggiate le uova in camicia sopra. Guarnite con menta e basilico freschi e finite con una spolverata dei semi tostati."
                ],
                "ingredients": [
                    {"name": "Pane fatto in casa", "amount": 4, "unit": "fette", "notes": "", "order": 0},
                    {"name": "Avocado", "amount": 1, "unit": "pezzo", "notes": "", "order": 1},
                    {"name": "Pomodori", "amount": 2, "unit": "pezzi", "notes": "", "order": 2},
                    {"name": "Uova", "amount": 2, "unit": "pezzi", "notes": "", "order": 3},
                    {"name": "Paprika dolce", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 4},
                    {"name": "Curcuma", "amount": 1, "unit": "pizzico", "notes": "", "order": 5},
                    {"name": "Zenzero", "amount": 1, "unit": "pizzico", "notes": "", "order": 6},
                    {"name": "Semi misti", "amount": 30, "unit": "g", "notes": "zucca, sesamo, lino", "order": 7},
                    {"name": "Limone", "amount": 0.5, "unit": "pezzo", "notes": "", "order": 8},
                    {"name": "Basilico", "amount": 5, "unit": "foglie", "notes": "", "order": 9},
                    {"name": "Menta", "amount": 5, "unit": "foglie", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11},
                    {"name": "Olio extravergine d'oliva", "amount": 40, "unit": "ml", "notes": "", "order": 12}
                ],
                "images": ["https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=800"],
                "tags": ["max mariola", "moderna", "colazioni", "avocado", "healthy", "brunch"]
            },
            {
                "title": "Quinoa con verdure e feta",
                "description": "Un'insalata fresca estiva, perfetta da portare in ufficio o al mare. Un piatto completo e salutare con quinoa, feta greca e verdure di stagione.",
                "category": "Insalate",
                "cuisine": "Mediterranea",
                "difficulty": 2,
                "prep_time_minutes": 20,
                "cook_time_minutes": 15,
                "servings": 4,
                "instructions": [
                    "Cuocete la quinoa in acqua bollente per 10-15 minuti fino a cottura.",
                    "Mentre la quinoa cuoce, preparate le verdure. Tagliate zucchine e peperoni e fateli saltare in un wok con aglio e olio.",
                    "Aggiungete il basilico alle zucchine quando iniziano a dorarsi, poi i peperoni e la menta.",
                    "Tagliate i pomodorini a metà e teneteli da parte.",
                    "Una volta cotta, raffreddate la quinoa sotto l'acqua corrente.",
                    "Preparate un condimento emulsionando olio, succo di limone, origano, basilico e menta.",
                    "Condite la quinoa raffreddata con questo condimento.",
                    "Componete il piatto unendo quinoa condita, verdure saltate, pomodorini freschi e feta sbriciolata. Fate riposare in frigo prima di servire."
                ],
                "ingredients": [
                    {"name": "Quinoa", "amount": 200, "unit": "g", "notes": "", "order": 0},
                    {"name": "Feta greca", "amount": 150, "unit": "g", "notes": "", "order": 1},
                    {"name": "Zucchine trombetta", "amount": 2, "unit": "pezzi", "notes": "", "order": 2},
                    {"name": "Pomodorini", "amount": 200, "unit": "g", "notes": "", "order": 3},
                    {"name": "Peperoncino", "amount": 1, "unit": "pizzico", "notes": "", "order": 4},
                    {"name": "Cipolla rossa", "amount": 0.5, "unit": "pezzo", "notes": "", "order": 5},
                    {"name": "Basilico fresco", "amount": 10, "unit": "foglie", "notes": "", "order": 6},
                    {"name": "Menta", "amount": 10, "unit": "foglie", "notes": "", "order": 7},
                    {"name": "Origano", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 8},
                    {"name": "Limone", "amount": 1, "unit": "pezzo", "notes": "", "order": 9},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11}
                ],
                "images": ["https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800"],
                "tags": ["max mariola", "mediterranea", "insalate", "quinoa", "feta", "healthy"]
            },
            {
                "title": "Frittata dolce austriaca",
                "description": "Una frittata dolce della tradizione austriaca, perfetta per una colazione speciale o un dessert leggero. Servita con ricotta e frutta fresca di stagione.",
                "category": "Dolci",
                "cuisine": "Austriaca",
                "difficulty": 3,
                "prep_time_minutes": 15,
                "cook_time_minutes": 15,
                "servings": 4,
                "instructions": [
                    "Separate gli albumi dai tuorli in due ciotole diverse. Montate gli albumi con un pizzico di sale fino a renderli spumosi.",
                    "Con la stessa frusta, montate i tuorli con lo zucchero e aromatizzate con scorza di limone grattugiata o vaniglia. Aggiungete il latte continuando a mescolare bene.",
                    "Incorporate 100 grammi di farina setacciata e mescolate bene per evitare grumi.",
                    "Incorporate delicatamente gli albumi montati nel composto di tuorli, muovendovi dall'alto verso il basso per non far smontare il composto.",
                    "Sciogliete una noce di burro in una padella antiaderente e versate tutto il composto. Coprite e cuocete per 4-5 minuti. Quando si è formata una crosta, tagliatela in 4 parti e separatele.",
                    "Abbassate il fuoco e iniziate a sbriciolarla con una spatola di silicone.",
                    "Saltatela leggermente per cuocere il composto e farla dorare bene.",
                    "Una volta dorata, versatela su un piatto e servite con un cucchiaio di ricotta lavorata e frutta fresca di stagione tagliata.",
                    "Guarnite con menta fresca e una spolverata di zucchero a velo."
                ],
                "ingredients": [
                    {"name": "Farina 00", "amount": 100, "unit": "g", "notes": "", "order": 0},
                    {"name": "Zucchero", "amount": 15, "unit": "g", "notes": "", "order": 1},
                    {"name": "Ricotta fresca", "amount": 200, "unit": "g", "notes": "", "order": 2},
                    {"name": "Latte", "amount": 100, "unit": "ml", "notes": "q.b.", "order": 3},
                    {"name": "Uova", "amount": 3, "unit": "pezzi", "notes": "", "order": 4},
                    {"name": "Sale", "amount": 1, "unit": "pizzico", "notes": "", "order": 5},
                    {"name": "Burro", "amount": 30, "unit": "g", "notes": "", "order": 6},
                    {"name": "Menta", "amount": 5, "unit": "foglie", "notes": "", "order": 7},
                    {"name": "Limone", "amount": 1, "unit": "pezzo", "notes": "scorza", "order": 8},
                    {"name": "Frutta di stagione", "amount": 200, "unit": "g", "notes": "", "order": 9}
                ],
                "images": ["https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800"],
                "tags": ["max mariola", "austriaca", "dolci", "frittata", "colazione", "dessert"]
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
            print("=== Adding Max Mariola Appetizers & Other Dishes ===\n")
            
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
    adder = MaxMariolaAppetizerAdder()
    asyncio.run(adder.run())
