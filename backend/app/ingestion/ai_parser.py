import json
import asyncio
from typing import Dict, Any, Optional, Tuple
import logging
from openai import AsyncOpenAI
from app.core.settings import settings
from app.schemas.ingestion import ParsedRecipe, ParsedIngredient, ParsedNutrition

logger = logging.getLogger(__name__)


class AIRecipeParser:
    """AI-powered recipe parser using OpenAI"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = "gpt-4o-mini"  # Cost-effective model for structured extraction
        self.max_retries = 2
        self.semaphore = asyncio.Semaphore(4)  # Limit concurrent requests
    
    async def parse_recipe(self, text: str, detected_language: Optional[str] = None) -> Tuple[ParsedRecipe, Dict[str, Any]]:
        """
        Parse recipe text into structured data
        
        Args:
            text: Raw recipe text
            detected_language: Detected language of the text
            
        Returns:
            Tuple of (ParsedRecipe, metadata)
            metadata contains token_usage, processing_time, etc.
        """
        async with self.semaphore:
            start_time = asyncio.get_event_loop().time()
            
            try:
                # Prepare the prompt
                system_prompt = self._get_system_prompt()
                user_prompt = self._get_user_prompt(text, detected_language)
                
                # Make API call
                response = await self._call_openai(system_prompt, user_prompt)
                
                # Parse response
                parsed_data = self._parse_response(response)
                
                # Create ParsedRecipe object
                recipe = ParsedRecipe(**parsed_data)
                
                # Calculate metadata
                processing_time = asyncio.get_event_loop().time() - start_time
                metadata = {
                    'token_usage': response.usage.model_dump() if response.usage else {},
                    'processing_time_seconds': processing_time,
                    'model_used': self.model,
                    'detected_language': detected_language,
                    'was_translated': detected_language and detected_language != 'en'
                }
                
                logger.info(f"Successfully parsed recipe: {recipe.title}")
                return recipe, metadata
                
            except Exception as e:
                logger.error(f"Failed to parse recipe: {str(e)}")
                raise
    
    def _get_system_prompt(self) -> str:
        """Get the system prompt for recipe parsing"""
        return """You are a professional recipe parser. Extract structured recipe data from unstructured text.

IMPORTANT RULES:
1. If text is not in English, translate all content to English
2. Improve descriptions to match professional chef style - make them appetizing and descriptive
3. Use "unknown" for any field you cannot determine from the text
4. For ingredients: separate quantity, unit, and name clearly
5. Normalize units: use g, kg, ml, l, cup, tbsp, tsp, oz, lb, piece (or pc)
6. Difficulty: 1=very easy, 2=easy, 3=medium, 4=hard, 5=very hard
7. Instructions should be clear, numbered steps
8. Tags should include dietary restrictions if mentioned (vegetarian, vegan, gluten-free, etc.)

INGREDIENT PARSING GUIDELINES:
- Extract clean ingredient names (remove preparation methods)
- Put preparation methods in "notes" field (diced, chopped, minced, etc.)
- Normalize quantities to decimal numbers
- Use standard units: g, kg, ml, l, cup, tbsp, tsp, oz, lb, piece
- For "to taste" items, use null for quantity and unit

EXAMPLES:
"2 large onions, diced" → {"name": "onions", "quantity_value": 2, "unit": "piece", "notes": "large, diced"}
"400g spaghetti" → {"name": "spaghetti", "quantity_value": 400, "unit": "g", "notes": null}
"3 cloves garlic, minced" → {"name": "garlic", "quantity_value": 3, "unit": "piece", "notes": "cloves, minced"}
"Salt to taste" → {"name": "salt", "quantity_value": null, "unit": null, "notes": "to taste"}

Return ONLY valid JSON matching this exact schema:
{
  "title": "string",
  "description": "string (appetizing, chef-style description)",
  "cuisine": "string",
  "category": "string (appetizer, main, dessert, etc.)",
  "difficulty": 1-5,
  "prep_time_minutes": 0,
  "cook_time_minutes": 0,
  "servings": 1,
  "ingredients": [
    {
      "name": "string (clean ingredient name)",
      "quantity_value": 0.0 or null,
      "unit": "string (normalized) or null",
      "notes": "string (preparation, size, etc.) or null"
    }
  ],
  "instructions": ["step 1", "step 2"],
  "tags": ["tag1", "tag2"],
  "nutrition": {
    "calories_per_serving": 0 or null,
    "protein_g": 0.0 or null,
    "carbs_g": 0.0 or null,
    "fat_g": 0.0 or null,
    "sugar_g": 0.0 or null,
    "fiber_g": 0.0 or null,
    "sodium_mg": 0.0 or null
  } or null,
  "detected_language": "string or null",
  "was_translated": true/false,
  "confidence_scores": {
    "overall": 0.0-1.0,
    "title": 0.0-1.0,
    "ingredients": 0.0-1.0,
    "instructions": 0.0-1.0
  }
}"""
    
    def _get_user_prompt(self, text: str, detected_language: Optional[str] = None) -> str:
        """Get the user prompt with the recipe text"""
        lang_info = f" (detected language: {detected_language})" if detected_language else ""
        return f"""Parse this recipe text{lang_info}:

{text}

Remember to:
- Translate to English if needed
- Make the description appetizing and professional
- Use "unknown" for missing information
- Include dietary tags if applicable
- Provide confidence scores for each section"""
    
    async def _call_openai(self, system_prompt: str, user_prompt: str) -> Any:
        """Make API call to OpenAI with retries"""
        for attempt in range(self.max_retries + 1):
            try:
                response = await self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    response_format={"type": "json_object"},
                    temperature=0.1,  # Low temperature for consistent extraction
                    max_tokens=2000
                )
                return response
                
            except Exception as e:
                if attempt < self.max_retries:
                    wait_time = 2 ** attempt  # Exponential backoff
                    logger.warning(f"OpenAI API call failed (attempt {attempt + 1}), retrying in {wait_time}s: {str(e)}")
                    await asyncio.sleep(wait_time)
                else:
                    raise
    
    def _parse_response(self, response: Any) -> Dict[str, Any]:
        """Parse OpenAI response into structured data"""
        try:
            content = response.choices[0].message.content
            data = json.loads(content)
            
            # Validate required fields
            required_fields = ['title', 'description', 'cuisine', 'category', 'difficulty', 
                             'prep_time_minutes', 'cook_time_minutes', 'servings', 
                             'ingredients', 'instructions']
            
            for field in required_fields:
                if field not in data:
                    raise ValueError(f"Missing required field: {field}")
            
            # Set defaults for optional fields
            data.setdefault('tags', [])
            data.setdefault('nutrition', None)
            data.setdefault('detected_language', None)
            data.setdefault('was_translated', False)
            data.setdefault('confidence_scores', {})
            
            # Validate ingredients structure
            if not isinstance(data['ingredients'], list) or len(data['ingredients']) == 0:
                raise ValueError("At least one ingredient is required")
            
            for i, ingredient in enumerate(data['ingredients']):
                if not isinstance(ingredient, dict) or 'name' not in ingredient:
                    raise ValueError(f"Invalid ingredient structure at index {i}")
            
            # Validate instructions
            if not isinstance(data['instructions'], list) or len(data['instructions']) == 0:
                raise ValueError("At least one instruction is required")
            
            return data
            
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON response from AI: {str(e)}")
        except Exception as e:
            raise ValueError(f"Failed to parse AI response: {str(e)}")


# Global instance
ai_parser = AIRecipeParser()
