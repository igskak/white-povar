import openai
from typing import Dict, List, Any, Optional
import logging
import json
import asyncio
from functools import wraps

from app.core.settings import settings

logger = logging.getLogger(__name__)

class OpenAIService:
    """Service for OpenAI API interactions, specifically Vision API for ingredient detection"""
    
    def __init__(self):
        openai.api_key = settings.openai_api_key
        self.client = openai.AsyncOpenAI(api_key=settings.openai_api_key)
    
    async def analyze_ingredients(self, base64_image: str) -> Dict[str, Any]:
        """
        Analyze an image to detect cooking ingredients using OpenAI Vision API
        
        Args:
            base64_image: Base64 encoded image string
            
        Returns:
            Dict containing detected ingredients and confidence score
        """
        try:
            # Prepare the prompt for ingredient detection
            prompt = """
            Analyze this image and identify all cooking ingredients that are visible. 
            Focus on ingredients that could be used for cooking recipes.
            
            Return your response as a JSON object with this exact structure:
            {
                "ingredients": ["ingredient1", "ingredient2", ...],
                "confidence": 0.85,
                "notes": "Brief description of what you see"
            }
            
            Guidelines:
            - Only list ingredients you can clearly identify
            - Use common ingredient names (e.g., "tomatoes" not "cherry tomatoes")
            - Include fruits, vegetables, proteins, grains, herbs, spices
            - Exclude non-food items, utensils, or containers
            - Confidence should be between 0.0 and 1.0
            - If no ingredients are visible, return empty ingredients array
            """
            
            # Make API call to OpenAI Vision
            response = await self.client.chat.completions.create(
                model="gpt-4-vision-preview",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": prompt
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}",
                                    "detail": "high"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=500,
                temperature=0.1  # Low temperature for consistent results
            )
            
            # Parse the response
            content = response.choices[0].message.content
            
            try:
                # Try to parse as JSON
                result = json.loads(content)
                
                # Validate the response structure
                if not isinstance(result, dict):
                    raise ValueError("Response is not a dictionary")
                
                ingredients = result.get('ingredients', [])
                confidence = result.get('confidence', 0.0)
                notes = result.get('notes', '')
                
                # Validate ingredients list
                if not isinstance(ingredients, list):
                    ingredients = []
                
                # Clean up ingredient names
                cleaned_ingredients = []
                for ingredient in ingredients:
                    if isinstance(ingredient, str) and ingredient.strip():
                        cleaned_ingredients.append(ingredient.strip().lower())
                
                # Validate confidence score
                if not isinstance(confidence, (int, float)) or confidence < 0 or confidence > 1:
                    confidence = 0.5  # Default confidence
                
                return {
                    'ingredients': cleaned_ingredients,
                    'confidence': float(confidence),
                    'notes': notes,
                    'raw_response': content
                }
                
            except json.JSONDecodeError:
                # If JSON parsing fails, try to extract ingredients from text
                logger.warning(f"Failed to parse JSON response: {content}")
                return await self._fallback_ingredient_extraction(content)
                
        except Exception as e:
            logger.error(f"OpenAI Vision API error: {str(e)}")
            
            # Return fallback response
            return {
                'ingredients': [],
                'confidence': 0.0,
                'notes': f'Error analyzing image: {str(e)}',
                'error': str(e)
            }
    
    async def _fallback_ingredient_extraction(self, text_response: str) -> Dict[str, Any]:
        """
        Fallback method to extract ingredients from text response when JSON parsing fails
        """
        try:
            # Common ingredient keywords to look for
            common_ingredients = [
                'tomato', 'tomatoes', 'onion', 'onions', 'garlic', 'pepper', 'peppers',
                'carrot', 'carrots', 'potato', 'potatoes', 'chicken', 'beef', 'pork',
                'fish', 'salmon', 'rice', 'pasta', 'bread', 'cheese', 'milk', 'eggs',
                'flour', 'sugar', 'salt', 'oil', 'butter', 'herbs', 'basil', 'parsley',
                'cilantro', 'spinach', 'lettuce', 'cucumber', 'bell pepper', 'mushroom',
                'mushrooms', 'broccoli', 'cauliflower', 'zucchini', 'eggplant',
                'avocado', 'lime', 'lemon', 'apple', 'banana', 'strawberry', 'blueberry'
            ]
            
            # Extract ingredients mentioned in the text
            text_lower = text_response.lower()
            found_ingredients = []
            
            for ingredient in common_ingredients:
                if ingredient in text_lower:
                    found_ingredients.append(ingredient)
            
            # Remove duplicates while preserving order
            unique_ingredients = []
            for ingredient in found_ingredients:
                if ingredient not in unique_ingredients:
                    unique_ingredients.append(ingredient)
            
            return {
                'ingredients': unique_ingredients,
                'confidence': 0.3,  # Lower confidence for fallback method
                'notes': 'Extracted using fallback text analysis',
                'raw_response': text_response
            }
            
        except Exception as e:
            logger.error(f"Fallback extraction error: {str(e)}")
            return {
                'ingredients': [],
                'confidence': 0.0,
                'notes': 'Failed to extract ingredients',
                'error': str(e)
            }
    
    async def generate_recipe_description(self, title: str, ingredients: List[str]) -> str:
        """
        Generate a recipe description based on title and ingredients
        """
        try:
            prompt = f"""
            Create a brief, appetizing description for a recipe called "{title}" 
            that uses these ingredients: {', '.join(ingredients)}.
            
            The description should be 2-3 sentences, highlight the key flavors,
            and make the dish sound delicious. Keep it under 200 characters.
            """
            
            response = await self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=100,
                temperature=0.7
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logger.error(f"Error generating recipe description: {str(e)}")
            return f"A delicious recipe featuring {', '.join(ingredients[:3])}."
    
    async def suggest_recipe_variations(self, base_recipe_title: str, ingredients: List[str]) -> List[str]:
        """
        Suggest recipe variations based on available ingredients
        """
        try:
            prompt = f"""
            Given a base recipe "{base_recipe_title}" and these available ingredients: {', '.join(ingredients)},
            suggest 3-5 simple variations or modifications that could be made.
            
            Return as a simple list, one variation per line.
            Focus on practical substitutions or additions.
            """
            
            response = await self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=200,
                temperature=0.8
            )
            
            variations = response.choices[0].message.content.strip().split('\n')
            return [v.strip('- ').strip() for v in variations if v.strip()]
            
        except Exception as e:
            logger.error(f"Error generating recipe variations: {str(e)}")
            return []

# Global service instance
openai_service = OpenAIService()
