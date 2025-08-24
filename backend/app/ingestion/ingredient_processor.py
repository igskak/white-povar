import re
from typing import List, Dict, Optional, Any, Tuple
import logging
from app.schemas.ingestion import ParsedIngredient
from app.services.database import supabase_service

logger = logging.getLogger(__name__)


class IngredientProcessor:
    """Process and normalize ingredients for database storage"""
    
    def __init__(self):
        self.unit_mappings = {
            # Common unit normalizations
            'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp.': 'tbsp',
            'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp.': 'tsp',
            'gram': 'g', 'grams': 'g', 'gr': 'g',
            'kilogram': 'kg', 'kilograms': 'kg', 'kilo': 'kg',
            'milliliter': 'ml', 'milliliters': 'ml', 'millilitre': 'ml',
            'liter': 'l', 'liters': 'l', 'litre': 'l', 'litres': 'l',
            'cup': 'cup', 'cups': 'cup',
            'ounce': 'oz', 'ounces': 'oz',
            'pound': 'lb', 'pounds': 'lb',
            'piece': 'pc', 'pieces': 'pc', 'pcs': 'pc',
            'clove': 'pc', 'cloves': 'pc',  # garlic cloves as pieces
            'slice': 'pc', 'slices': 'pc',
            'pinch': 'pinch', 'pinches': 'pinch',
            'dash': 'dash', 'dashes': 'dash',
            'to taste': None,  # No unit for "to taste"
        }
        
        self.ingredient_normalizations = {
            # Common ingredient name normalizations
            'onions': 'onion',
            'tomatoes': 'tomato',
            'carrots': 'carrot',
            'potatoes': 'potato',
            'garlic cloves': 'garlic',
            'olive oil': 'olive oil',
            'salt and pepper': 'salt',  # Will need special handling
            'black pepper': 'black pepper',
            'ground black pepper': 'black pepper',
        }
    
    async def process_ingredients(self, parsed_ingredients: List[ParsedIngredient]) -> List[Dict[str, Any]]:
        """
        Process parsed ingredients into database-ready format
        
        Returns list of ingredient dictionaries for recipe_ingredients table
        """
        processed_ingredients = []
        
        for ingredient in parsed_ingredients:
            try:
                processed = await self._process_single_ingredient(ingredient)
                if processed:
                    processed_ingredients.append(processed)
            except Exception as e:
                logger.warning(f"Failed to process ingredient '{ingredient.name}': {str(e)}")
                # Create fallback ingredient
                fallback = {
                    'display_name': ingredient.name,
                    'amount': ingredient.quantity_value,
                    'preparation_notes': ingredient.notes
                }
                processed_ingredients.append(fallback)
        
        return processed_ingredients
    
    async def _process_single_ingredient(self, ingredient: ParsedIngredient) -> Dict[str, Any]:
        """Process a single ingredient"""
        # Normalize ingredient name
        normalized_name = self._normalize_ingredient_name(ingredient.name)
        
        # Find base ingredient
        base_ingredient = await self._find_base_ingredient(normalized_name)
        
        # Normalize unit
        unit_id = await self._find_unit_id(ingredient.unit) if ingredient.unit else None
        
        # Extract preparation notes
        preparation_notes = self._extract_preparation_notes(ingredient)
        
        # Build ingredient data
        ingredient_data = {
            'display_name': ingredient.name.strip(),
            'amount': ingredient.quantity_value,
            'unit_id': unit_id,
            'preparation_notes': preparation_notes,
            'base_ingredient_id': base_ingredient['id'] if base_ingredient else None
        }
        
        return ingredient_data
    
    def _normalize_ingredient_name(self, name: str) -> str:
        """Normalize ingredient name for matching"""
        if not name:
            return ""
        
        # Convert to lowercase and strip
        normalized = name.lower().strip()
        
        # Remove common preparation words for matching
        prep_words = ['fresh', 'dried', 'chopped', 'diced', 'minced', 'sliced', 
                     'grated', 'ground', 'whole', 'large', 'small', 'medium']
        
        for word in prep_words:
            normalized = re.sub(rf'\b{word}\b', '', normalized)
        
        # Remove extra spaces
        normalized = ' '.join(normalized.split())
        
        # Apply specific normalizations
        for original, replacement in self.ingredient_normalizations.items():
            if original in normalized:
                normalized = normalized.replace(original, replacement)
        
        return normalized.strip()
    
    async def _find_base_ingredient(self, normalized_name: str) -> Optional[Dict[str, Any]]:
        """Find matching base ingredient"""
        if not normalized_name:
            return None
        
        try:
            # Try exact match first
            base_ingredient = await supabase_service.find_base_ingredient_by_name(normalized_name)
            if base_ingredient:
                return base_ingredient
            
            # Try partial matches
            words = normalized_name.split()
            for word in words:
                if len(word) > 2:  # Skip very short words
                    base_ingredient = await supabase_service.find_base_ingredient_by_name(word)
                    if base_ingredient:
                        logger.info(f"Matched '{normalized_name}' to base ingredient '{base_ingredient['name_en']}' via word '{word}'")
                        return base_ingredient
            
            return None
            
        except Exception as e:
            logger.warning(f"Error finding base ingredient for '{normalized_name}': {str(e)}")
            return None
    
    async def _find_unit_id(self, unit_name: str) -> Optional[str]:
        """Find unit ID by name or abbreviation"""
        if not unit_name:
            return None
        
        try:
            # Normalize unit name
            normalized_unit = unit_name.lower().strip()
            
            # Apply unit mappings
            if normalized_unit in self.unit_mappings:
                mapped_unit = self.unit_mappings[normalized_unit]
                if mapped_unit is None:  # "to taste" case
                    return None
                normalized_unit = mapped_unit
            
            # Find in database
            unit = await supabase_service.find_unit_by_name(normalized_unit)
            if unit:
                return unit['id']
            
            logger.warning(f"Unit not found: '{unit_name}' (normalized: '{normalized_unit}')")
            return None
            
        except Exception as e:
            logger.warning(f"Error finding unit for '{unit_name}': {str(e)}")
            return None
    
    def _extract_preparation_notes(self, ingredient: ParsedIngredient) -> Optional[str]:
        """Extract preparation notes from ingredient"""
        notes = []
        
        # Add existing notes
        if ingredient.notes:
            notes.append(ingredient.notes)
        
        # Extract preparation words from the name
        name_lower = ingredient.name.lower()
        prep_words = ['chopped', 'diced', 'minced', 'sliced', 'grated', 'ground', 
                     'fresh', 'dried', 'whole', 'large', 'small', 'medium',
                     'to taste', 'optional']
        
        found_prep = []
        for word in prep_words:
            if word in name_lower:
                found_prep.append(word)
        
        if found_prep:
            notes.extend(found_prep)
        
        return ', '.join(notes) if notes else None
    
    async def get_ingredient_statistics(self) -> Dict[str, Any]:
        """Get statistics about ingredient processing"""
        try:
            # Get counts from database
            base_ingredients_result = await supabase_service.execute_query('base_ingredients', 'select', use_service_key=True)
            units_result = await supabase_service.execute_query('units', 'select', use_service_key=True)
            categories_result = await supabase_service.execute_query('ingredient_categories', 'select', use_service_key=True)
            recipe_ingredients_result = await supabase_service.execute_query('recipe_ingredients', 'select', use_service_key=True)
            
            return {
                'base_ingredients_count': len(base_ingredients_result.data) if base_ingredients_result.data else 0,
                'units_count': len(units_result.data) if units_result.data else 0,
                'categories_count': len(categories_result.data) if categories_result.data else 0,
                'recipe_ingredients_count': len(recipe_ingredients_result.data) if recipe_ingredients_result.data else 0
            }
            
        except Exception as e:
            logger.error(f"Error getting ingredient statistics: {str(e)}")
            return {}


# Global instance
ingredient_processor = IngredientProcessor()
