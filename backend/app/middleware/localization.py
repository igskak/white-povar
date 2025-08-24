"""
Localization Middleware

Handles request localization preferences:
- Accept-Language header parsing
- Unit system preferences
- Response formatting based on locale
"""

from typing import Optional, List, Tuple
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import re
import logging

from app.core.settings import settings

logger = logging.getLogger(__name__)


class LocalizationContext:
    """Context object for localization preferences"""
    
    def __init__(self, request: Request):
        self.request = request
        self._parse_preferences()
    
    def _parse_preferences(self):
        """Parse localization preferences from request"""
        # Parse Accept-Language header
        self.languages = self._parse_accept_language()
        self.primary_language = self.languages[0] if self.languages else settings.default_locale
        
        # Parse unit system preference
        self.unit_system = self._parse_unit_system()
        
        # Parse other preferences
        self.currency = self._parse_currency()
        self.timezone = self._parse_timezone()
    
    def _parse_accept_language(self) -> List[str]:
        """Parse Accept-Language header into ordered list of languages"""
        accept_language = self.request.headers.get('Accept-Language', '')
        
        if not accept_language:
            return [settings.default_locale]
        
        # Parse language preferences with quality values
        languages = []
        for lang_range in accept_language.split(','):
            lang_range = lang_range.strip()
            if ';q=' in lang_range:
                lang, quality = lang_range.split(';q=', 1)
                try:
                    quality = float(quality)
                except ValueError:
                    quality = 1.0
            else:
                lang = lang_range
                quality = 1.0
            
            # Extract language code (ignore region for now)
            lang_code = lang.split('-')[0].lower()
            
            # Only include supported languages
            if lang_code in settings.supported_locales_list:
                languages.append((lang_code, quality))
        
        # Sort by quality and return language codes
        languages.sort(key=lambda x: x[1], reverse=True)
        result = [lang[0] for lang in languages]
        
        # Fallback to default if no supported languages found
        if not result:
            result = [settings.default_locale]
        
        return result
    
    def _parse_unit_system(self) -> str:
        """Parse unit system preference from query params or headers"""
        # Check query parameter first
        unit_system = self.request.query_params.get('units')
        if unit_system and unit_system.lower() in ['metric', 'imperial', 'us']:
            return unit_system.lower()
        
        # Check custom header
        unit_system = self.request.headers.get('X-Unit-System')
        if unit_system and unit_system.lower() in ['metric', 'imperial', 'us']:
            return unit_system.lower()
        
        # Infer from language/region
        if self.primary_language == 'en':
            # Could be US or UK - default to metric for now
            return 'metric'
        
        return settings.default_unit_system
    
    def _parse_currency(self) -> str:
        """Parse currency preference"""
        currency = self.request.query_params.get('currency')
        if currency:
            return currency.upper()
        
        currency = self.request.headers.get('X-Currency')
        if currency:
            return currency.upper()
        
        return settings.default_currency
    
    def _parse_timezone(self) -> str:
        """Parse timezone preference"""
        timezone = self.request.headers.get('X-Timezone')
        if timezone:
            return timezone
        
        return settings.default_timezone
    
    def should_translate_to(self, target_language: str) -> bool:
        """Check if content should be translated to target language"""
        return target_language in self.languages and target_language != settings.default_locale
    
    def get_preferred_language(self, available_languages: List[str]) -> str:
        """Get the best matching language from available options"""
        for lang in self.languages:
            if lang in available_languages:
                return lang
        return settings.default_locale
    
    def to_dict(self) -> dict:
        """Convert to dictionary for API responses"""
        return {
            'languages': self.languages,
            'primary_language': self.primary_language,
            'unit_system': self.unit_system,
            'currency': self.currency,
            'timezone': self.timezone
        }


class LocalizationMiddleware(BaseHTTPMiddleware):
    """Middleware to add localization context to requests"""
    
    async def dispatch(self, request: Request, call_next):
        # Add localization context to request state
        request.state.localization = LocalizationContext(request)
        
        # Process request
        response = await call_next(request)
        
        # Add localization headers to response
        self._add_response_headers(response, request.state.localization)
        
        return response
    
    def _add_response_headers(self, response: Response, context: LocalizationContext):
        """Add localization metadata to response headers"""
        response.headers['X-Content-Language'] = context.primary_language
        response.headers['X-Unit-System'] = context.unit_system
        response.headers['X-Currency'] = context.currency
        response.headers['X-Timezone'] = context.timezone


def get_localization_context(request: Request) -> LocalizationContext:
    """Get localization context from request"""
    return getattr(request.state, 'localization', LocalizationContext(request))


class ResponseLocalizer:
    """Helper class for localizing API responses"""
    
    def __init__(self, context: LocalizationContext):
        self.context = context
    
    def localize_recipe(self, recipe_data: dict) -> dict:
        """Localize recipe data based on context preferences"""
        localized = recipe_data.copy()
        
        # Add localization metadata
        localized['_localization'] = {
            'language': self.context.primary_language,
            'unit_system': self.context.unit_system,
            'currency': self.context.currency
        }
        
        # Use appropriate language fields
        if self.context.primary_language != 'en':
            # Try to use localized fields if available
            lang_suffix = f'_{self.context.primary_language}'
            
            for field in ['title', 'description', 'cuisine', 'category']:
                localized_field = f'{field}{lang_suffix}'
                if localized_field in recipe_data and recipe_data[localized_field]:
                    localized[field] = recipe_data[localized_field]
            
            # Handle instructions array
            instructions_field = f'instructions{lang_suffix}'
            if instructions_field in recipe_data and recipe_data[instructions_field]:
                localized['instructions'] = recipe_data[instructions_field]
        
        return localized
    
    def localize_ingredient(self, ingredient_data: dict) -> dict:
        """Localize ingredient data based on context preferences"""
        from app.services.unit_conversion import unit_converter
        
        localized = ingredient_data.copy()
        
        # Convert units if needed
        if self.context.unit_system != 'metric':
            try:
                amount = ingredient_data.get('amount_canonical', ingredient_data.get('amount', 0))
                unit = ingredient_data.get('unit_canonical', ingredient_data.get('unit', 'gram'))
                ingredient_name = ingredient_data.get('name', '')
                
                conversion_result = unit_converter.convert_to_system(
                    amount, unit, self.context.unit_system, ingredient_name
                )
                
                localized['amount'] = float(conversion_result.amount)
                localized['unit'] = conversion_result.unit
                localized['_conversion_applied'] = True
                
            except Exception as e:
                logger.warning(f"Failed to convert units for ingredient: {e}")
                # Keep original values if conversion fails
                pass
        
        # Use appropriate language for ingredient name
        if self.context.primary_language != 'en':
            lang_suffix = f'_{self.context.primary_language}'
            name_field = f'name{lang_suffix}'
            if name_field in ingredient_data and ingredient_data[name_field]:
                localized['name'] = ingredient_data[name_field]
        
        return localized
    
    def add_response_metadata(self, response_data: dict) -> dict:
        """Add localization metadata to response"""
        if isinstance(response_data, dict):
            response_data['_meta'] = response_data.get('_meta', {})
            response_data['_meta']['localization'] = self.context.to_dict()
        
        return response_data
