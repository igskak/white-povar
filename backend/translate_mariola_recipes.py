#!/usr/bin/env python3
"""
Translate Max Mariola recipes from Italian to English
"""

import asyncio
import sys
import os

# Add current directory to path
sys.path.append('.')

from app.services.database import supabase_service

class MaxMariolaTranslator:
    def __init__(self):
        self.chef_id = "a06dccc2-0e3d-45ee-9d16-cb348898dd7a"
        
    def get_translations(self):
        """Return translations for Max Mariola recipes"""
        return {
            # Recipe 1
            "Pancotto con verdure e bottarga": {
                "title": "Bread Soup with Vegetables and Bottarga",
                "description": "A beautiful rustic soup with seasonal vegetables and bottarga to enjoy in summer. Try my delicious version of this traditional Pugliese pancotto.",
                "instructions": [
                    "Prepare the stale bread by cutting it into pieces and soaking it in warm water.",
                    "In a pan, heat the extra virgin olive oil and sauté the chopped garlic.",
                    "Add the seasonal vegetables cut into pieces and cook for a few minutes.",
                    "Add the squeezed bread and mix well, adding vegetable broth if necessary.",
                    "Finish with grated bottarga and serve hot."
                ],
                "tags": ["max mariola", "italian cuisine", "first courses", "pugliese", "bottarga"]
            },
            
            # Recipe 2
            "Pasta con verdure e tonno": {
                "title": "Pasta with Vegetables and Tuna",
                "description": "An amazing pasta with tuna and seasonal vegetables perfect for summer! A complete and flavorful dish that combines sea and land.",
                "instructions": [
                    "Peel and dice a potato, then cook it in boiling salted water along with the pasta.",
                    "Cut a trumpet zucchini into rounds.",
                    "Slice a fresh spring onion and sauté it in a wok with oil.",
                    "Add the zucchini, salt and chili powder to the wok and cook.",
                    "Cut the red and yellow cherry tomatoes in half and add them to the wok.",
                    "Add the tuna in oil and olives to the wok, mix and turn off the heat.",
                    "About 3 minutes before the pasta is ready, add the cleaned green beans to the pasta water.",
                    "Drain pasta, potatoes and green beans and add them to the wok with the sauce.",
                    "Add some fresh basil leaves and toss everything together."
                ],
                "tags": ["max mariola", "italian cuisine", "first courses", "tuna", "vegetables"]
            },
            
            # Recipe 3
            "Pasta e fagioli estiva": {
                "title": "Summer Pasta and Beans",
                "description": "Try the perfect recipe for summer pasta and beans made with quality ingredients and lots of love to enjoy legumes even in summer.",
                "instructions": [
                    "If using dried beans, soak them overnight and then cook them for about 2 hours until tender.",
                    "In a wok put good oil with garlic and brown well. Then add the pear tomatoes, crush them with a fork and cook for a few minutes.",
                    "Add the already cooked beans to the tomato sauce and let them absorb the flavors well.",
                    "Meanwhile, cook the mixed pasta in boiling salted water.",
                    "Drain the pasta and pour it into the wok with the beans. Add plenty of pecorino and toss everything together."
                ],
                "tags": ["max mariola", "italian cuisine", "first courses", "beans", "traditional"]
            },
            
            # Recipe 4
            "Tagliolini con tartare e peperoni croccanti": {
                "title": "Tagliolini with Tartare and Crispy Peppers",
                "description": "A delicious first course with good meat and crispy peppers to lick your lips! A gourmet recipe that combines the delicacy of tagliolini with the flavor of tartare.",
                "instructions": [
                    "Prepare the fresh meat tartare by cutting it finely with a knife and season it with oil, salt, pepper and aromatic herbs.",
                    "Cut the peppers into strips and fry them in hot oil until crispy.",
                    "Prepare a savory zabaglione cream by whipping egg yolks with white wine in a double boiler.",
                    "Cook the tagliolini in plenty of salted water until al dente.",
                    "Toss the pasta with the zabaglione cream and plate.",
                    "Complete with the meat tartare and crispy peppers."
                ],
                "tags": ["max mariola", "italian cuisine", "first courses", "tartare", "gourmet"]
            },
            
            # Recipe 5
            "Pasta di riso con pollo e verdure": {
                "title": "Rice Pasta with Chicken and Vegetables",
                "description": "A complete and light recipe, perfect for eating well and tasty for lunch or dinner. A fusion dish that combines Italian tradition with oriental flavors.",
                "instructions": [
                    "Wash all vegetables well. You can use some baking soda for extra cleaning.",
                    "Cut the eggplants into slices and then into cubes. Salt them to draw out the bitter water.",
                    "Slice the zucchini and peppers into cubes after removing seeds and stem.",
                    "Peel a piece of ginger and a clove of garlic. Finely slice a spring onion.",
                    "Cut the chicken breast into strips and marinate it with soy sauce and lemon juice.",
                    "Heat oil in a wok with spring onion and grated ginger over low heat.",
                    "Add zucchini and eggplant to the wok, then the marinated chicken.",
                    "When the chicken is well cooked, add the peppers which should remain crispy.",
                    "Cut the cherry tomatoes in half and a small hot pepper into pieces.",
                    "Cook the rice pasta in boiling salted water, drain it and add it to the wok.",
                    "Add tomatoes and chili, toss everything together and serve."
                ],
                "tags": ["max mariola", "fusion", "first courses", "chicken", "vegetables", "light"]
            },
            
            # Recipe 6
            "Bruschetta con vongole e pomodorini": {
                "title": "Bruschetta with Clams and Cherry Tomatoes",
                "description": "A delicious bruschetta with lupini clams and datterini cherry tomatoes. A seafood appetizer that tastes like summer and Neapolitan tradition!",
                "instructions": [
                    "Wash the clams well to remove excess water.",
                    "Open the clams in a wok with plenty of extra virgin oil, a clove of garlic and parsley stems. Cover and cook for a few minutes, keeping them nice and juicy.",
                    "Meanwhile, cut the cherry tomatoes into pieces and season them with a drizzle of oil and some grated garlic. Also add a drop of the clam cooking water and fresh chopped parsley.",
                    "As soon as the clams open, put them in a bowl and shell them one by one, then drizzle them with the cooking liquid to keep them soft.",
                    "Cut some slices of rustic bread and toast them in a hot pan with some good oil.",
                    "Assemble the bruschetta: put the seasoned tomatoes on the bread pieces, add the cooked clams, garnish with parsley and finish with a nice drizzle of oil."
                ],
                "tags": ["max mariola", "italian cuisine", "appetizers", "clams", "bruschetta", "seafood"]
            },
            
            # Recipe 7
            "Avocado Toast con uova e pomodoro": {
                "title": "Avocado Toast with Eggs and Tomato",
                "description": "A modern and healthy toast with avocado, eggs and tomato. Perfect for a nutritious breakfast or a delicious brunch!",
                "instructions": [
                    "Cut the homemade bread into slices, season with a drizzle of oil and toast it in a hot pan.",
                    "Take a slightly ripe avocado, cut it in half and scoop out the flesh with a spoon. Slice it.",
                    "In a small bowl mix the juice of half a lemon with oil, sweet paprika, turmeric and ginger. Add a pinch of salt and mix well.",
                    "In a hot pan with a drizzle of oil, cook the poached eggs with a pinch of salt. Keep them aside still soft.",
                    "In a pan toast a mix of seeds (pumpkin, sesame, flax) until they start to pop. Then crush them in a mortar or in a bag to release the oils.",
                    "On a plate arrange two slices of toasted bread. On top put the avocado slices and some thick tomato slices. Season with the sauce to give flavor. Place the poached eggs on top. Garnish with fresh mint and basil and finish with a sprinkle of the toasted seeds."
                ],
                "tags": ["max mariola", "modern", "breakfast", "avocado", "healthy", "brunch"]
            },
            
            # Recipe 8
            "Quinoa con verdure e feta": {
                "title": "Quinoa with Vegetables and Feta",
                "description": "A fresh summer salad, perfect to take to the office or to the beach. A complete and healthy dish with quinoa, Greek feta and seasonal vegetables.",
                "instructions": [
                    "Cook the quinoa in boiling water for 10-15 minutes until cooked.",
                    "While the quinoa cooks, prepare the vegetables. Cut zucchini and peppers and sauté them in a wok with garlic and oil.",
                    "Add basil to the zucchini when they start to brown, then the peppers and mint.",
                    "Cut the cherry tomatoes in half and set aside.",
                    "Once cooked, cool the quinoa under running water.",
                    "Prepare a dressing by emulsifying oil, lemon juice, oregano, basil and mint.",
                    "Season the cooled quinoa with this dressing.",
                    "Compose the dish by combining seasoned quinoa, sautéed vegetables, fresh tomatoes and crumbled feta. Let it rest in the fridge before serving."
                ],
                "tags": ["max mariola", "mediterranean", "salads", "quinoa", "feta", "healthy"]
            },
            
            # Recipe 9
            "Frittata dolce austriaca": {
                "title": "Austrian Sweet Frittata",
                "description": "A sweet frittata from Austrian tradition, perfect for a special breakfast or a light dessert. Served with ricotta and fresh seasonal fruit.",
                "instructions": [
                    "Separate the egg whites from the yolks in two different bowls. Whip the egg whites with a pinch of salt until foamy.",
                    "With the same whisk, whip the yolks with sugar and flavor with grated lemon zest or vanilla. Add milk while continuing to mix well.",
                    "Incorporate 100 grams of sifted flour and mix well to avoid lumps.",
                    "Gently incorporate the whipped egg whites into the yolk mixture, moving from top to bottom so as not to deflate the mixture.",
                    "Melt a knob of butter in a non-stick pan and pour in all the mixture. Cover and cook for 4-5 minutes. When a crust has formed, cut it into 4 parts and separate them.",
                    "Lower the heat and start to crumble it with a silicone spatula.",
                    "Toss it lightly to cook the mixture and brown it well.",
                    "Once golden, pour it onto a plate and serve with a spoonful of worked ricotta and fresh seasonal fruit cut up.",
                    "Garnish with fresh mint and a dusting of powdered sugar."
                ],
                "tags": ["max mariola", "austrian", "desserts", "frittata", "breakfast", "dessert"]
            },
            
            # Recipe 10
            "Panino con verdure e alici": {
                "title": "Sandwich with Vegetables and Anchovies",
                "description": "Enough with pasta with anchovies, make this delicious sandwich with seasonal vegetables and you'll see what a treat!",
                "instructions": [
                    "Prepare the vegetables by washing them and cutting them julienne style.",
                    "In a pan heat the oil and sauté the vegetables for a few minutes.",
                    "Add the anchovies in oil and let them flavor.",
                    "Cut the bread in half and toast it lightly.",
                    "Fill the sandwich with the vegetables and anchovies, add a drizzle of oil and serve."
                ],
                "tags": ["max mariola", "italian cuisine", "sandwiches", "anchovies", "vegetables"]
            },
            
            # Recipe 11
            "Pasta al Formaggio": {
                "title": "Cheese Pasta",
                "description": "A delicious cheese pasta with six different cheeses and crispy guanciale. A creamy and flavorful first course that tastes like Italian tradition!",
                "instructions": [
                    "Prepare a béchamel sauce with butter, flour and whole milk.",
                    "Grate the Piave, Casera, Gruyère, Caciocavallo Silano and Emmental cheeses in a bowl and incorporate them into the béchamel.",
                    "Cut the guanciale into small pieces and brown it in a pan until crispy.",
                    "Cook the pasta al dente in salted water with a few basil leaves.",
                    "Drain the pasta and combine it in a bowl with the guanciale, cheese sauce, black pepper and more basil.",
                    "Transfer the mixture to individual ramekins.",
                    "Top with panko, Grana Padano and butter and bake until golden brown."
                ],
                "tags": ["max mariola", "italian cuisine", "first courses", "cheese", "guanciale"]
            },

            # Recipe 12
            "Cheeseburger Fatto in Casa": {
                "title": "Homemade Cheeseburger",
                "description": "The perfect homemade cheeseburger with artisanal ketchup, pickled cucumbers and melted fontina. A delicious burger that beats any fast food!",
                "instructions": [
                    "For the ketchup: cut the spring onion into rings and brown it with oil. Add grated ginger and garlic, cinnamon, sweet paprika, tomato paste, nutmeg and tomato puree.",
                    "In a small bowl mix potato starch, sugar and apple cider vinegar. Add to the tomato, salt and blend everything.",
                    "Cut the cucumbers into thin slices with a peeler and season them with brown sugar, vinegar, salt and ginger.",
                    "Chop the pancetta and mix it with the ground meat. Work well with your hands and form 150g burgers.",
                    "Cook the burgers in a non-stick pan with oil. When you flip them, add sliced fontina and cover to melt it.",
                    "Heat the buns in the same pan, on the crumb side.",
                    "Assemble the cheeseburger: cucumbers, mustard, homemade ketchup, burger with fontina and close."
                ],
                "tags": ["max mariola", "american", "sandwiches", "hamburger", "homemade"]
            },

            # Recipe 13
            "Pasta ai 4 Formaggi e Limone": {
                "title": "Four Cheese and Lemon Pasta",
                "description": "A classic and elegant first course with four fine cheeses and the fresh scent of lemon. Creamy, refined and irresistible!",
                "instructions": [
                    "Toast the mixed seeds in a pan to add crunchiness.",
                    "In a pan gently heat milk and cream with lemon zest over low heat. It should not boil.",
                    "Cut the cheeses into small pieces and add them to the hot milk with some sage leaves. Mix until you get a smooth sauce.",
                    "Cook the mafalde in boiling salted water and drain them al dente.",
                    "Combine the pasta with the cheese sauce and toss well.",
                    "Serve garnished with toasted seeds, grated lemon zest and black pepper."
                ],
                "tags": ["max mariola", "italian cuisine", "first courses", "cheese", "lemon"]
            },

            # Recipe 14
            "Panino con Frittata di Patate e Salsiccia": {
                "title": "Sandwich with Potato and Sausage Frittata",
                "description": "A hearty and delicious sandwich with potato frittata, sausage and cheese. Perfect for a snack or a quick but tasty lunch!",
                "instructions": [
                    "Peel the potatoes and cut them into cubes. Fry them in a non-stick pan with oil.",
                    "Cut the red onion into rings and add it to the potatoes with the crumbled sausage.",
                    "Cut the cheese into slices, then into cubes and set aside.",
                    "In a bowl beat 4-5 eggs and pour in the potatoes with sausage and cheese pieces.",
                    "Cook the frittata in a hot non-stick pan with oil, moving it slightly. Add chopped basil and pieces of 'nduja if you like.",
                    "Cover with a plate, flip the frittata and let it slide into the pan to cook evenly.",
                    "Cut the bread into slices and toast it with oil in a pan until golden.",
                    "Cut the tomato into slices, put it on the bread, add a piece of frittata and close with the other slice."
                ],
                "tags": ["max mariola", "italian cuisine", "sandwiches", "frittata", "sausage"]
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

    async def update_recipe(self, recipe_id: str, updates: dict) -> bool:
        """Update a recipe with new data"""
        try:
            # Use the supabase service directly
            result = await supabase_service.execute_query(
                'recipes',
                'update',
                data=updates,
                filters={'id': recipe_id},
                use_service_key=True
            )

            if result.data:
                return True
            else:
                return False
        except Exception as e:
            print(f"✗ Error updating recipe: {e}")
            return False

    async def run(self):
        """Main execution method"""
        try:
            print("=== Translating Max Mariola Recipes to English ===\n")
            
            # Get all Max Mariola recipes
            recipes = await self.get_max_mariola_recipes()
            print(f"Found {len(recipes)} Max Mariola recipes to translate\n")
            
            # Get translations
            translations = self.get_translations()
            
            updated_count = 0
            skipped_count = 0
            
            for recipe in recipes:
                title = recipe['title']
                recipe_id = recipe['id']
                
                if title in translations:
                    translation = translations[title]
                    
                    # Prepare updates
                    updates = {
                        'title': translation['title'],
                        'description': translation['description'],
                        'instructions': translation['instructions'],
                        'tags': translation['tags'],
                        'cuisine': 'Italian'  # Standardize cuisine to English
                    }
                    
                    print(f"Translating: {title} -> {translation['title']}")
                    
                    if await self.update_recipe(recipe_id, updates):
                        updated_count += 1
                        print(f"✓ Updated successfully")
                    else:
                        print(f"✗ Failed to update")
                else:
                    print(f"⚠ No translation found for: {title}")
                    skipped_count += 1
                
                print()
            
            print(f"=== Translation Complete ===")
            print(f"✓ Updated: {updated_count} recipes")
            print(f"⚠ Skipped: {skipped_count} recipes")
            print(f"📊 Total processed: {len(recipes)} recipes")
            
        except Exception as e:
            print(f"✗ Error in main execution: {e}")
            raise

if __name__ == "__main__":
    translator = MaxMariolaTranslator()
    asyncio.run(translator.run())
