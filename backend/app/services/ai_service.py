import openai
from typing import List, Dict, Any, Optional
from ..core.settings import settings
import json
import logging

logger = logging.getLogger(__name__)

class AIService:
    def __init__(self):
        self._client = None
        
    @property
    def client(self):
        """Lazy-load OpenAI client to avoid validation during import"""
        if self._client is None:
            self._client = openai.OpenAI(api_key=settings.openai_api_key)
        return self._client
    
    async def generate_recipe_suggestions(
        self, 
        ingredients: List[str], 
        cuisine_preference: Optional[str] = None,
        dietary_restrictions: Optional[List[str]] = None,
        difficulty_level: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Generate recipe suggestions based on available ingredients"""
        
        prompt = self._build_recipe_suggestion_prompt(
            ingredients, cuisine_preference, dietary_restrictions, difficulty_level
        )
        
        try:
            response = await self._call_openai(prompt, max_tokens=1500)
            return self._parse_recipe_suggestions(response)
        except Exception as e:
            logger.error(f"Error generating recipe suggestions: {e}")
            return []
    
    async def suggest_ingredient_substitutions(
        self, 
        original_ingredient: str, 
        recipe_context: str,
        dietary_restrictions: Optional[List[str]] = None
    ) -> List[Dict[str, str]]:
        """Suggest ingredient substitutions"""
        
        prompt = f"""
        I need substitutions for "{original_ingredient}" in this recipe context: "{recipe_context}"
        
        {"Dietary restrictions: " + ", ".join(dietary_restrictions) if dietary_restrictions else ""}
        
        Please provide 3-5 suitable substitutions with explanations. Format as JSON:
        [
            {{"substitute": "ingredient name", "explanation": "why it works", "ratio": "1:1 or other ratio"}},
            ...
        ]
        """
        
        try:
            response = await self._call_openai(prompt, max_tokens=800)
            return self._parse_substitutions(response)
        except Exception as e:
            logger.error(f"Error generating substitutions: {e}")
            return []
    
    async def generate_cooking_tips(
        self, 
        recipe_title: str, 
        cooking_method: str,
        difficulty_level: str
    ) -> List[str]:
        """Generate cooking tips for a specific recipe"""
        
        prompt = f"""
        Generate 5-7 helpful cooking tips for making "{recipe_title}" using {cooking_method} method.
        The recipe difficulty is {difficulty_level}.
        
        Focus on:
        - Technique improvements
        - Common mistakes to avoid
        - Timing and temperature tips
        - Ingredient preparation tips
        
        Return as a JSON array of strings: ["tip1", "tip2", ...]
        """
        
        try:
            response = await self._call_openai(prompt, max_tokens=600)
            return self._parse_cooking_tips(response)
        except Exception as e:
            logger.error(f"Error generating cooking tips: {e}")
            return []
    
    async def analyze_recipe_nutrition(
        self, 
        ingredients: List[Dict[str, Any]], 
        servings: int
    ) -> Dict[str, Any]:
        """Analyze nutritional content of a recipe"""
        
        ingredients_text = "\n".join([
            f"- {ing.get('amount', '')} {ing.get('unit', '')} {ing.get('name', '')}"
            for ing in ingredients
        ])
        
        prompt = f"""
        Analyze the nutritional content of this recipe (serves {servings}):
        
        Ingredients:
        {ingredients_text}
        
        Provide estimated nutrition per serving in JSON format:
        {{
            "calories": number,
            "protein_g": number,
            "carbs_g": number,
            "fat_g": number,
            "fiber_g": number,
            "sugar_g": number,
            "sodium_mg": number,
            "notes": "any important nutritional notes"
        }}
        """
        
        try:
            response = await self._call_openai(prompt, max_tokens=400)
            return self._parse_nutrition_analysis(response)
        except Exception as e:
            logger.error(f"Error analyzing nutrition: {e}")
            return {}
    
    async def improve_recipe_instructions(
        self, 
        current_instructions: List[str], 
        recipe_title: str
    ) -> List[str]:
        """Improve recipe instructions for clarity and completeness"""
        
        instructions_text = "\n".join([
            f"{i+1}. {instruction}" for i, instruction in enumerate(current_instructions)
        ])
        
        prompt = f"""
        Improve these cooking instructions for "{recipe_title}" to be clearer and more detailed:
        
        Current instructions:
        {instructions_text}
        
        Please provide improved instructions that:
        - Include specific temperatures and times
        - Add helpful technique details
        - Clarify any ambiguous steps
        - Maintain the same cooking method
        
        Return as JSON array: ["step1", "step2", ...]
        """
        
        try:
            response = await self._call_openai(prompt, max_tokens=1000)
            return self._parse_improved_instructions(response)
        except Exception as e:
            logger.error(f"Error improving instructions: {e}")
            return current_instructions
    
    def _build_recipe_suggestion_prompt(
        self, 
        ingredients: List[str], 
        cuisine: Optional[str], 
        restrictions: Optional[List[str]], 
        difficulty: Optional[str]
    ) -> str:
        """Build prompt for recipe suggestions"""
        
        base_prompt = f"I have these ingredients: {', '.join(ingredients)}\n\n"
        
        if cuisine:
            base_prompt += f"I prefer {cuisine} cuisine.\n"
        if restrictions:
            base_prompt += f"Dietary restrictions: {', '.join(restrictions)}\n"
        if difficulty:
            base_prompt += f"Preferred difficulty level: {difficulty}\n"
        
        base_prompt += """
        Please suggest 3-5 recipes I can make. For each recipe, provide:
        
        Format as JSON:
        [
            {
                "title": "Recipe Name",
                "description": "Brief description",
                "prep_time": minutes,
                "cook_time": minutes,
                "difficulty": "easy/medium/hard",
                "missing_ingredients": ["ingredient1", "ingredient2"],
                "key_techniques": ["technique1", "technique2"]
            },
            ...
        ]
        """
        
        return base_prompt
    
    async def _call_openai(self, prompt: str, max_tokens: int = 1000) -> str:
        """Make API call to OpenAI"""
        
        response = self.client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a professional chef and cooking assistant. Always respond with valid JSON when requested."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=max_tokens,
            temperature=0.7
        )
        
        return response.choices[0].message.content
    
    def _parse_recipe_suggestions(self, response: str) -> List[Dict[str, Any]]:
        """Parse recipe suggestions from AI response"""
        try:
            parsed = json.loads(response)
            # Handle both formats: direct list or wrapped in 'recipes' key
            if isinstance(parsed, list):
                return parsed
            elif isinstance(parsed, dict) and 'recipes' in parsed:
                return parsed['recipes']
            else:
                logger.error(f"Unexpected recipe suggestions format: {parsed}")
                return []
        except json.JSONDecodeError:
            logger.error("Failed to parse recipe suggestions JSON")
            return []
    
    def _parse_substitutions(self, response: str) -> List[Dict[str, str]]:
        """Parse ingredient substitutions from AI response"""
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            logger.error("Failed to parse substitutions JSON")
            return []
    
    def _parse_cooking_tips(self, response: str) -> List[str]:
        """Parse cooking tips from AI response"""
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            logger.error("Failed to parse cooking tips JSON")
            return []
    
    def _parse_nutrition_analysis(self, response: str) -> Dict[str, Any]:
        """Parse nutrition analysis from AI response"""
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            logger.error("Failed to parse nutrition analysis JSON")
            return {}
    
    def _parse_improved_instructions(self, response: str) -> List[str]:
        """Parse improved instructions from AI response"""
        try:
            return json.loads(response)
        except json.JSONDecodeError:
            logger.error("Failed to parse improved instructions JSON")
            return []

# Global AI service instance
ai_service = AIService()
