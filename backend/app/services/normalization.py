"""
Data Normalization Service

Handles conversion of incoming data to canonical formats:
- Units to metric system
- Text to English (canonical language)
- Numbers to proper decimal format
- Dates to UTC/ISO format
"""

import re
import unicodedata
from typing import Dict, List, Optional, Tuple, Any
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone
import logging

from app.core.settings import settings

logger = logging.getLogger(__name__)


class DataNormalizer:
    """Service for normalizing incoming data to canonical formats"""
    
    def __init__(self):
        self.unit_synonyms = self._load_unit_synonyms()
        self.fraction_patterns = self._compile_fraction_patterns()
    
    def _load_unit_synonyms(self) -> Dict[str, str]:
        """Load unit synonyms mapping to canonical names"""
        return {
            # Mass units
            'g': 'gram',
            'gr': 'gram',
            'gram': 'gram',
            'kg': 'kilogram',
            'kilo': 'kilogram',
            'kilogram': 'kilogram',
            'oz': 'ounce',
            'ounce': 'ounce',
            'lb': 'pound',
            'lbs': 'pound',
            'pound': 'pound',
            
            # Volume units
            'ml': 'milliliter',
            'milliliter': 'milliliter',
            'l': 'liter',
            'liter': 'liter',
            'litre': 'liter',
            'dl': 'deciliter',
            'deciliter': 'deciliter',
            
            # US/Imperial volume
            'tsp': 'teaspoon',
            't': 'teaspoon',
            'teaspoon': 'teaspoon',
            'tbsp': 'tablespoon',
            'T': 'tablespoon',
            'tablespoon': 'tablespoon',
            'cup': 'cup',
            'c': 'cup',
            'fl oz': 'fluid ounce',
            'fl. oz': 'fluid ounce',
            'fluid ounce': 'fluid ounce',
            'fluid ounces': 'fluid ounce',
            'pt': 'pint',
            'pint': 'pint',
            'pints': 'pint',
            'qt': 'quart',
            'quart': 'quart',
            'quarts': 'quart',
            'gal': 'gallon',
            'gallon': 'gallon',
            'gallons': 'gallon',
            
            # Count units
            'pc': 'piece',
            'piece': 'piece',
            'pieces': 'piece',
            'pcs': 'piece',
            'each': 'piece',
            'item': 'piece',
            'items': 'piece',
            'dozen': 'dozen',
            'dz': 'dozen',
            
            # Special cases
            'q.b.': 'piece',  # Italian "quanto basta" (as needed)
            'to taste': 'piece',
            'as needed': 'piece',
            'pinch': 'piece',
            'dash': 'piece',
            'splash': 'piece',
        }
    
    def _compile_fraction_patterns(self) -> List[re.Pattern]:
        """Compile regex patterns for fraction detection"""
        return [
            re.compile(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$'),  # 1 1/2, 2 3/4, etc. (mixed numbers first)
            re.compile(r'^(\d+)\s*/\s*(\d+)$'),  # 1/2, 3/4, etc. (simple fractions)
        ]
    
    def normalize_text(self, text: str, target_language: str = None) -> str:
        """Normalize text to canonical format"""
        if not text:
            return ""
        
        target_language = target_language or settings.default_locale
        
        # Normalize Unicode (NFC form)
        text = unicodedata.normalize('NFC', text)
        
        # Basic cleanup
        text = text.strip()
        
        # TODO: Add translation service integration here
        # For now, just return cleaned text
        return text
    
    def normalize_amount(self, amount_str: str) -> Tuple[Decimal, str]:
        """
        Normalize amount string to decimal and detect issues
        
        Returns:
            Tuple of (normalized_amount, issues_found)
        """
        if not amount_str:
            return Decimal('0'), "empty_amount"
        
        amount_str = str(amount_str).strip().lower()
        issues = []
        
        # Handle fractions - check mixed numbers first, then simple fractions
        for pattern in self.fraction_patterns:
            match = pattern.match(amount_str)
            if match:
                if len(match.groups()) == 3:  # Mixed number like 1 1/2
                    whole, numerator, denominator = match.groups()
                    decimal_value = Decimal(whole) + (Decimal(numerator) / Decimal(denominator))
                    return decimal_value, ""
                elif len(match.groups()) == 2:  # Simple fraction like 1/2
                    numerator, denominator = match.groups()
                    decimal_value = Decimal(numerator) / Decimal(denominator)
                    return decimal_value, ""
        
        # Remove common non-numeric characters (but preserve minus sign)
        cleaned = re.sub(r'[^\d.,-]', '', amount_str)
        
        # Handle different decimal separators
        if ',' in cleaned and '.' in cleaned:
            # Assume European format: 1.234,56
            cleaned = cleaned.replace('.', '').replace(',', '.')
            issues.append("european_decimal_format")
        elif ',' in cleaned:
            # Could be decimal separator or thousands separator
            if cleaned.count(',') == 1 and len(cleaned.split(',')[1]) <= 2:
                # Likely decimal separator
                cleaned = cleaned.replace(',', '.')
                issues.append("comma_decimal_separator")
            else:
                # Likely thousands separator
                cleaned = cleaned.replace(',', '')
                issues.append("comma_thousands_separator")
        
        try:
            decimal_value = Decimal(cleaned)
            if decimal_value < 0:
                issues.append("negative_amount")
            return decimal_value, "|".join(issues) if issues else ""
        except (InvalidOperation, ValueError):
            logger.warning(f"Could not parse amount: {amount_str}")
            return Decimal('0'), f"parse_error|{amount_str}"
    
    def normalize_unit(self, unit_str: str) -> Tuple[str, str]:
        """
        Normalize unit string to canonical unit name
        
        Returns:
            Tuple of (canonical_unit_name, issues_found)
        """
        if not unit_str:
            return "piece", "missing_unit"
        
        unit_str = unit_str.strip().lower()

        # Check direct mapping first (before removing periods)
        if unit_str in self.unit_synonyms:
            return self.unit_synonyms[unit_str], ""

        # Remove periods and extra spaces
        unit_str_cleaned = re.sub(r'\.+', '', unit_str)
        unit_str_cleaned = re.sub(r'\s+', ' ', unit_str_cleaned).strip()

        # Check mapping after cleaning
        if unit_str_cleaned in self.unit_synonyms:
            return self.unit_synonyms[unit_str_cleaned], ""
        
        # Try without 's' (plural) - use cleaned version
        if unit_str_cleaned.endswith('s') and len(unit_str_cleaned) > 1:
            singular = unit_str_cleaned[:-1]
            if singular in self.unit_synonyms:
                return self.unit_synonyms[singular], "plural_form"
        
        # Log unknown unit for future mapping
        logger.info(f"Unknown unit encountered: {unit_str}")
        return unit_str, f"unknown_unit|{unit_str}"
    
    def normalize_ingredient_name(self, name: str, language: str = None) -> Tuple[str, str]:
        """
        Normalize ingredient name to canonical English format
        
        Returns:
            Tuple of (canonical_name, issues_found)
        """
        if not name:
            return "", "empty_name"
        
        language = language or settings.default_locale
        issues = []
        
        # Basic text normalization
        canonical_name = self.normalize_text(name, 'en')
        
        # Remove common cooking preparation terms from ingredient name
        prep_terms = [
            'chopped', 'diced', 'minced', 'sliced', 'grated', 'shredded',
            'fresh', 'dried', 'frozen', 'canned', 'cooked', 'raw',
            'large', 'medium', 'small', 'extra large',
            'organic', 'free-range', 'grass-fed'
        ]
        
        original_name = canonical_name
        for term in prep_terms:
            pattern = rf'\b{term}\b'
            if re.search(pattern, canonical_name, re.IGNORECASE):
                canonical_name = re.sub(pattern, '', canonical_name, flags=re.IGNORECASE)
                issues.append(f"removed_prep_term_{term}")
        
        # Clean up extra spaces
        canonical_name = re.sub(r'\s+', ' ', canonical_name).strip()
        
        # Capitalize properly
        canonical_name = canonical_name.title()

        # Only mark as modified if there were actual changes beyond capitalization
        if canonical_name.lower() != name.lower().strip():
            issues.append("name_modified")

        return canonical_name, "|".join(issues) if issues else ""
    
    def normalize_recipe_data(self, recipe_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normalize entire recipe data structure
        
        Args:
            recipe_data: Raw recipe data dictionary
            
        Returns:
            Normalized recipe data with canonical fields
        """
        normalized = recipe_data.copy()
        
        # Normalize text fields
        if 'title' in normalized:
            normalized['title_en'] = self.normalize_text(normalized['title'], 'en')
        
        if 'description' in normalized:
            normalized['description_en'] = self.normalize_text(normalized['description'], 'en')
        
        if 'instructions' in normalized:
            normalized['instructions_en'] = [
                self.normalize_text(instruction, 'en') 
                for instruction in normalized['instructions']
            ]
        
        # Normalize ingredients
        if 'ingredients' in normalized:
            normalized_ingredients = []
            for ingredient in normalized['ingredients']:
                norm_ingredient = self._normalize_ingredient_data(ingredient)
                normalized_ingredients.append(norm_ingredient)
            normalized['ingredients'] = normalized_ingredients
        
        # Add metadata
        normalized['normalization_applied'] = True
        normalized['normalized_at'] = datetime.now(timezone.utc).isoformat()
        
        return normalized
    
    def _normalize_ingredient_data(self, ingredient: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize individual ingredient data"""
        normalized = ingredient.copy()
        
        # Normalize amount
        if 'amount' in ingredient:
            amount, amount_issues = self.normalize_amount(str(ingredient['amount']))
            normalized['amount_canonical'] = float(amount)
            if amount_issues:
                normalized['amount_normalization_issues'] = amount_issues
        
        # Normalize unit
        if 'unit' in ingredient:
            unit, unit_issues = self.normalize_unit(ingredient['unit'])
            normalized['unit_canonical'] = unit
            if unit_issues:
                normalized['unit_normalization_issues'] = unit_issues
        
        # Normalize ingredient name
        if 'name' in ingredient:
            name, name_issues = self.normalize_ingredient_name(ingredient['name'])
            normalized['name_en'] = name
            if name_issues:
                normalized['name_normalization_issues'] = name_issues
        
        return normalized


# Global instance
data_normalizer = DataNormalizer()
