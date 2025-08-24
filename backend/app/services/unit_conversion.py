"""
Unit Conversion Service

Handles conversion between different unit systems:
- Metric ↔ Imperial ↔ US customary
- Mass ↔ Volume (using ingredient density)
- Temperature conversions
- Scaling recipes up/down
"""

from typing import Dict, Optional, Tuple, List
from decimal import Decimal, ROUND_HALF_UP
from dataclasses import dataclass
import logging

from app.core.settings import settings

logger = logging.getLogger(__name__)


@dataclass
class Unit:
    """Unit definition with conversion information"""
    name: str
    abbreviation: str
    unit_type: str  # 'mass', 'volume', 'count', 'temperature'
    system: str     # 'metric', 'imperial', 'us'
    base_factor: Decimal  # Factor to convert to base unit
    is_base: bool = False


@dataclass
class ConversionResult:
    """Result of unit conversion"""
    amount: Decimal
    unit: str
    original_amount: Decimal
    original_unit: str
    conversion_factor: Decimal
    precision_lost: bool = False
    notes: Optional[str] = None


class UnitConverter:
    """Service for converting between different units"""
    
    def __init__(self):
        self.units = self._load_units()
        self.ingredient_densities = self._load_ingredient_densities()
    
    def _load_units(self) -> Dict[str, Unit]:
        """Load unit definitions with conversion factors"""
        units = {}
        
        # Mass units (base: gram)
        units['gram'] = Unit('gram', 'g', 'mass', 'metric', Decimal('1'), True)
        units['kilogram'] = Unit('kilogram', 'kg', 'mass', 'metric', Decimal('1000'))
        units['milligram'] = Unit('milligram', 'mg', 'mass', 'metric', Decimal('0.001'))
        units['ounce'] = Unit('ounce', 'oz', 'mass', 'imperial', Decimal('28.3495'))
        units['pound'] = Unit('pound', 'lb', 'mass', 'imperial', Decimal('453.592'))
        
        # Volume units (base: milliliter)
        units['milliliter'] = Unit('milliliter', 'ml', 'volume', 'metric', Decimal('1'), True)
        units['liter'] = Unit('liter', 'l', 'volume', 'metric', Decimal('1000'))
        units['deciliter'] = Unit('deciliter', 'dl', 'volume', 'metric', Decimal('100'))
        
        # US volume units
        units['teaspoon'] = Unit('teaspoon', 'tsp', 'volume', 'us', Decimal('4.92892'))
        units['tablespoon'] = Unit('tablespoon', 'tbsp', 'volume', 'us', Decimal('14.7868'))
        units['fluid ounce'] = Unit('fluid ounce', 'fl oz', 'volume', 'us', Decimal('29.5735'))
        units['cup'] = Unit('cup', 'cup', 'volume', 'us', Decimal('236.588'))
        units['pint'] = Unit('pint', 'pt', 'volume', 'us', Decimal('473.176'))
        units['quart'] = Unit('quart', 'qt', 'volume', 'us', Decimal('946.353'))
        units['gallon'] = Unit('gallon', 'gal', 'volume', 'us', Decimal('3785.41'))
        
        # Count units (base: piece)
        units['piece'] = Unit('piece', 'pc', 'count', 'metric', Decimal('1'), True)
        units['dozen'] = Unit('dozen', 'dz', 'count', 'metric', Decimal('12'))
        
        return units
    
    def _load_ingredient_densities(self) -> Dict[str, Decimal]:
        """Load ingredient densities for volume/mass conversion (g/ml)"""
        return {
            # Common cooking ingredients
            'water': Decimal('1.0'),
            'milk': Decimal('1.03'),
            'cream': Decimal('0.994'),
            'oil': Decimal('0.92'),
            'olive oil': Decimal('0.915'),
            'butter': Decimal('0.911'),
            'honey': Decimal('1.4'),
            'sugar': Decimal('0.845'),
            'flour': Decimal('0.593'),
            'salt': Decimal('2.16'),
            'rice': Decimal('0.753'),
            'pasta': Decimal('0.6'),
            
            # Default for unknown ingredients
            'default': Decimal('1.0'),
        }
    
    def convert_units(self, amount: Decimal, from_unit: str, to_unit: str, 
                     ingredient_name: Optional[str] = None) -> ConversionResult:
        """
        Convert amount from one unit to another
        
        Args:
            amount: Amount to convert
            from_unit: Source unit name
            to_unit: Target unit name
            ingredient_name: Ingredient name for density-based conversions
            
        Returns:
            ConversionResult with converted amount and metadata
        """
        if from_unit == to_unit:
            return ConversionResult(
                amount=amount,
                unit=to_unit,
                original_amount=amount,
                original_unit=from_unit,
                conversion_factor=Decimal('1')
            )
        
        from_unit_def = self.units.get(from_unit)
        to_unit_def = self.units.get(to_unit)
        
        if not from_unit_def or not to_unit_def:
            raise ValueError(f"Unknown unit: {from_unit if not from_unit_def else to_unit}")
        
        # Same unit type - direct conversion
        if from_unit_def.unit_type == to_unit_def.unit_type:
            return self._convert_same_type(amount, from_unit_def, to_unit_def)
        
        # Different unit types - need ingredient density
        if ingredient_name and self._can_convert_via_density(from_unit_def, to_unit_def):
            return self._convert_via_density(amount, from_unit_def, to_unit_def, ingredient_name)
        
        raise ValueError(f"Cannot convert {from_unit} to {to_unit} without ingredient density")
    
    def _convert_same_type(self, amount: Decimal, from_unit: Unit, to_unit: Unit) -> ConversionResult:
        """Convert between units of the same type"""
        # Convert to base unit first
        base_amount = amount * from_unit.base_factor
        
        # Convert from base unit to target unit
        target_amount = base_amount / to_unit.base_factor
        
        conversion_factor = from_unit.base_factor / to_unit.base_factor
        
        return ConversionResult(
            amount=target_amount,
            unit=to_unit.name,
            original_amount=amount,
            original_unit=from_unit.name,
            conversion_factor=conversion_factor
        )
    
    def _can_convert_via_density(self, from_unit: Unit, to_unit: Unit) -> bool:
        """Check if units can be converted using ingredient density"""
        mass_volume_types = {'mass', 'volume'}
        return {from_unit.unit_type, to_unit.unit_type} == mass_volume_types
    
    def _convert_via_density(self, amount: Decimal, from_unit: Unit, to_unit: Unit, 
                           ingredient_name: str) -> ConversionResult:
        """Convert between mass and volume using ingredient density"""
        density = self._get_ingredient_density(ingredient_name)
        
        # Convert to base units first
        if from_unit.unit_type == 'mass':
            # Mass to volume: grams → ml
            base_grams = amount * from_unit.base_factor
            base_ml = base_grams / density
            target_amount = base_ml / to_unit.base_factor
        else:
            # Volume to mass: ml → grams
            base_ml = amount * from_unit.base_factor
            base_grams = base_ml * density
            target_amount = base_grams / to_unit.base_factor
        
        return ConversionResult(
            amount=target_amount,
            unit=to_unit.name,
            original_amount=amount,
            original_unit=from_unit.name,
            conversion_factor=density if from_unit.unit_type == 'volume' else Decimal('1') / density,
            notes=f"Used density: {density} g/ml for {ingredient_name}"
        )
    
    def _get_ingredient_density(self, ingredient_name: str) -> Decimal:
        """Get density for ingredient, with fallback to default"""
        ingredient_lower = ingredient_name.lower()
        
        # Try exact match first
        if ingredient_lower in self.ingredient_densities:
            return self.ingredient_densities[ingredient_lower]
        
        # Try partial matches
        for key, density in self.ingredient_densities.items():
            if key in ingredient_lower or ingredient_lower in key:
                return density
        
        # Use default density
        logger.info(f"Using default density for unknown ingredient: {ingredient_name}")
        return self.ingredient_densities['default']
    
    def convert_to_metric(self, amount: Decimal, unit: str, 
                         ingredient_name: Optional[str] = None) -> ConversionResult:
        """Convert any unit to metric equivalent"""
        unit_def = self.units.get(unit)
        if not unit_def:
            raise ValueError(f"Unknown unit: {unit}")
        
        if unit_def.system == 'metric':
            return ConversionResult(
                amount=amount,
                unit=unit,
                original_amount=amount,
                original_unit=unit,
                conversion_factor=Decimal('1')
            )
        
        # Determine target metric unit
        if unit_def.unit_type == 'mass':
            target_unit = 'gram' if amount * unit_def.base_factor < 1000 else 'kilogram'
        elif unit_def.unit_type == 'volume':
            target_unit = 'milliliter' if amount * unit_def.base_factor < 1000 else 'liter'
        else:
            target_unit = 'piece'
        
        return self.convert_units(amount, unit, target_unit, ingredient_name)
    
    def convert_to_system(self, amount: Decimal, unit: str, target_system: str,
                         ingredient_name: Optional[str] = None) -> ConversionResult:
        """Convert to specified unit system (metric, imperial, us)"""
        if target_system == 'metric':
            return self.convert_to_metric(amount, unit, ingredient_name)
        
        unit_def = self.units.get(unit)
        if not unit_def:
            raise ValueError(f"Unknown unit: {unit}")
        
        if unit_def.system == target_system:
            return ConversionResult(
                amount=amount,
                unit=unit,
                original_amount=amount,
                original_unit=unit,
                conversion_factor=Decimal('1')
            )
        
        # Find appropriate target unit in the target system
        target_units = [u for u in self.units.values() 
                       if u.system == target_system and u.unit_type == unit_def.unit_type]
        
        if not target_units:
            raise ValueError(f"No {unit_def.unit_type} units available in {target_system} system")
        
        # Choose the most appropriate unit based on amount
        base_amount = amount * unit_def.base_factor
        best_unit = min(target_units, key=lambda u: abs(base_amount / u.base_factor - 1))
        
        return self.convert_units(amount, unit, best_unit.name, ingredient_name)
    
    def scale_recipe(self, ingredients: List[Dict], scale_factor: Decimal) -> List[Dict]:
        """Scale recipe ingredients by a factor"""
        scaled_ingredients = []
        
        for ingredient in ingredients:
            scaled = ingredient.copy()
            if 'amount' in scaled:
                original_amount = Decimal(str(scaled['amount']))
                scaled_amount = original_amount * scale_factor
                
                # Round to appropriate precision
                if scaled_amount < 1:
                    scaled_amount = scaled_amount.quantize(
                        Decimal('0.01'), rounding=ROUND_HALF_UP
                    )
                elif scaled_amount < 10:
                    scaled_amount = scaled_amount.quantize(
                        Decimal('0.1'), rounding=ROUND_HALF_UP
                    )
                else:
                    scaled_amount = scaled_amount.quantize(
                        Decimal('1'), rounding=ROUND_HALF_UP
                    )
                
                scaled['amount'] = float(scaled_amount)
                scaled['scale_factor'] = float(scale_factor)
            
            scaled_ingredients.append(scaled)
        
        return scaled_ingredients
    
    def format_amount(self, amount: Decimal, unit: str, 
                     precision: Optional[int] = None) -> str:
        """Format amount with appropriate precision for display"""
        if precision is None:
            precision = settings.ingredient_round_decimals
        
        # Round to specified precision
        rounded = amount.quantize(
            Decimal('0.1') ** precision, 
            rounding=ROUND_HALF_UP
        )
        
        # Remove trailing zeros
        formatted = f"{rounded:.{precision}f}".rstrip('0').rstrip('.')
        
        # Handle special cases
        if formatted == '0':
            formatted = '0'
        
        unit_def = self.units.get(unit)
        unit_abbrev = unit_def.abbreviation if unit_def else unit
        
        return f"{formatted} {unit_abbrev}"


# Global instance
unit_converter = UnitConverter()
