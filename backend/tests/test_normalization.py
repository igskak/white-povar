"""
Tests for data normalization service

Tests the normalization of ingredients, units, amounts, and text content
"""

import pytest
from decimal import Decimal
from app.services.normalization import DataNormalizer


class TestDataNormalizer:
    """Test suite for DataNormalizer"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.normalizer = DataNormalizer()
    
    def test_normalize_amount_simple_decimal(self):
        """Test normalization of simple decimal amounts"""
        amount, issues = self.normalizer.normalize_amount("2.5")
        assert amount == Decimal("2.5")
        assert issues == ""
    
    def test_normalize_amount_integer(self):
        """Test normalization of integer amounts"""
        amount, issues = self.normalizer.normalize_amount("3")
        assert amount == Decimal("3")
        assert issues == ""
    
    def test_normalize_amount_fraction(self):
        """Test normalization of fraction amounts"""
        amount, issues = self.normalizer.normalize_amount("1/2")
        assert amount == Decimal("0.5")
        assert issues == ""
        
        amount, issues = self.normalizer.normalize_amount("3/4")
        assert amount == Decimal("0.75")
        assert issues == ""
    
    def test_normalize_amount_mixed_fraction(self):
        """Test normalization of mixed number fractions"""
        amount, issues = self.normalizer.normalize_amount("1 1/2")
        assert amount == Decimal("1.5")
        assert issues == ""
        
        amount, issues = self.normalizer.normalize_amount("2 3/4")
        assert amount == Decimal("2.75")
        assert issues == ""
    
    def test_normalize_amount_european_decimal(self):
        """Test normalization of European decimal format"""
        amount, issues = self.normalizer.normalize_amount("2,5")
        assert amount == Decimal("2.5")
        assert "comma_decimal_separator" in issues
    
    def test_normalize_amount_thousands_separator(self):
        """Test normalization with thousands separators"""
        amount, issues = self.normalizer.normalize_amount("1,000")
        assert amount == Decimal("1000")
        assert "comma_thousands_separator" in issues
    
    def test_normalize_amount_invalid(self):
        """Test handling of invalid amounts"""
        amount, issues = self.normalizer.normalize_amount("invalid")
        assert amount == Decimal("0")
        assert "parse_error" in issues
    
    def test_normalize_amount_empty(self):
        """Test handling of empty amounts"""
        amount, issues = self.normalizer.normalize_amount("")
        assert amount == Decimal("0")
        assert issues == "empty_amount"
    
    def test_normalize_unit_common_abbreviations(self):
        """Test normalization of common unit abbreviations"""
        test_cases = [
            ("g", "gram"),
            ("kg", "kilogram"),
            ("ml", "milliliter"),
            ("l", "liter"),
            ("tsp", "teaspoon"),
            ("tbsp", "tablespoon"),
            ("cup", "cup"),
            ("oz", "ounce"),
            ("lb", "pound"),
        ]
        
        for input_unit, expected in test_cases:
            unit, issues = self.normalizer.normalize_unit(input_unit)
            assert unit == expected, f"Expected {expected} for {input_unit}, got {unit}"
            assert issues == ""
    
    def test_normalize_unit_plural_forms(self):
        """Test normalization of plural unit forms"""
        test_cases = [
            ("grams", "gram"),
            ("teaspoons", "teaspoon"),
            ("cups", "cup"),
            ("ounces", "ounce"),
        ]
        
        for input_unit, expected in test_cases:
            unit, issues = self.normalizer.normalize_unit(input_unit)
            assert unit == expected
            assert "plural_form" in issues
    
    def test_normalize_unit_with_periods(self):
        """Test normalization of units with periods"""
        unit, issues = self.normalizer.normalize_unit("fl. oz")
        assert unit == "fluid ounce"
        assert issues == ""
    
    def test_normalize_unit_special_cases(self):
        """Test normalization of special unit cases"""
        test_cases = [
            ("q.b.", "piece"),
            ("to taste", "piece"),
            ("pinch", "piece"),
            ("dash", "piece"),
        ]
        
        for input_unit, expected in test_cases:
            unit, issues = self.normalizer.normalize_unit(input_unit)
            assert unit == expected
    
    def test_normalize_unit_unknown(self):
        """Test handling of unknown units"""
        unit, issues = self.normalizer.normalize_unit("unknown_unit")
        assert unit == "unknown_unit"
        assert "unknown_unit" in issues
    
    def test_normalize_ingredient_name_basic(self):
        """Test basic ingredient name normalization"""
        name, issues = self.normalizer.normalize_ingredient_name("tomato")
        assert name == "Tomato"
        assert issues == ""
    
    def test_normalize_ingredient_name_with_prep_terms(self):
        """Test ingredient name normalization with preparation terms"""
        name, issues = self.normalizer.normalize_ingredient_name("chopped onion")
        assert "Onion" in name
        assert "removed_prep_term_chopped" in issues
        
        name, issues = self.normalizer.normalize_ingredient_name("fresh basil leaves")
        assert "Basil Leaves" in name
        assert "removed_prep_term_fresh" in issues
    
    def test_normalize_ingredient_name_multiple_prep_terms(self):
        """Test ingredient name with multiple preparation terms"""
        name, issues = self.normalizer.normalize_ingredient_name("fresh chopped organic tomatoes")
        assert "Tomatoes" in name
        assert "removed_prep_term_fresh" in issues
        assert "removed_prep_term_chopped" in issues
        assert "removed_prep_term_organic" in issues
    
    def test_normalize_ingredient_name_empty(self):
        """Test handling of empty ingredient names"""
        name, issues = self.normalizer.normalize_ingredient_name("")
        assert name == ""
        assert issues == "empty_name"
    
    def test_normalize_recipe_data_complete(self):
        """Test normalization of complete recipe data"""
        recipe_data = {
            "title": "Test Recipe",
            "description": "A test recipe for validation",
            "instructions": ["Step 1", "Step 2"],
            "ingredients": [
                {
                    "name": "chopped tomatoes",
                    "amount": "2.5",
                    "unit": "cups",
                    "notes": "fresh"
                },
                {
                    "name": "olive oil",
                    "amount": "1/4",
                    "unit": "cup"
                }
            ]
        }
        
        normalized = self.normalizer.normalize_recipe_data(recipe_data)
        
        # Check recipe-level normalization
        assert normalized["title_en"] == "Test Recipe"
        assert normalized["description_en"] == "A test recipe for validation"
        assert normalized["instructions_en"] == ["Step 1", "Step 2"]
        assert normalized["normalization_applied"] is True
        assert "normalized_at" in normalized
        
        # Check ingredient normalization
        ingredients = normalized["ingredients"]
        assert len(ingredients) == 2
        
        # First ingredient
        first_ingredient = ingredients[0]
        assert "Tomatoes" in first_ingredient["name_en"]
        assert first_ingredient["amount_canonical"] == 2.5
        assert first_ingredient["unit_canonical"] == "cup"
        
        # Second ingredient
        second_ingredient = ingredients[1]
        assert second_ingredient["name_en"] == "Olive Oil"
        assert second_ingredient["amount_canonical"] == 0.25
        assert second_ingredient["unit_canonical"] == "cup"
    
    def test_normalize_text_basic(self):
        """Test basic text normalization"""
        text = self.normalizer.normalize_text("  Test Text  ")
        assert text == "Test Text"
    
    def test_normalize_text_unicode(self):
        """Test Unicode normalization"""
        # Test with accented characters
        text = self.normalizer.normalize_text("café")
        assert text == "café"  # Should be normalized to NFC form
    
    def test_normalize_text_empty(self):
        """Test empty text normalization"""
        text = self.normalizer.normalize_text("")
        assert text == ""
        
        text = self.normalizer.normalize_text(None)
        assert text == ""


class TestNormalizationEdgeCases:
    """Test edge cases and error conditions"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.normalizer = DataNormalizer()
    
    def test_normalize_amount_very_large_numbers(self):
        """Test normalization of very large numbers"""
        amount, issues = self.normalizer.normalize_amount("1000000")
        assert amount == Decimal("1000000")
        assert issues == ""
    
    def test_normalize_amount_very_small_numbers(self):
        """Test normalization of very small numbers"""
        amount, issues = self.normalizer.normalize_amount("0.001")
        assert amount == Decimal("0.001")
        assert issues == ""
    
    def test_normalize_amount_negative_numbers(self):
        """Test handling of negative numbers"""
        amount, issues = self.normalizer.normalize_amount("-5")
        assert amount == Decimal("-5")
        assert "negative_amount" in issues
    
    def test_normalize_amount_complex_european_format(self):
        """Test complex European number format"""
        amount, issues = self.normalizer.normalize_amount("1.234,56")
        assert amount == Decimal("1234.56")
        assert "european_decimal_format" in issues
    
    def test_normalize_unit_case_insensitive(self):
        """Test that unit normalization is case insensitive"""
        test_cases = [
            ("G", "gram"),
            ("ML", "milliliter"),
            ("TSP", "teaspoon"),
            ("Cup", "cup"),
        ]
        
        for input_unit, expected in test_cases:
            unit, issues = self.normalizer.normalize_unit(input_unit)
            assert unit == expected
    
    def test_normalize_ingredient_name_case_handling(self):
        """Test proper case handling in ingredient names"""
        name, issues = self.normalizer.normalize_ingredient_name("TOMATO")
        assert name == "Tomato"
        
        name, issues = self.normalizer.normalize_ingredient_name("olive oil")
        assert name == "Olive Oil"
    
    def test_normalize_ingredient_name_extra_whitespace(self):
        """Test handling of extra whitespace in ingredient names"""
        name, issues = self.normalizer.normalize_ingredient_name("  fresh   basil   leaves  ")
        assert "Basil Leaves" in name
        assert "removed_prep_term_fresh" in issues


class TestNormalizationIntegration:
    """Integration tests for normalization with real-world data"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.normalizer = DataNormalizer()
    
    def test_italian_recipe_normalization(self):
        """Test normalization of Italian recipe data"""
        recipe_data = {
            "title": "Pasta con Pomodori",
            "description": "Una ricetta tradizionale italiana",
            "ingredients": [
                {
                    "name": "Pomodorini rossi e gialli",
                    "amount": "200",
                    "unit": "g"
                },
                {
                    "name": "Olio extravergine d'oliva",
                    "amount": "50",
                    "unit": "ml"
                }
            ]
        }
        
        normalized = self.normalizer.normalize_recipe_data(recipe_data)
        
        # Should preserve original and create English versions
        assert normalized["title"] == "Pasta con Pomodori"
        assert normalized["title_en"] == "Pasta con Pomodori"  # Would be translated in real implementation
        
        # Ingredients should be normalized
        ingredients = normalized["ingredients"]
        assert len(ingredients) == 2
        
        first_ingredient = ingredients[0]
        assert first_ingredient["amount_canonical"] == 200.0
        assert first_ingredient["unit_canonical"] == "gram"
    
    def test_mixed_unit_systems_normalization(self):
        """Test normalization of recipe with mixed unit systems"""
        recipe_data = {
            "title": "Mixed Units Recipe",
            "ingredients": [
                {"name": "flour", "amount": "2", "unit": "cups"},
                {"name": "butter", "amount": "100", "unit": "g"},
                {"name": "milk", "amount": "1", "unit": "cup"},
                {"name": "salt", "amount": "1", "unit": "tsp"}
            ]
        }
        
        normalized = self.normalizer.normalize_recipe_data(recipe_data)
        ingredients = normalized["ingredients"]
        
        # All should have canonical units
        for ingredient in ingredients:
            assert "amount_canonical" in ingredient
            assert "unit_canonical" in ingredient
            assert ingredient["amount_canonical"] > 0


if __name__ == "__main__":
    pytest.main([__file__])
