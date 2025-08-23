#!/usr/bin/env python3
"""
Add Max Mariola pasta dishes and specialty recipes to the database
"""

import asyncio
import sys
import os
import uuid

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaPastaSpecialties:
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
        """Return pasta dishes and specialty recipes"""
        return [
            {
                "title": "Spaghetti con Broccoli e Baccalà",
                "description": "Un primo piatto della tradizione del Sud Italia con baccalà, broccoli e pomodorini del Piennolo. Saporito e genuino!",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 3,
                "prep_time_minutes": 20,
                "cook_time_minutes": 25,
                "servings": 4,
                "instructions": [
                    "Pulite i broccoli togliendo foglie e parti dure. Tagliate a cimette.",
                    "Cuocete gli spaghetti in acqua bollente salata. Nella stessa acqua cuocete i broccoli scoperti.",
                    "In un wok fate soffriggere aglio grattugiato in olio. Aggiungete cipollotto affettato e pomodorini del Piennolo tagliati a metà.",
                    "Tagliate la parte centrale di un filetto di baccalà a pezzi e aggiungetelo al wok con le verdure saltate.",
                    "Quando la pasta è cotta, trasferitela nel wok con i broccoli. Aggiungete un mestolo di acqua di cottura, peperoncino fresco tritato e zenzero grattugiato.",
                    "Mantecate tutto insieme e servite subito."
                ],
                "ingredients": [
                    {"name": "Spaghetti", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Broccoli", "amount": 400, "unit": "g", "notes": "", "order": 1},
                    {"name": "Baccalà", "amount": 200, "unit": "g", "notes": "", "order": 2},
                    {"name": "Cipollotto", "amount": 1, "unit": "pezzo", "notes": "", "order": 3},
                    {"name": "Pomodorini del Piennolo", "amount": 200, "unit": "g", "notes": "", "order": 4},
                    {"name": "Peperoncino fresco", "amount": 1, "unit": "pezzo", "notes": "", "order": 5},
                    {"name": "Zenzero", "amount": 10, "unit": "g", "notes": "", "order": 6},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 7},
                    {"name": "Aglio", "amount": 2, "unit": "spicchi", "notes": "", "order": 8},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 9}
                ],
                "images": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "baccalà", "broccoli"]
            },
            {
                "title": "Burrito con Salsiccia, Fagioli e Spinaci",
                "description": "Un burrito tex-mex godereccio con salsiccia, fagioli cannellini e spinaci freschi. Fusion italiana che conquista!",
                "category": "Piatti Unici",
                "cuisine": "Fusion",
                "difficulty": 3,
                "prep_time_minutes": 25,
                "cook_time_minutes": 30,
                "servings": 4,
                "instructions": [
                    "Tagliate porro e cipollotto a rondelle, metteteli in padella di ghisa con aglio grattugiato e olio, cuocete a fuoco basso.",
                    "Tagliate la pancetta a strisce, togliete il budello dalla salsiccia e mettete in padella. Aggiungete la carne macinata e sbriciolate bene.",
                    "Aggiungete cumino e coriandolo per il tocco etnico, mescolate e date colore con concentrato di pomodoro. Aggiungete acqua calda o brodo e cuocete a fuoco basso.",
                    "Tagliate il peperone a cubetti dopo aver tolto semi e picciolo, aggiungetelo alla carne. Mescolate, aggiungete acqua, salate e cuocete 20 minuti con coperchio.",
                    "Rosolate gli spinaci freschi in padella con olio e sale, lasciateli croccanti.",
                    "Quando la carne è quasi pronta, aggiungete i fagioli cannellini già cotti.",
                    "Tagliate il jalapeño a pezzetti e il formaggio a pezzi.",
                    "Scaldate le tortillas su padella calda, aggiungete il ripieno di carne, jalapeño, cipolla croccante, spinaci, formaggio e chiudete il burrito facendo pieghe.",
                    "Cuocetelo qualche minuto in padella antiaderente e gustate caldo e filante."
                ],
                "ingredients": [
                    {"name": "Tortillas", "amount": 4, "unit": "pezzi", "notes": "", "order": 0},
                    {"name": "Carne macinata", "amount": 300, "unit": "g", "notes": "", "order": 1},
                    {"name": "Pancetta", "amount": 100, "unit": "g", "notes": "", "order": 2},
                    {"name": "Salsiccia", "amount": 200, "unit": "g", "notes": "", "order": 3},
                    {"name": "Fagioli cannellini", "amount": 400, "unit": "g", "notes": "già cotti", "order": 4},
                    {"name": "Peperone rosso", "amount": 1, "unit": "pezzo", "notes": "", "order": 5},
                    {"name": "Formaggio", "amount": 150, "unit": "g", "notes": "", "order": 6},
                    {"name": "Spinaci", "amount": 200, "unit": "g", "notes": "", "order": 7},
                    {"name": "Peperoncino jalapeño", "amount": 1, "unit": "pezzo", "notes": "", "order": 8},
                    {"name": "Cipolla croccante", "amount": 30, "unit": "g", "notes": "", "order": 9},
                    {"name": "Cipollotto", "amount": 1, "unit": "pezzo", "notes": "", "order": 10},
                    {"name": "Porro", "amount": 1, "unit": "pezzo", "notes": "", "order": 11},
                    {"name": "Aglio", "amount": 2, "unit": "spicchi", "notes": "", "order": 12},
                    {"name": "Cumino", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 13},
                    {"name": "Coriandolo", "amount": 1, "unit": "cucchiaino", "notes": "", "order": 14},
                    {"name": "Concentrato di pomodoro", "amount": 2, "unit": "cucchiai", "notes": "", "order": 15},
                    {"name": "Olio extravergine d'oliva", "amount": 50, "unit": "ml", "notes": "", "order": 16},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 17},
                    {"name": "Pepe", "amount": 1, "unit": "q.b.", "notes": "", "order": 18}
                ],
                "images": ["https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=800"],
                "tags": ["max mariola", "fusion", "piatti unici", "burrito", "salsiccia"]
            },
            {
                "title": "Involtini di Maiale",
                "description": "Involtini di lonza di maiale con scamorza e salvia, serviti su crema di patate e porri. Un secondo piatto elegante e saporito!",
                "category": "Secondi Piatti",
                "cuisine": "Italiana",
                "difficulty": 3,
                "prep_time_minutes": 25,
                "cook_time_minutes": 30,
                "servings": 4,
                "instructions": [
                    "Pelate e affettate le patate, affettate sottilmente il porro. Fate saltare patate e porro in tegame con burro, mescolando di tanto in tanto. Aggiungete acqua e fate cuocere.",
                    "Mettete le fette di lonza tra due fogli di carta forno e battetele con batticarne o padellina d'acciaio. Salate, pepate, poi mettete al centro un pezzo di scamorza e una foglia di salvia.",
                    "Arrotolate la carne intorno alla scamorza e fermate con stuzzicadenti.",
                    "In padella antiaderente aggiungete burro o olio e fate dorare gli involtini su tutti i lati. Aggiungete un goccio d'acqua, coprite con coperchio e fate cuocere.",
                    "Una volta cotte le patate, frullatele per creare una crema liscia di patate e porri.",
                    "Per servire, spalmate generosa crema sul fondo del piatto e appoggiate sopra gli involtini di maiale."
                ],
                "ingredients": [
                    {"name": "Lonza di maiale", "amount": 600, "unit": "g", "notes": "a fette", "order": 0},
                    {"name": "Patate", "amount": 500, "unit": "g", "notes": "", "order": 1},
                    {"name": "Scamorza", "amount": 150, "unit": "g", "notes": "", "order": 2},
                    {"name": "Pomodori secchi", "amount": 50, "unit": "g", "notes": "", "order": 3},
                    {"name": "Porro", "amount": 1, "unit": "pezzo", "notes": "", "order": 4},
                    {"name": "Burro", "amount": 50, "unit": "g", "notes": "", "order": 5},
                    {"name": "Salvia", "amount": 8, "unit": "foglie", "notes": "", "order": 6},
                    {"name": "Olio extravergine d'oliva", "amount": 30, "unit": "ml", "notes": "", "order": 7},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 8},
                    {"name": "Pepe", "amount": 1, "unit": "q.b.", "notes": "", "order": 9}
                ],
                "images": ["https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=800"],
                "tags": ["max mariola", "cucina italiana", "secondi piatti", "maiale", "involtini"]
            },
            {
                "title": "Risotto con Zucca, Gambuccio e Provola",
                "description": "Un risotto cremoso con zucca dolce, gambuccio croccante e provola filante. Un primo piatto autunnale ricco di sapore!",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 4,
                "prep_time_minutes": 20,
                "cook_time_minutes": 35,
                "servings": 4,
                "instructions": [
                    "Preparate il brodo vegetale: fate soffriggere porro, sedano e carote tritati in padella con olio. Aggiungete acqua e fate cuocere.",
                    "Tagliate il gambuccio a pezzetti e cuocetelo lentamente in wok con burro fino a renderlo croccante. Scolate e tenete da parte, lasciando il grasso nel wok.",
                    "Affettate sottilmente il porro e aggiungetelo al wok con il grasso del gambuccio e poca acqua. Aggiungete il riso, sfumate con vino e tostatelo bene.",
                    "Tagliate la zucca a cubetti e aggiungetela direttamente al riso. Aggiungete gradualmente il brodo, mescolando continuamente, e cuocete.",
                    "A cottura ultimata, aggiungete burro e Parmigiano grattugiato. Mantecate bene, poi aggiungete il gambuccio croccante e la provola a dadini.",
                    "Servite il risotto caldo, completando con il gambuccio rimasto e una spolverata di pepe fresco o erbe come rosmarino o timo."
                ],
                "ingredients": [
                    {"name": "Riso Carnaroli", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Zucca delica", "amount": 400, "unit": "g", "notes": "", "order": 1},
                    {"name": "Gambuccio", "amount": 150, "unit": "g", "notes": "", "order": 2},
                    {"name": "Provola", "amount": 100, "unit": "g", "notes": "", "order": 3},
                    {"name": "Sedano", "amount": 1, "unit": "costa", "notes": "", "order": 4},
                    {"name": "Carota", "amount": 1, "unit": "pezzo", "notes": "", "order": 5},
                    {"name": "Porro", "amount": 1, "unit": "pezzo", "notes": "", "order": 6},
                    {"name": "Parmigiano", "amount": 80, "unit": "g", "notes": "", "order": 7},
                    {"name": "Burro", "amount": 60, "unit": "g", "notes": "", "order": 8},
                    {"name": "Vino bianco", "amount": 100, "unit": "ml", "notes": "", "order": 9},
                    {"name": "Olio extravergine d'oliva", "amount": 30, "unit": "ml", "notes": "", "order": 10},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 11},
                    {"name": "Pepe", "amount": 1, "unit": "q.b.", "notes": "", "order": 12}
                ],
                "images": ["https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "risotto", "zucca"]
            },
            {
                "title": "Spaghetti alle Vongole con Asparagi, Pomodorini e Stracciatella",
                "description": "Una rivisitazione gourmet degli spaghetti alle vongole con asparagi freschi, pomodorini e stracciatella cremosa. Eleganza e tradizione!",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 4,
                "prep_time_minutes": 25,
                "cook_time_minutes": 20,
                "servings": 4,
                "instructions": [
                    "Fate soffriggere aglio schiacciato in olio in un wok. Aggiungete le vongole e un mestolo di acqua calda, coprite fino all'apertura.",
                    "Preparate gli asparagi spezzando la parte dura. Aggiungete i gambi all'acqua della pasta per sapore e affettate le parti tenere a rondelle, tenendo le punte separate e tagliate a metà per lungo.",
                    "Una volta aperte le vongole, toglietele dal wok e filtrate l'acqua di cottura. Sgusciate la maggior parte delle vongole.",
                    "Nello stesso wok fate soffriggere altro aglio schiacciato e gambi di basilico in olio. Aggiungete gli asparagi affettati e un po' di acqua delle vongole.",
                    "Cuocete gli spaghetti nell'acqua bollente dopo aver tolto i gambi degli asparagi. Nel frattempo tritate pomodorini rossi e gialli e conditeli con basilico, un cucchiaio di acqua delle vongole e olio per la guarnizione.",
                    "Quando gli spaghetti sono al dente, trasferiteli nel wok con gli asparagi. Aggiungete l'acqua delle vongole, alcune vongole e basilico fresco. Condite con pepe nero e aggiungete le punte di asparagi crude.",
                    "Aggiungete tutte le vongole, mantecate tutto e impiattate. Guarnite con un cucchiaio di stracciatella e i pomodorini conditi."
                ],
                "ingredients": [
                    {"name": "Spaghetti", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Vongole", "amount": 800, "unit": "g", "notes": "", "order": 1},
                    {"name": "Asparagi", "amount": 300, "unit": "g", "notes": "", "order": 2},
                    {"name": "Pomodorini rossi e gialli", "amount": 200, "unit": "g", "notes": "", "order": 3},
                    {"name": "Stracciatella", "amount": 150, "unit": "g", "notes": "", "order": 4},
                    {"name": "Basilico fresco", "amount": 15, "unit": "foglie", "notes": "", "order": 5},
                    {"name": "Aglio", "amount": 3, "unit": "spicchi", "notes": "", "order": 6},
                    {"name": "Olio extravergine d'oliva", "amount": 60, "unit": "ml", "notes": "", "order": 7},
                    {"name": "Pepe nero", "amount": 1, "unit": "q.b.", "notes": "", "order": 8},
                    {"name": "Sale", "amount": 1, "unit": "q.b.", "notes": "", "order": 9}
                ],
                "images": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "vongole", "asparagi", "gourmet"]
            },
            {
                "title": "Spaghetti Aglio, Olio e Peperoncino con Mentuccia e Pecorino",
                "description": "Il classico aglio, olio e peperoncino rivisitato con mentuccia fresca e pecorino di fossa. Semplicità e sapore in un piatto!",
                "category": "Primi Piatti",
                "cuisine": "Italiana",
                "difficulty": 1,
                "prep_time_minutes": 10,
                "cook_time_minutes": 15,
                "servings": 4,
                "instructions": [
                    "Mettete abbondante olio buono in padella con gli spicchi d'aglio e fateli sfrigolare.",
                    "Quando l'aglio è dorato, spegnete il fuoco e lasciatelo in padella.",
                    "Prendete qualche foglia di mentuccia o nepitella e aggiungetele al soffritto per renderlo fresco. Aggiungete peperoncino secco a piacere.",
                    "Cuocete la pasta in abbondante acqua con pochissimo sale (o senza) fino al dente. Versatela nella padella con il soffritto, a fuoco spento, e grattugiate abbondante pecorino.",
                    "Mescolate bene e mangiatelo in compagnia, perché è semplice ma delizioso!"
                ],
                "ingredients": [
                    {"name": "Spaghetti", "amount": 320, "unit": "g", "notes": "", "order": 0},
                    {"name": "Aglio fresco", "amount": 4, "unit": "spicchi", "notes": "", "order": 1},
                    {"name": "Peperoncino secco", "amount": 1, "unit": "pezzo", "notes": "", "order": 2},
                    {"name": "Pecorino di fossa", "amount": 100, "unit": "g", "notes": "", "order": 3},
                    {"name": "Mentuccia o nepitella", "amount": 10, "unit": "foglie", "notes": "", "order": 4},
                    {"name": "Sale", "amount": 1, "unit": "pizzico", "notes": "", "order": 5},
                    {"name": "Olio extravergine d'oliva", "amount": 80, "unit": "ml", "notes": "", "order": 6}
                ],
                "images": ["https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800"],
                "tags": ["max mariola", "cucina italiana", "primi piatti", "aglio olio", "tradizionale"]
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
            print("=== Adding Max Mariola Pasta & Specialty Recipes ===\n")
            
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
            
            print(f"\n=== Pasta & Specialty Addition Complete ===")
            print(f"✓ Successful: {successful}")
            print(f"✗ Failed: {failed}")
            print(f"📊 Total: {len(recipes)}")
            
        except Exception as e:
            print(f"✗ Error in main execution: {e}")
            raise

if __name__ == "__main__":
    adder = MaxMariolaPastaSpecialties()
    asyncio.run(adder.run())
