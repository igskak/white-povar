import re
from typing import List, Dict, Optional, Any
import logging
from app.schemas.ingestion import ParsedIngredient
from app.services.database import supabase_service

logger = logging.getLogger(__name__)


class IngredientMatcher:
    """Smart ingredient matching to reuse existing base ingredients"""
    
    def __init__(self):
        self.base_ingredients_cache = None
        self.units_cache = None
        
        # Common ingredient name normalizations
        self.ingredient_normalizations = {
            'onions': 'onion',
            'tomatoes': 'tomato', 
            'carrots': 'carrot',
            'potatoes': 'potato',
            'garlic cloves': 'garlic',
            'cloves garlic': 'garlic',
            'olive oil': 'olive oil',
            'black pepper': 'black pepper',
            'ground black pepper': 'black pepper',
            'fresh parsley': 'parsley',
            'fresh basil': 'basil',
            'parmesan cheese': 'parmesan',
            'mozzarella cheese': 'mozzarella',
            'cheddar cheese': 'cheddar',
            'ground beef': 'ground beef',
            'chicken breast': 'chicken breast',
            'chicken thighs': 'chicken thigh',
        }
        
        # Unit normalizations
        self.unit_normalizations = {
            'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp.': 'tbsp',
            'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp.': 'tsp', 
            'gram': 'g', 'grams': 'g', 'gr': 'g',
            'kilogram': 'kg', 'kilograms': 'kg', 'kilo': 'kg',
            'milliliter': 'ml', 'milliliters': 'ml', 'millilitre': 'ml',
            'liter': 'l', 'liters': 'l', 'litre': 'l',
            'cup': 'cup', 'cups': 'cup',
            'ounce': 'oz', 'ounces': 'oz',
            'pound': 'lb', 'pounds': 'lb',
            'piece': 'piece', 'pieces': 'piece', 'pc': 'piece', 'pcs': 'piece',
            'clove': 'piece', 'cloves': 'piece',
            'slice': 'piece', 'slices': 'piece',
        }
    
    async def process_ingredients(self, parsed_ingredients: List[ParsedIngredient]) -> List[Dict[str, Any]]:
        """
        Process ingredients and match them to existing base ingredients
        
        Returns list of ingredient dictionaries for recipe_ingredients table
        """
        # Load caches if needed
        await self._load_caches()
        
        processed_ingredients = []
        
        for i, ingredient in enumerate(parsed_ingredients):
            try:
                processed = await self._process_single_ingredient(ingredient, i + 1)
                processed_ingredients.append(processed)
            except Exception as e:
                logger.warning(f"Failed to process ingredient '{ingredient.name}': {str(e)}")
                # Create fallback ingredient
                fallback = {
                    'display_name': ingredient.name,
                    'amount': ingredient.quantity_value,
                    'preparation_notes': ingredient.notes,
                    'sort_order': i + 1
                }
                processed_ingredients.append(fallback)
        
        return processed_ingredients
    
    async def _process_single_ingredient(self, ingredient: ParsedIngredient, sort_order: int) -> Dict[str, Any]:
        """Process a single ingredient"""
        # Clean and normalize the ingredient name
        clean_name = self._clean_ingredient_name(ingredient.name)
        
        # Try to find matching base ingredient
        base_ingredient = self._find_matching_base_ingredient(clean_name)
        
        # Find unit ID if we have a unit
        unit_id = self._find_unit_id(ingredient.unit) if ingredient.unit else None
        
        # Extract preparation notes
        prep_notes = self._extract_preparation_notes(ingredient)
        
        # Build the ingredient record (exclude None values)
        ingredient_data = {
            'display_name': ingredient.name.strip(),
            'sort_order': sort_order
        }

        # Add optional fields only if they have values
        if ingredient.quantity_value is not None:
            ingredient_data['amount'] = ingredient.quantity_value

        if unit_id:
            ingredient_data['unit_id'] = unit_id

        if prep_notes:
            ingredient_data['preparation_notes'] = prep_notes

        # Add base ingredient reference if found
        if base_ingredient:
            ingredient_data['base_ingredient_id'] = base_ingredient['id']
            logger.info(f"Matched '{ingredient.name}' to base ingredient '{base_ingredient['name_en']}'")
        else:
            logger.info(f"No base ingredient match found for '{ingredient.name}'")

        return ingredient_data
    
    def _clean_ingredient_name(self, name: str) -> str:
        """Clean ingredient name for matching"""
        if not name:
            return ""
        
        # Convert to lowercase and strip
        clean = name.lower().strip()
        
        # Remove quantity information that might be in the name
        clean = re.sub(r'^\d+(\.\d+)?\s*(g|kg|ml|l|cup|cups|tbsp|tsp|oz|lb|piece|pieces|pc|pcs|clove|cloves)?\s*', '', clean)
        
        # Remove common preparation words for matching
        prep_words = ['fresh', 'dried', 'chopped', 'diced', 'minced', 'sliced', 
                     'grated', 'ground', 'whole', 'large', 'small', 'medium',
                     'finely', 'roughly', 'coarsely']
        
        for word in prep_words:
            clean = re.sub(rf'\b{word}\b', '', clean)
        
        # Remove punctuation and extra spaces
        clean = re.sub(r'[,\(\)]', '', clean)
        clean = ' '.join(clean.split())
        
        # Apply specific normalizations
        for original, replacement in self.ingredient_normalizations.items():
            if original in clean:
                clean = clean.replace(original, replacement)
        
        return clean.strip()
    
    def _find_matching_base_ingredient(self, clean_name: str) -> Optional[Dict[str, Any]]:
        """Find matching base ingredient from cache"""
        if not clean_name or not self.base_ingredients_cache:
            return None
        
        # Try exact match first
        for base_ing in self.base_ingredients_cache:
            if base_ing['name_en'].lower() == clean_name:
                return base_ing
        
        # Try partial matches
        for base_ing in self.base_ingredients_cache:
            base_name = base_ing['name_en'].lower()
            
            # Check if clean_name contains the base ingredient name
            if base_name in clean_name or clean_name in base_name:
                return base_ing
            
            # Check aliases if they exist
            if base_ing.get('aliases'):
                for alias in base_ing['aliases']:
                    if alias.lower() == clean_name:
                        return base_ing
        
        # Try word-by-word matching for compound ingredients
        clean_words = clean_name.split()
        for word in clean_words:
            if len(word) > 2:  # Skip very short words
                for base_ing in self.base_ingredients_cache:
                    if word in base_ing['name_en'].lower():
                        return base_ing
        
        return None
    
    def _find_unit_id(self, unit_name: str) -> Optional[str]:
        """Find unit ID from cache"""
        if not unit_name or not self.units_cache:
            return None
        
        # Normalize unit name
        normalized_unit = unit_name.lower().strip()
        
        # Apply unit normalizations
        if normalized_unit in self.unit_normalizations:
            normalized_unit = self.unit_normalizations[normalized_unit]
        
        # Handle special cases
        if normalized_unit in ['to taste', 'taste']:
            return None
        
        # Find in cache
        for unit in self.units_cache:
            if (unit['abbreviation_en'].lower() == normalized_unit or 
                unit['name_en'].lower() == normalized_unit):
                return unit['id']
        
        return None
    
    def _extract_preparation_notes(self, ingredient: ParsedIngredient) -> Optional[str]:
        """Extract preparation notes"""
        notes = []
        
        # Add existing notes
        if ingredient.notes:
            notes.append(ingredient.notes)
        
        # Add unit if it's descriptive (not a standard unit)
        if ingredient.unit and ingredient.unit.lower() in ['to taste', 'pinch', 'dash', 'handful']:
            notes.append(ingredient.unit)
        
        # Extract preparation words from the name
        name_lower = ingredient.name.lower()
        prep_words = ['chopped', 'diced', 'minced', 'sliced', 'grated', 'ground',
                     'fresh', 'dried', 'whole', 'large', 'small', 'medium',
                     'finely', 'roughly', 'coarsely', 'to taste', 'optional']
        
        found_prep = []
        for word in prep_words:
            if word in name_lower and word not in notes:
                found_prep.append(word)
        
        if found_prep:
            notes.extend(found_prep)
        
        return ', '.join(notes) if notes else None
    
    async def _load_caches(self):
        """Load base ingredients and units into cache"""
        try:
            if self.base_ingredients_cache is None:
                result = await supabase_service.execute_query('base_ingredients', 'select', use_service_key=True)
                self.base_ingredients_cache = result.data if result.data else []
                logger.info(f"Loaded {len(self.base_ingredients_cache)} base ingredients into cache")
            
            if self.units_cache is None:
                result = await supabase_service.execute_query('units', 'select', use_service_key=True)
                self.units_cache = result.data if result.data else []
                logger.info(f"Loaded {len(self.units_cache)} units into cache")
                
        except Exception as e:
            logger.error(f"Failed to load ingredient caches: {str(e)}")
            self.base_ingredients_cache = []
            self.units_cache = []
    
    async def get_matching_stats(self) -> Dict[str, Any]:
        """Get statistics about ingredient matching"""
        await self._load_caches()
        
        return {
            'base_ingredients_available': len(self.base_ingredients_cache),
            'units_available': len(self.units_cache),
            'normalizations_configured': len(self.ingredient_normalizations)
        }


# Global instance
ingredient_matcher = IngredientMatcher()
