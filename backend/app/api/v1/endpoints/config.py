"""
Configuration API endpoints

Provides system configuration and localization settings
"""

from fastapi import APIRouter, Request, Query
from typing import Optional, Dict, Any
from pydantic import BaseModel

from app.core.settings import settings
from app.middleware.localization import get_localization_context, ResponseLocalizer

router = APIRouter()


class SystemConfig(BaseModel):
    """System configuration response"""
    app_name: str
    version: str
    default_locale: str
    default_unit_system: str
    default_currency: str
    supported_locales: list[str]
    features: Dict[str, bool]


class LocalizationConfig(BaseModel):
    """Localization configuration response"""
    current_language: str
    current_unit_system: str
    current_currency: str
    available_languages: list[str]
    unit_systems: Dict[str, str]
    currencies: list[str]


@router.get("/system", response_model=SystemConfig)
async def get_system_config():
    """Get system-wide configuration"""
    return SystemConfig(
        app_name=settings.app_name,
        version=settings.version,
        default_locale=settings.default_locale,
        default_unit_system=settings.default_unit_system,
        default_currency=settings.default_currency,
        supported_locales=settings.supported_locales_list,
        features={
            "unit_auto_convert": settings.enable_unit_auto_convert,
            "auto_translate": settings.enable_auto_translate,
            "data_normalize_input": settings.data_normalize_input,
        }
    )


@router.get("/localization", response_model=LocalizationConfig)
async def get_localization_config(request: Request):
    """Get localization configuration for current request"""
    context = get_localization_context(request)
    
    return LocalizationConfig(
        current_language=context.primary_language,
        current_unit_system=context.unit_system,
        current_currency=context.currency,
        available_languages=settings.supported_locales_list,
        unit_systems={
            "metric": "Metric (kg, L, °C)",
            "imperial": "Imperial (lb, gal, °F)",
            "us": "US Customary (lb, cup, °F)"
        },
        currencies=["EUR", "USD", "GBP"]
    )


@router.get("/units")
async def get_available_units(
    unit_type: Optional[str] = Query(None, description="Filter by unit type (mass, volume, count)"),
    system: Optional[str] = Query(None, description="Filter by system (metric, imperial, us)")
):
    """Get available units for conversion"""
    from app.services.unit_conversion import unit_converter
    
    units = []
    for unit_name, unit_def in unit_converter.units.items():
        if unit_type and unit_def.unit_type != unit_type:
            continue
        if system and unit_def.system != system:
            continue
        
        units.append({
            "name": unit_def.name,
            "abbreviation": unit_def.abbreviation,
            "type": unit_def.unit_type,
            "system": unit_def.system,
            "is_base": unit_def.is_base
        })
    
    return {"units": units}


@router.get("/ingredient-categories")
async def get_ingredient_categories(request: Request):
    """Get available ingredient categories"""
    context = get_localization_context(request)
    localizer = ResponseLocalizer(context)
    
    # Mock data - in real implementation, this would come from database
    categories = [
        {"id": "vegetables", "name_en": "Vegetables", "name_it": "Verdure"},
        {"id": "fruits", "name_en": "Fruits", "name_it": "Frutta"},
        {"id": "proteins", "name_en": "Proteins", "name_it": "Proteine"},
        {"id": "dairy", "name_en": "Dairy & Eggs", "name_it": "Latticini e Uova"},
        {"id": "grains", "name_en": "Grains & Cereals", "name_it": "Cereali"},
        {"id": "herbs", "name_en": "Herbs & Spices", "name_it": "Erbe e Spezie"},
        {"id": "oils", "name_en": "Oils & Fats", "name_it": "Oli e Grassi"},
        {"id": "condiments", "name_en": "Condiments & Sauces", "name_it": "Condimenti e Salse"},
        {"id": "nuts", "name_en": "Nuts & Seeds", "name_it": "Noci e Semi"},
        {"id": "beverages", "name_en": "Beverages", "name_it": "Bevande"},
        {"id": "baking", "name_en": "Baking", "name_it": "Prodotti da Forno"},
        {"id": "other", "name_en": "Other", "name_it": "Altro"}
    ]
    
    # Localize category names
    localized_categories = []
    for category in categories:
        localized = category.copy()
        if context.primary_language != 'en':
            lang_field = f"name_{context.primary_language}"
            if lang_field in category:
                localized["name"] = category[lang_field]
            else:
                localized["name"] = category["name_en"]
        else:
            localized["name"] = category["name_en"]
        
        # Remove language-specific fields from response
        for key in list(localized.keys()):
            if key.startswith("name_"):
                del localized[key]
        
        localized_categories.append(localized)
    
    response = {"categories": localized_categories}
    return localizer.add_response_metadata(response)


@router.post("/convert-units")
async def convert_units(
    request: Request,
    conversion_request: Dict[str, Any]
):
    """Convert units for ingredients"""
    from app.services.unit_conversion import unit_converter
    
    try:
        amount = float(conversion_request["amount"])
        from_unit = conversion_request["from_unit"]
        to_unit = conversion_request["to_unit"]
        ingredient_name = conversion_request.get("ingredient_name")
        
        result = unit_converter.convert_units(
            amount, from_unit, to_unit, ingredient_name
        )
        
        return {
            "converted_amount": float(result.amount),
            "converted_unit": result.unit,
            "original_amount": float(result.original_amount),
            "original_unit": result.original_unit,
            "conversion_factor": float(result.conversion_factor),
            "notes": result.notes,
            "precision_lost": result.precision_lost
        }
        
    except Exception as e:
        return {
            "error": str(e),
            "converted_amount": conversion_request["amount"],
            "converted_unit": conversion_request["from_unit"]
        }


@router.get("/normalization-stats")
async def get_normalization_stats():
    """Get statistics about data normalization"""
    # This would typically come from database queries
    # For now, return mock data
    return {
        "total_recipes": 1000,
        "normalized_recipes": 850,
        "normalization_coverage": 85.0,
        "common_issues": [
            {"issue": "unknown_unit", "count": 45, "description": "Units not in standard list"},
            {"issue": "fraction_amounts", "count": 32, "description": "Fractional amounts converted"},
            {"issue": "name_modified", "count": 28, "description": "Ingredient names standardized"},
            {"issue": "european_decimal", "count": 15, "description": "European decimal format converted"}
        ],
        "unit_distribution": {
            "metric": 65.2,
            "us": 28.1,
            "imperial": 6.7
        },
        "language_distribution": {
            "en": 72.3,
            "it": 27.7
        }
    }
