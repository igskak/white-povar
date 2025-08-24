"""
Tests for unit conversion service

Tests conversion between different unit systems and scaling operations
"""

import pytest
from decimal import Decimal
from app.services.unit_conversion import UnitConverter, ConversionResult


class TestUnitConverter:
    """Test suite for UnitConverter"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.converter = UnitConverter()
    
    def test_same_unit_conversion(self):
        """Test conversion between same units"""
        result = self.converter.convert_units(
            Decimal("5"), "gram", "gram"
        )
        assert result.amount == Decimal("5")
        assert result.unit == "gram"
        assert result.conversion_factor == Decimal("1")
    
    def test_metric_mass_conversion(self):
        """Test conversion between metric mass units"""
        # Grams to kilograms
        result = self.converter.convert_units(
            Decimal("1000"), "gram", "kilogram"
        )
        assert result.amount == Decimal("1")
        assert result.unit == "kilogram"
        
        # Kilograms to grams
        result = self.converter.convert_units(
            Decimal("2"), "kilogram", "gram"
        )
        assert result.amount == Decimal("2000")
        assert result.unit == "gram"
        
        # Milligrams to grams
        result = self.converter.convert_units(
            Decimal("500"), "milligram", "gram"
        )
        assert result.amount == Decimal("0.5")
        assert result.unit == "gram"
    
    def test_metric_volume_conversion(self):
        """Test conversion between metric volume units"""
        # Milliliters to liters
        result = self.converter.convert_units(
            Decimal("1000"), "milliliter", "liter"
        )
        assert result.amount == Decimal("1")
        assert result.unit == "liter"
        
        # Liters to milliliters
        result = self.converter.convert_units(
            Decimal("1.5"), "liter", "milliliter"
        )
        assert result.amount == Decimal("1500")
        assert result.unit == "milliliter"
        
        # Deciliters to milliliters
        result = self.converter.convert_units(
            Decimal("2"), "deciliter", "milliliter"
        )
        assert result.amount == Decimal("200")
        assert result.unit == "milliliter"
    
    def test_us_volume_conversion(self):
        """Test conversion between US volume units"""
        # Teaspoons to tablespoons
        result = self.converter.convert_units(
            Decimal("3"), "teaspoon", "tablespoon"
        )
        assert abs(result.amount - Decimal("1")) < Decimal("0.01")
        assert result.unit == "tablespoon"
        
        # Cups to fluid ounces
        result = self.converter.convert_units(
            Decimal("1"), "cup", "fluid ounce"
        )
        assert abs(result.amount - Decimal("8")) < Decimal("0.1")
        assert result.unit == "fluid ounce"
    
    def test_imperial_mass_conversion(self):
        """Test conversion between imperial mass units"""
        # Ounces to pounds
        result = self.converter.convert_units(
            Decimal("16"), "ounce", "pound"
        )
        assert abs(result.amount - Decimal("1")) < Decimal("0.01")
        assert result.unit == "pound"
        
        # Pounds to ounces
        result = self.converter.convert_units(
            Decimal("2"), "pound", "ounce"
        )
        assert abs(result.amount - Decimal("32")) < Decimal("0.1")
        assert result.unit == "ounce"
    
    def test_metric_to_imperial_conversion(self):
        """Test conversion from metric to imperial units"""
        # Grams to ounces
        result = self.converter.convert_units(
            Decimal("100"), "gram", "ounce"
        )
        assert abs(result.amount - Decimal("3.527")) < Decimal("0.01")
        assert result.unit == "ounce"
        
        # Kilograms to pounds
        result = self.converter.convert_units(
            Decimal("1"), "kilogram", "pound"
        )
        assert abs(result.amount - Decimal("2.205")) < Decimal("0.01")
        assert result.unit == "pound"
    
    def test_imperial_to_metric_conversion(self):
        """Test conversion from imperial to metric units"""
        # Ounces to grams
        result = self.converter.convert_units(
            Decimal("1"), "ounce", "gram"
        )
        assert abs(result.amount - Decimal("28.35")) < Decimal("0.1")
        assert result.unit == "gram"
        
        # Pounds to kilograms
        result = self.converter.convert_units(
            Decimal("1"), "pound", "kilogram"
        )
        assert abs(result.amount - Decimal("0.454")) < Decimal("0.01")
        assert result.unit == "kilogram"
    
    def test_us_to_metric_volume_conversion(self):
        """Test conversion from US to metric volume units"""
        # Cups to milliliters
        result = self.converter.convert_units(
            Decimal("1"), "cup", "milliliter"
        )
        assert abs(result.amount - Decimal("236.6")) < Decimal("1")
        assert result.unit == "milliliter"
        
        # Teaspoons to milliliters
        result = self.converter.convert_units(
            Decimal("1"), "teaspoon", "milliliter"
        )
        assert abs(result.amount - Decimal("4.93")) < Decimal("0.1")
        assert result.unit == "milliliter"
    
    def test_count_unit_conversion(self):
        """Test conversion of count units"""
        # Pieces to dozen
        result = self.converter.convert_units(
            Decimal("12"), "piece", "dozen"
        )
        assert result.amount == Decimal("1")
        assert result.unit == "dozen"
        
        # Dozen to pieces
        result = self.converter.convert_units(
            Decimal("2"), "dozen", "piece"
        )
        assert result.amount == Decimal("24")
        assert result.unit == "piece"
    
    def test_volume_to_mass_conversion_with_density(self):
        """Test conversion from volume to mass using ingredient density"""
        # Water: 1ml = 1g
        result = self.converter.convert_units(
            Decimal("250"), "milliliter", "gram", "water"
        )
        assert result.amount == Decimal("250")
        assert result.unit == "gram"
        assert "density" in result.notes
        
        # Oil: lighter than water
        result = self.converter.convert_units(
            Decimal("100"), "milliliter", "gram", "olive oil"
        )
        assert result.amount < Decimal("100")  # Oil is lighter than water
        assert result.unit == "gram"
    
    def test_mass_to_volume_conversion_with_density(self):
        """Test conversion from mass to volume using ingredient density"""
        # Water: 1g = 1ml
        result = self.converter.convert_units(
            Decimal("500"), "gram", "milliliter", "water"
        )
        assert result.amount == Decimal("500")
        assert result.unit == "milliliter"
        
        # Honey: denser than water
        result = self.converter.convert_units(
            Decimal("140"), "gram", "milliliter", "honey"
        )
        assert result.amount < Decimal("140")  # Honey is denser than water
        assert result.unit == "milliliter"
    
    def test_convert_to_metric_system(self):
        """Test conversion to metric system"""
        # Imperial mass to metric
        result = self.converter.convert_to_metric(
            Decimal("1"), "pound"
        )
        assert result.unit in ["gram", "kilogram"]
        assert result.amount > 0
        
        # US volume to metric
        result = self.converter.convert_to_metric(
            Decimal("1"), "cup"
        )
        assert result.unit in ["milliliter", "liter"]
        assert result.amount > 0
    
    def test_convert_to_system(self):
        """Test conversion to specific unit systems"""
        # Metric to US
        result = self.converter.convert_to_system(
            Decimal("250"), "milliliter", "us"
        )
        assert result.unit in ["teaspoon", "tablespoon", "cup", "fluid ounce"]
        
        # Metric to imperial
        result = self.converter.convert_to_system(
            Decimal("500"), "gram", "imperial"
        )
        assert result.unit in ["ounce", "pound"]
    
    def test_scale_recipe(self):
        """Test recipe scaling functionality"""
        ingredients = [
            {"name": "flour", "amount": 2, "unit": "cups"},
            {"name": "sugar", "amount": 1, "unit": "cup"},
            {"name": "eggs", "amount": 3, "unit": "piece"}
        ]
        
        # Scale up by 1.5x
        scaled = self.converter.scale_recipe(ingredients, Decimal("1.5"))
        
        assert len(scaled) == 3
        assert scaled[0]["amount"] == 3.0  # 2 * 1.5
        assert scaled[1]["amount"] == 1.5  # 1 * 1.5
        assert scaled[2]["amount"] == 4.5  # 3 * 1.5 = 4.5
        
        # Check scale factor is recorded
        for ingredient in scaled:
            assert ingredient["scale_factor"] == 1.5
    
    def test_format_amount(self):
        """Test amount formatting for display"""
        # Test basic formatting
        formatted = self.converter.format_amount(Decimal("2.5"), "cup")
        assert "2.5" in formatted
        assert "cup" in formatted
        
        # Test rounding
        formatted = self.converter.format_amount(Decimal("2.333"), "gram", precision=1)
        assert "2.3" in formatted
        assert "g" in formatted
        
        # Test whole numbers
        formatted = self.converter.format_amount(Decimal("3.0"), "piece")
        assert "3" in formatted  # Should not show .0
        assert "pc" in formatted


class TestUnitConverterEdgeCases:
    """Test edge cases and error conditions"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.converter = UnitConverter()
    
    def test_unknown_unit_conversion(self):
        """Test handling of unknown units"""
        with pytest.raises(ValueError, match="Unknown unit"):
            self.converter.convert_units(
                Decimal("1"), "unknown_unit", "gram"
            )
    
    def test_incompatible_unit_conversion_without_density(self):
        """Test conversion between incompatible units without ingredient"""
        with pytest.raises(ValueError, match="Cannot convert"):
            self.converter.convert_units(
                Decimal("1"), "gram", "milliliter"
            )
    
    def test_zero_amount_conversion(self):
        """Test conversion of zero amounts"""
        result = self.converter.convert_units(
            Decimal("0"), "gram", "kilogram"
        )
        assert result.amount == Decimal("0")
        assert result.unit == "kilogram"
    
    def test_very_small_amount_conversion(self):
        """Test conversion of very small amounts"""
        result = self.converter.convert_units(
            Decimal("0.001"), "kilogram", "gram"
        )
        assert result.amount == Decimal("1")
        assert result.unit == "gram"
    
    def test_very_large_amount_conversion(self):
        """Test conversion of very large amounts"""
        result = self.converter.convert_units(
            Decimal("1000000"), "gram", "kilogram"
        )
        assert result.amount == Decimal("1000")
        assert result.unit == "kilogram"
    
    def test_unknown_ingredient_density(self):
        """Test density lookup for unknown ingredients"""
        # Should use default density
        result = self.converter.convert_units(
            Decimal("100"), "milliliter", "gram", "unknown_ingredient"
        )
        assert result.amount == Decimal("100")  # Default density = 1.0
        assert result.unit == "gram"
    
    def test_recipe_scaling_edge_cases(self):
        """Test recipe scaling with edge cases"""
        ingredients = [
            {"name": "salt", "amount": 0.1, "unit": "tsp"},
            {"name": "flour", "amount": 1000, "unit": "g"}
        ]
        
        # Scale down significantly
        scaled = self.converter.scale_recipe(ingredients, Decimal("0.1"))
        
        # Very small amounts should be handled gracefully
        assert all(ing["amount"] > 0 for ing in scaled)
        
        # Scale up significantly
        scaled = self.converter.scale_recipe(ingredients, Decimal("10"))
        
        # Large amounts should be handled gracefully
        assert all(ing["amount"] > 0 for ing in scaled)


if __name__ == "__main__":
    pytest.main([__file__])
