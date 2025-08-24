"""
Tests for API localization features

Tests localization middleware, context parsing, and response formatting
"""

import pytest
from fastapi import Request
from fastapi.testclient import TestClient
from unittest.mock import Mock

from app.middleware.localization import LocalizationContext, ResponseLocalizer
from app.main import app


class TestLocalizationContext:
    """Test suite for LocalizationContext"""
    
    def create_mock_request(self, headers=None, query_params=None):
        """Create a mock request with specified headers and query params"""
        request = Mock(spec=Request)
        request.headers = headers or {}
        request.query_params = query_params or {}
        return request
    
    def test_default_localization_context(self):
        """Test default localization context with no headers"""
        request = self.create_mock_request()
        context = LocalizationContext(request)
        
        assert context.primary_language == "en"
        assert context.unit_system == "metric"
        assert context.currency == "EUR"
        assert context.timezone == "UTC"
    
    def test_accept_language_parsing_single(self):
        """Test parsing of single Accept-Language header"""
        request = self.create_mock_request(
            headers={"Accept-Language": "it"}
        )
        context = LocalizationContext(request)
        
        assert context.primary_language == "it"
        assert "it" in context.languages
    
    def test_accept_language_parsing_multiple(self):
        """Test parsing of multiple Accept-Language values"""
        request = self.create_mock_request(
            headers={"Accept-Language": "it,en;q=0.8,fr;q=0.6"}
        )
        context = LocalizationContext(request)
        
        assert context.primary_language == "it"
        assert context.languages == ["it", "en"]  # fr not supported
    
    def test_accept_language_parsing_with_regions(self):
        """Test parsing of Accept-Language with regions"""
        request = self.create_mock_request(
            headers={"Accept-Language": "en-US,en;q=0.9,it;q=0.8"}
        )
        context = LocalizationContext(request)
        
        assert context.primary_language == "en"
        assert "en" in context.languages
        assert "it" in context.languages
    
    def test_unit_system_from_query_param(self):
        """Test unit system preference from query parameter"""
        request = self.create_mock_request(
            query_params={"units": "imperial"}
        )
        context = LocalizationContext(request)
        
        assert context.unit_system == "imperial"
    
    def test_unit_system_from_header(self):
        """Test unit system preference from custom header"""
        request = self.create_mock_request(
            headers={"X-Unit-System": "us"}
        )
        context = LocalizationContext(request)
        
        assert context.unit_system == "us"
    
    def test_currency_from_query_param(self):
        """Test currency preference from query parameter"""
        request = self.create_mock_request(
            query_params={"currency": "usd"}
        )
        context = LocalizationContext(request)
        
        assert context.currency == "USD"
    
    def test_currency_from_header(self):
        """Test currency preference from custom header"""
        request = self.create_mock_request(
            headers={"X-Currency": "gbp"}
        )
        context = LocalizationContext(request)
        
        assert context.currency == "GBP"
    
    def test_timezone_from_header(self):
        """Test timezone preference from header"""
        request = self.create_mock_request(
            headers={"X-Timezone": "Europe/Rome"}
        )
        context = LocalizationContext(request)
        
        assert context.timezone == "Europe/Rome"
    
    def test_should_translate_to(self):
        """Test translation decision logic"""
        request = self.create_mock_request(
            headers={"Accept-Language": "it,en;q=0.8"}
        )
        context = LocalizationContext(request)
        
        assert context.should_translate_to("it") is True
        assert context.should_translate_to("en") is False  # Default language
        assert context.should_translate_to("fr") is False  # Not requested
    
    def test_get_preferred_language(self):
        """Test preferred language selection from available options"""
        request = self.create_mock_request(
            headers={"Accept-Language": "it,en;q=0.8,fr;q=0.6"}
        )
        context = LocalizationContext(request)
        
        # Should prefer Italian if available
        preferred = context.get_preferred_language(["en", "it", "de"])
        assert preferred == "it"
        
        # Should fall back to English if Italian not available
        preferred = context.get_preferred_language(["en", "de", "fr"])
        assert preferred == "en"
        
        # Should fall back to default if none available
        preferred = context.get_preferred_language(["de", "fr", "es"])
        assert preferred == "en"
    
    def test_to_dict(self):
        """Test conversion to dictionary"""
        request = self.create_mock_request(
            headers={
                "Accept-Language": "it,en;q=0.8",
                "X-Unit-System": "metric",
                "X-Currency": "EUR"
            }
        )
        context = LocalizationContext(request)
        
        result = context.to_dict()
        
        assert result["primary_language"] == "it"
        assert result["unit_system"] == "metric"
        assert result["currency"] == "EUR"
        assert result["timezone"] == "UTC"
        assert isinstance(result["languages"], list)


class TestResponseLocalizer:
    """Test suite for ResponseLocalizer"""
    
    def create_context(self, language="en", unit_system="metric", currency="EUR"):
        """Create a localization context for testing"""
        request = Mock(spec=Request)
        request.headers = {
            "Accept-Language": language,
            "X-Unit-System": unit_system,
            "X-Currency": currency
        }
        request.query_params = {}
        return LocalizationContext(request)
    
    def test_localize_recipe_english(self):
        """Test recipe localization for English"""
        context = self.create_context("en")
        localizer = ResponseLocalizer(context)
        
        recipe_data = {
            "title": "Test Recipe",
            "title_en": "Test Recipe",
            "description": "A test recipe",
            "description_en": "A test recipe"
        }
        
        localized = localizer.localize_recipe(recipe_data)
        
        assert localized["title"] == "Test Recipe"
        assert localized["description"] == "A test recipe"
        assert localized["_localization"]["language"] == "en"
        assert localized["_localization"]["unit_system"] == "metric"
    
    def test_localize_recipe_italian(self):
        """Test recipe localization for Italian"""
        context = self.create_context("it")
        localizer = ResponseLocalizer(context)
        
        recipe_data = {
            "title": "Test Recipe",
            "title_en": "Test Recipe",
            "title_it": "Ricetta di Prova",
            "description": "A test recipe",
            "description_en": "A test recipe",
            "description_it": "Una ricetta di prova"
        }
        
        localized = localizer.localize_recipe(recipe_data)
        
        assert localized["title"] == "Ricetta di Prova"
        assert localized["description"] == "Una ricetta di prova"
        assert localized["_localization"]["language"] == "it"
    
    def test_localize_recipe_fallback_to_english(self):
        """Test recipe localization fallback when translation not available"""
        context = self.create_context("it")
        localizer = ResponseLocalizer(context)
        
        recipe_data = {
            "title": "Test Recipe",
            "title_en": "Test Recipe",
            # No title_it available
            "description": "A test recipe",
            "description_en": "A test recipe"
        }
        
        localized = localizer.localize_recipe(recipe_data)
        
        # Should fall back to original/English
        assert localized["title"] == "Test Recipe"
        assert localized["description"] == "A test recipe"
    
    def test_localize_ingredient_metric_system(self):
        """Test ingredient localization with metric system"""
        context = self.create_context("en", "metric")
        localizer = ResponseLocalizer(context)
        
        ingredient_data = {
            "name": "Flour",
            "amount_canonical": 500,
            "unit_canonical": "gram",
            "amount": 500,
            "unit": "gram"
        }
        
        localized = localizer.localize_ingredient(ingredient_data)
        
        # Should keep metric units
        assert localized["amount"] == 500
        assert localized["unit"] == "gram"
        assert "_conversion_applied" not in localized
    
    def test_localize_ingredient_imperial_system(self):
        """Test ingredient localization with imperial system"""
        context = self.create_context("en", "imperial")
        localizer = ResponseLocalizer(context)
        
        ingredient_data = {
            "name": "Flour",
            "amount_canonical": 500,
            "unit_canonical": "gram",
            "amount": 500,
            "unit": "gram"
        }
        
        localized = localizer.localize_ingredient(ingredient_data)
        
        # Should convert to imperial units
        assert localized["amount"] != 500  # Should be converted
        assert localized["unit"] in ["ounce", "pound"]
        assert localized.get("_conversion_applied") is True
    
    def test_localize_ingredient_name_translation(self):
        """Test ingredient name localization"""
        context = self.create_context("it")
        localizer = ResponseLocalizer(context)
        
        ingredient_data = {
            "name": "Flour",
            "name_en": "Flour",
            "name_it": "Farina",
            "amount": 500,
            "unit": "gram"
        }
        
        localized = localizer.localize_ingredient(ingredient_data)
        
        assert localized["name"] == "Farina"
    
    def test_add_response_metadata(self):
        """Test adding localization metadata to response"""
        context = self.create_context("it", "metric", "EUR")
        localizer = ResponseLocalizer(context)
        
        response_data = {"recipes": []}
        
        result = localizer.add_response_metadata(response_data)
        
        assert "_meta" in result
        assert "localization" in result["_meta"]
        assert result["_meta"]["localization"]["primary_language"] == "it"
        assert result["_meta"]["localization"]["unit_system"] == "metric"
        assert result["_meta"]["localization"]["currency"] == "EUR"


class TestLocalizationMiddleware:
    """Test localization middleware integration"""
    
    def test_middleware_adds_localization_context(self):
        """Test that middleware adds localization context to requests"""
        client = TestClient(app)
        
        response = client.get(
            "/api/v1/config/localization",
            headers={"Accept-Language": "it,en;q=0.8"}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["current_language"] == "it"
        assert data["current_unit_system"] == "metric"
    
    def test_middleware_adds_response_headers(self):
        """Test that middleware adds localization headers to responses"""
        client = TestClient(app)
        
        response = client.get(
            "/api/v1/config/system",
            headers={
                "Accept-Language": "it",
                "X-Unit-System": "imperial",
                "X-Currency": "USD"
            }
        )
        
        assert response.status_code == 200
        
        # Check response headers
        assert response.headers.get("X-Content-Language") == "it"
        assert response.headers.get("X-Unit-System") == "imperial"
        assert response.headers.get("X-Currency") == "USD"
    
    def test_unit_conversion_query_param(self):
        """Test unit conversion via query parameter"""
        client = TestClient(app)
        
        response = client.get(
            "/api/v1/config/localization?units=us",
            headers={"Accept-Language": "en"}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["current_unit_system"] == "us"
    
    def test_unsupported_language_fallback(self):
        """Test fallback to default language for unsupported languages"""
        client = TestClient(app)
        
        response = client.get(
            "/api/v1/config/localization",
            headers={"Accept-Language": "zh,fr;q=0.8"}  # Unsupported languages
        )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should fall back to default language
        assert data["current_language"] == "en"


class TestLocalizationEdgeCases:
    """Test edge cases and error conditions"""
    
    def test_malformed_accept_language_header(self):
        """Test handling of malformed Accept-Language headers"""
        request = Mock(spec=Request)
        request.headers = {"Accept-Language": "invalid;malformed;header"}
        request.query_params = {}
        
        context = LocalizationContext(request)
        
        # Should fall back to default
        assert context.primary_language == "en"
    
    def test_empty_accept_language_header(self):
        """Test handling of empty Accept-Language header"""
        request = Mock(spec=Request)
        request.headers = {"Accept-Language": ""}
        request.query_params = {}
        
        context = LocalizationContext(request)
        
        assert context.primary_language == "en"
    
    def test_invalid_unit_system(self):
        """Test handling of invalid unit system values"""
        request = Mock(spec=Request)
        request.headers = {"X-Unit-System": "invalid"}
        request.query_params = {}
        
        context = LocalizationContext(request)
        
        # Should fall back to default
        assert context.unit_system == "metric"
    
    def test_case_insensitive_headers(self):
        """Test case insensitive header handling"""
        request = Mock(spec=Request)
        request.headers = {"X-Unit-System": "METRIC"}
        request.query_params = {"units": "IMPERIAL"}
        
        context = LocalizationContext(request)
        
        # Query param should take precedence and be normalized
        assert context.unit_system == "imperial"


if __name__ == "__main__":
    pytest.main([__file__])
