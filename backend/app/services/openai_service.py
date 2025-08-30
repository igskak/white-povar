import openai
from typing import Dict, List, Any, Optional
import logging
import json
import re

from app.core.settings import settings

logger = logging.getLogger(__name__)

class OpenAIService:
    """Service for OpenAI API interactions, specifically Vision API for ingredient detection"""
    
    def __init__(self):
        self._client = None
        
    @property
    def client(self):
        """Lazy-load OpenAI client to avoid validation during import"""
        if self._client is None:
            self._client = openai.AsyncOpenAI(api_key=settings.openai_api_key)
        return self._client
    
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
            You are an expert chef and food recognition specialist. Analyze this image to identify cooking ingredients with high accuracy.

            TASK: Identify all visible cooking ingredients that can be used in recipes.

            Return your response as a JSON object with this exact structure:
            {
                "ingredients": ["ingredient1", "ingredient2", ...],
                "confidence": 0.85,
                "notes": "Brief description of what you see"
            }

            CRITICAL RULES:
            1. NO DUPLICATES: If you see tomatoes, list only "tomato" (not both "tomato" and "tomatoes")
            2. SINGULAR FORM: Always use singular names ("tomato", "pepper", "egg", "onion")
            3. STANDARD NAMES: Use common ingredient names ("tomato" not "cherry tomato")
            4. HIGH CONFIDENCE ONLY: Only include ingredients you can clearly identify
            5. FOOD ONLY: Exclude utensils, containers, packaging, plates

            CONFIDENCE GUIDELINES:
            - 0.8-1.0: Very clear, excellent lighting, certain identification
            - 0.6-0.8: Clear visibility, good confidence
            - 0.4-0.6: Somewhat visible, moderate confidence
            - 0.2-0.4: Poor visibility, low confidence
            - 0.0-0.2: Very unclear, guessing

            Be generous with confidence if you can clearly see the ingredients. The goal is accurate identification, not conservative scoring.
            """
            
            # Make API call to OpenAI Vision with optimized parameters
            response = await self.client.chat.completions.create(
                model="gpt-4o",  # Use full GPT-4o for better vision capabilities
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert chef and food recognition specialist. You excel at identifying cooking ingredients from images with high accuracy."
                    },
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
                                    "detail": "high"  # High detail for better recognition
                                }
                            }
                        ]
                    }
                ],
                max_tokens=800,  # More tokens for detailed analysis
                temperature=0.0  # Zero temperature for maximum consistency
            )
            
            # Parse the response
            content = response.choices[0].message.content

            # Some models wrap JSON in ```json code fences or prepend text; extract JSON block if present
            def _extract_json_block(text: str) -> str:
                # Try to find JSON within code fences
                fence_match = re.search(r"```(?:json)?\s*({[\s\S]*?})\s*```", text)
                if fence_match:
                    return fence_match.group(1)
                # Fallback: find first { ... } block heuristically
                brace_start = text.find('{')
                brace_end = text.rfind('}')
                if brace_start != -1 and brace_end != -1 and brace_end > brace_start:
                    return text[brace_start:brace_end+1]
                return text

            content_json = _extract_json_block(content)

            try:
                # Try to parse as JSON
                result = json.loads(content_json)

                # Validate the response structure
                if not isinstance(result, dict):
                    raise ValueError("Response is not a dictionary")

                ingredients = result.get('ingredients', [])
                confidence = result.get('confidence', 0.0)
                notes = result.get('notes', '')

                # Validate ingredients list
                if not isinstance(ingredients, list):
                    ingredients = []

                # Clean up ingredient names (OpenAI handles deduplication)
                cleaned_ingredients = []
                seen = set()
                for ingredient in ingredients:
                    if isinstance(ingredient, str) and ingredient.strip():
                        name = ingredient.strip().lower()
                        if name not in seen:
                            seen.add(name)
                            cleaned_ingredients.append(name)

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
        Generate an inspiring, sensory-rich recipe description
        """
        try:
            prompt = f"""
            You are a passionate food writer who makes every dish sound irresistible. Create a captivating description for "{title}" using these ingredients: {', '.join(ingredients)}.

            Write a description that:
            - Engages the senses (aromas, textures, colors, sounds)
            - Paints a picture of the final dish
            - Makes the reader hungry and excited to cook
            - Uses vivid, appetizing language
            - Captures the essence and appeal of the dish

            Keep it 2-3 sentences and under 200 characters. Make every word count!

            EXAMPLE STYLE:
            Instead of: "A simple pasta with tomatoes and basil"
            Write: "Silky pasta ribbons dance with sun-ripened tomatoes and fragrant basil in this soul-warming dish that brings the essence of summer to your table."
            """

            response = await self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=120,
                temperature=0.8
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
