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
            response = await self._call_openai(prompt, max_tokens=3000)  # Increased for detailed content
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
        """Generate inspiring and practical cooking tips that build confidence"""

        prompt = f"""
        You are a master chef sharing your secrets! Generate 5-7 inspiring, practical cooking tips for making "{recipe_title}" using {cooking_method} method. The recipe difficulty is {difficulty_level}.

        Create tips that:

        INSPIRE CONFIDENCE:
        - Use encouraging, supportive language
        - Explain the "why" behind each tip
        - Make cooking feel achievable and fun
        - Share chef secrets that make a real difference

        PRACTICAL VALUE:
        - Focus on techniques that elevate the dish
        - Prevent common mistakes with clear explanations
        - Include sensory cues (what to look for, smell, hear)
        - Offer timing and temperature guidance
        - Suggest ingredient preparation shortcuts

        ENGAGING STYLE:
        - Use vivid, descriptive language
        - Share the story behind the technique
        - Make each tip feel like insider knowledge
        - Build excitement about the cooking process

        EXAMPLE STYLE:
        Instead of: "Don't overcook the vegetables"
        Write: "Keep your vegetables vibrant and crisp by cooking them just until they're tender-crisp - they should still have a slight bite and bright color. Overcooked vegetables lose their soul! The secret is high heat and constant movement."

        Return as a JSON array of inspiring, detailed tips: ["tip1", "tip2", ...]
        """

        try:
            response = await self._call_openai(prompt, max_tokens=800)
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
        """Transform basic instructions into inspiring, detailed cooking steps"""

        instructions_text = "\n".join([
            f"{i+1}. {instruction}" for i, instruction in enumerate(current_instructions)
        ])

        prompt = f"""
        You are a master chef and culinary instructor. Transform these basic cooking instructions for "{recipe_title}" into inspiring, detailed steps that will guide and motivate a home cook.

        Current instructions:
        {instructions_text}

        Create improved instructions that:

        STORYTELLING & INSPIRATION:
        - Use sensory language (sizzling, golden, fragrant, tender)
        - Explain WHY each step matters for the final result
        - Build excitement and confidence throughout
        - Paint a picture of what success looks like

        TECHNICAL EXCELLENCE:
        - Include specific temperatures, times, and visual cues
        - Explain techniques clearly with helpful tips
        - Mention what to listen for, smell for, and look for
        - Add professional chef secrets and shortcuts

        CONFIDENCE BUILDING:
        - Use encouraging, supportive language
        - Explain what's normal vs. what to watch out for
        - Give reassurance about timing and technique
        - Include recovery tips if something goes wrong

        EXAMPLE TRANSFORMATION:
        Basic: "Cook the onions until soft"
        Enhanced: "Heat your pan over medium heat and add the onions. Listen for that gentle sizzle - that's your cue that the temperature is perfect. Stir occasionally and watch as they transform from sharp and white to golden and sweet, about 5-7 minutes. The kitchen will fill with an irresistible aroma that promises great things ahead!"

        Return as JSON array of detailed, inspiring steps: ["step1", "step2", ...]
        """

        try:
            response = await self._call_openai(prompt, max_tokens=1500)
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
        """Build enhanced prompt for inspiring recipe suggestions"""

        base_prompt = f"""You are a passionate chef and culinary storyteller who creates recipes that inspire people to cook.

Available ingredients: {', '.join(ingredients)}

"""

        if cuisine:
            base_prompt += f"Cuisine preference: {cuisine}\n"
        if restrictions:
            base_prompt += f"Dietary restrictions: {', '.join(restrictions)}\n"
        if difficulty:
            base_prompt += f"Preferred difficulty level: {difficulty}\n"

        base_prompt += """
Create 3-5 inspiring recipes that will make the user excited to cook. Each recipe should tell a story and make the dish irresistible.

CRITICAL REQUIREMENTS:
1. INSPIRING DESCRIPTIONS: Write descriptions that paint a picture of the final dish - mention aromas, textures, colors, and the experience of eating it
2. DETAILED COOKING STEPS: Provide specific, encouraging instructions that guide the user confidently through each step
3. SENSORY LANGUAGE: Use words that engage the senses (sizzling, golden, fragrant, tender, crispy)
4. CONFIDENCE BUILDING: Include helpful tips and reassuring language that makes cooking feel achievable
5. STORY TELLING: Give context about why this dish is special or where it comes from

Format as JSON:
[
    {
        "title": "Compelling recipe name that sounds delicious",
        "description": "2-3 sentences that make the dish irresistible. Describe the final result - how it looks, smells, tastes. Paint a picture that makes someone hungry and excited to cook.",
        "detailed_instructions": [
            "Step 1: Detailed instruction with specific techniques, temperatures, visual cues, and encouraging language",
            "Step 2: Continue with sensory details and helpful tips",
            "Step 3: Build confidence with clear guidance and what to expect",
            "Step 4: Include timing, technique tips, and reassuring language",
            "Step 5: Finish with presentation tips and serving suggestions"
        ],
        "prep_time": minutes,
        "cook_time": minutes,
        "difficulty": "easy/medium/hard",
        "missing_ingredients": ["ingredient1", "ingredient2"],
        "key_techniques": ["technique1", "technique2"],
        "chef_tips": [
            "Professional tip that elevates the dish",
            "Common mistake to avoid with explanation",
            "Flavor enhancement suggestion"
        ],
        "why_youll_love_it": "One sentence explaining what makes this dish special and worth making"
    }
]

EXAMPLE STYLE:
Instead of: "Cook the chicken until done"
Write: "Sear the chicken pieces until they develop a beautiful golden-brown crust, about 4-5 minutes per side. You'll hear that satisfying sizzle - that's the Maillard reaction creating incredible flavor!"

Instead of: "A simple pasta dish"
Write: "Silky strands of pasta embrace a rich, aromatic sauce that fills your kitchen with the warm scents of garlic and herbs. Each bite delivers comfort and satisfaction that will have you coming back for seconds."
"""

        return base_prompt
    
    async def _call_openai(self, prompt: str, max_tokens: int = 1000) -> str:
        """Make API call to OpenAI with enhanced system message"""

        response = self.client.chat.completions.create(
            model="gpt-4o-mini",  # Better quality than 3.5-turbo, more cost-effective than full GPT-4
            messages=[
                {
                    "role": "system",
                    "content": """You are a master chef, culinary storyteller, and passionate cooking instructor. Your mission is to inspire people to cook by making every recipe feel achievable, exciting, and delicious.

You have the gift of transforming simple ingredients into compelling culinary stories. When you describe food, you engage all the senses. When you give instructions, you build confidence. When you share tips, you reveal professional secrets that make a real difference.

Always respond with valid JSON when requested. Make every word count in creating an inspiring cooking experience."""
                },
                {"role": "user", "content": prompt}
            ],
            max_tokens=max_tokens,
            temperature=0.8  # Slightly higher for more creative, inspiring language
        )

        return response.choices[0].message.content
    
    def _parse_recipe_suggestions(self, response: str) -> List[Dict[str, Any]]:
        """Parse enhanced recipe suggestions from AI response"""
        try:
            logger.info(f"Raw AI response: {response[:500]}...")  # Log first 500 chars

            # Clean up response - sometimes AI wraps JSON in markdown code blocks
            cleaned_response = response.strip()
            if cleaned_response.startswith("```json"):
                cleaned_response = cleaned_response[7:]
            if cleaned_response.endswith("```"):
                cleaned_response = cleaned_response[:-3]
            cleaned_response = cleaned_response.strip()

            parsed = json.loads(cleaned_response)

            # Handle both formats: direct list or wrapped in 'recipes' key
            if isinstance(parsed, list):
                recipes = parsed
            elif isinstance(parsed, dict) and 'recipes' in parsed:
                recipes = parsed['recipes']
            else:
                logger.error(f"Unexpected recipe suggestions format: {parsed}")
                return []

            # Ensure each recipe has the expected fields with fallbacks
            enhanced_recipes = []
            for recipe in recipes:
                if isinstance(recipe, dict):
                    # Ensure all required fields exist
                    enhanced_recipe = {
                        'title': recipe.get('title', 'Untitled Recipe'),
                        'description': recipe.get('description', 'A delicious recipe'),
                        'detailed_instructions': recipe.get('detailed_instructions', recipe.get('instructions', [])),
                        'prep_time': recipe.get('prep_time', 15),
                        'cook_time': recipe.get('cook_time', 20),
                        'difficulty': recipe.get('difficulty', 'medium'),
                        'missing_ingredients': recipe.get('missing_ingredients', []),
                        'key_techniques': recipe.get('key_techniques', []),
                        'chef_tips': recipe.get('chef_tips', []),
                        'why_youll_love_it': recipe.get('why_youll_love_it', 'A wonderful dish to try!')
                    }
                    enhanced_recipes.append(enhanced_recipe)

            return enhanced_recipes

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse recipe suggestions JSON: {e}")
            logger.error(f"Raw response that failed to parse: {response}")
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
