from typing import List, Dict, Tuple, Any
import re
import logging
from app.schemas.ingestion import ParsedRecipe

logger = logging.getLogger(__name__)


class RecipeValidator:
    """Validate and score parsed recipes for quality control"""
    
    def __init__(self):
        self.min_confidence_threshold = 0.75
        self.dietary_tags = {
            'vegetarian', 'vegan', 'gluten-free', 'dairy-free', 'nut-free', 
            'egg-free', 'soy-free', 'halal', 'kosher', 'keto', 'paleo', 
            'low-carb', 'low-fat', 'low-sodium', 'sugar-free'
        }
        self.common_cuisines = {
            'italian', 'mexican', 'chinese', 'indian', 'french', 'thai', 
            'japanese', 'mediterranean', 'american', 'greek', 'spanish',
            'korean', 'vietnamese', 'middle eastern', 'british', 'german'
        }
        self.common_categories = {
            'appetizer', 'main course', 'dessert', 'side dish', 'soup', 
            'salad', 'breakfast', 'lunch', 'dinner', 'snack', 'beverage',
            'sauce', 'marinade', 'bread', 'pasta'
        }
    
    def validate_recipe(self, recipe: ParsedRecipe) -> Tuple[bool, List[str], float]:
        """
        Validate recipe and calculate quality score
        
        Args:
            recipe: Parsed recipe to validate
            
        Returns:
            Tuple of (is_valid, issues, confidence_score)
        """
        issues = []
        confidence_factors = []
        
        # Basic validation (these are critical issues)
        critical_issues = self._check_critical_issues(recipe)
        if critical_issues:
            return False, critical_issues, 0.0
        
        # Quality checks (these affect confidence but don't invalidate)
        quality_issues, quality_score = self._check_quality_issues(recipe)
        issues.extend(quality_issues)
        
        # Calculate overall confidence
        base_confidence = recipe.confidence_scores.get('overall', 0.8)
        final_confidence = min(base_confidence * quality_score, 1.0)
        
        # Determine if manual review is needed
        needs_review = final_confidence < self.min_confidence_threshold or len(issues) > 3
        
        logger.info(f"Recipe validation complete: confidence={final_confidence:.2f}, issues={len(issues)}")
        return not needs_review, issues, final_confidence
    
    def _check_critical_issues(self, recipe: ParsedRecipe) -> List[str]:
        """Check for critical issues that invalidate the recipe"""
        issues = []
        
        # Title validation
        if not recipe.title or len(recipe.title.strip()) < 3:
            issues.append("Title is missing or too short")
        
        # Ingredients validation
        if not recipe.ingredients or len(recipe.ingredients) == 0:
            issues.append("No ingredients found")
        else:
            for i, ingredient in enumerate(recipe.ingredients):
                if not ingredient.name or len(ingredient.name.strip()) < 2:
                    issues.append(f"Ingredient {i+1} has invalid name")
        
        # Instructions validation
        if not recipe.instructions or len(recipe.instructions) == 0:
            issues.append("No instructions found")
        else:
            for i, instruction in enumerate(recipe.instructions):
                if not instruction or len(instruction.strip()) < 10:
                    issues.append(f"Instruction {i+1} is too short or empty")
        
        # Basic numeric validation
        if recipe.difficulty < 1 or recipe.difficulty > 5:
            issues.append("Difficulty must be between 1 and 5")
        
        if recipe.servings < 1:
            issues.append("Servings must be at least 1")
        
        if recipe.prep_time_minutes < 0 or recipe.cook_time_minutes < 0:
            issues.append("Time values cannot be negative")
        
        return issues
    
    def _check_quality_issues(self, recipe: ParsedRecipe) -> Tuple[List[str], float]:
        """Check for quality issues and calculate quality score"""
        issues = []
        score_factors = []
        
        # Description quality
        desc_score = self._score_description(recipe.description)
        score_factors.append(desc_score)
        if desc_score < 0.7:
            issues.append("Description quality could be improved")
        
        # Ingredient quality
        ing_score = self._score_ingredients(recipe.ingredients)
        score_factors.append(ing_score)
        if ing_score < 0.7:
            issues.append("Some ingredients may need clarification")
        
        # Instructions quality
        inst_score = self._score_instructions(recipe.instructions)
        score_factors.append(inst_score)
        if inst_score < 0.7:
            issues.append("Instructions could be more detailed")
        
        # Cuisine validation
        cuisine_score = self._score_cuisine(recipe.cuisine)
        score_factors.append(cuisine_score)
        if cuisine_score < 0.8:
            issues.append(f"Unusual cuisine type: {recipe.cuisine}")
        
        # Category validation
        category_score = self._score_category(recipe.category)
        score_factors.append(category_score)
        if category_score < 0.8:
            issues.append(f"Unusual category: {recipe.category}")
        
        # Tags validation
        tag_score = self._score_tags(recipe.tags)
        score_factors.append(tag_score)
        if tag_score < 0.8:
            issues.append("Some tags may not be recognized")
        
        # Time reasonableness
        time_score = self._score_times(recipe.prep_time_minutes, recipe.cook_time_minutes)
        score_factors.append(time_score)
        if time_score < 0.7:
            issues.append("Cooking times seem unusual")
        
        # Nutrition validation (if provided)
        if recipe.nutrition:
            nutrition_score = self._score_nutrition(recipe.nutrition)
            score_factors.append(nutrition_score)
            if nutrition_score < 0.7:
                issues.append("Nutrition information seems inconsistent")
        
        # Calculate overall quality score
        overall_score = sum(score_factors) / len(score_factors) if score_factors else 0.5
        
        return issues, overall_score
    
    def _score_description(self, description: str) -> float:
        """Score description quality"""
        if not description:
            return 0.0
        
        score = 0.5  # Base score
        
        # Length check
        if 50 <= len(description) <= 500:
            score += 0.2
        
        # Check for appetizing words
        appetizing_words = ['delicious', 'flavorful', 'tender', 'crispy', 'fresh', 'savory', 'rich']
        if any(word in description.lower() for word in appetizing_words):
            score += 0.2
        
        # Check for complete sentences
        if description.count('.') >= 1:
            score += 0.1
        
        return min(score, 1.0)
    
    def _score_ingredients(self, ingredients: List) -> float:
        """Score ingredients quality"""
        if not ingredients:
            return 0.0
        
        score = 0.5  # Base score
        
        # Check if most ingredients have quantities
        with_quantities = sum(1 for ing in ingredients if ing.quantity_value is not None)
        if with_quantities / len(ingredients) > 0.7:
            score += 0.3
        
        # Check for reasonable ingredient names
        reasonable_names = sum(1 for ing in ingredients if len(ing.name) > 2 and len(ing.name) < 50)
        if reasonable_names / len(ingredients) > 0.9:
            score += 0.2
        
        return min(score, 1.0)
    
    def _score_instructions(self, instructions: List[str]) -> float:
        """Score instructions quality"""
        if not instructions:
            return 0.0
        
        score = 0.5  # Base score
        
        # Check average instruction length
        avg_length = sum(len(inst) for inst in instructions) / len(instructions)
        if 20 <= avg_length <= 200:
            score += 0.3
        
        # Check for action words
        action_words = ['heat', 'cook', 'add', 'mix', 'stir', 'bake', 'fry', 'boil', 'simmer']
        instructions_with_actions = sum(1 for inst in instructions 
                                      if any(word in inst.lower() for word in action_words))
        if instructions_with_actions / len(instructions) > 0.5:
            score += 0.2
        
        return min(score, 1.0)
    
    def _score_cuisine(self, cuisine: str) -> float:
        """Score cuisine validity"""
        if not cuisine:
            return 0.5
        
        if cuisine.lower() in self.common_cuisines:
            return 1.0
        
        # Partial match
        for common in self.common_cuisines:
            if common in cuisine.lower() or cuisine.lower() in common:
                return 0.8
        
        return 0.6  # Unknown but not necessarily wrong
    
    def _score_category(self, category: str) -> float:
        """Score category validity"""
        if not category:
            return 0.5
        
        if category.lower() in self.common_categories:
            return 1.0
        
        # Partial match
        for common in self.common_categories:
            if common in category.lower() or category.lower() in common:
                return 0.8
        
        return 0.6  # Unknown but not necessarily wrong
    
    def _score_tags(self, tags: List[str]) -> float:
        """Score tags validity"""
        if not tags:
            return 0.8  # No tags is fine
        
        recognized_tags = sum(1 for tag in tags if tag.lower() in self.dietary_tags)
        if len(tags) == 0:
            return 0.8
        
        return 0.6 + (recognized_tags / len(tags)) * 0.4
    
    def _score_times(self, prep_time: int, cook_time: int) -> float:
        """Score time reasonableness"""
        total_time = prep_time + cook_time
        
        # Very short or very long times are suspicious
        if total_time < 5 or total_time > 480:  # Less than 5 min or more than 8 hours
            return 0.5
        
        # Reasonable ranges
        if 10 <= total_time <= 180:  # 10 minutes to 3 hours
            return 1.0
        
        return 0.7
    
    def _score_nutrition(self, nutrition) -> float:
        """Score nutrition information consistency"""
        if not nutrition:
            return 0.8
        
        score = 0.5
        
        # Check if calories are reasonable
        if nutrition.calories_per_serving and 50 <= nutrition.calories_per_serving <= 2000:
            score += 0.3
        
        # Check if macros add up reasonably (rough check)
        if (nutrition.protein_g and nutrition.carbs_g and nutrition.fat_g and 
            nutrition.calories_per_serving):
            calculated_calories = (nutrition.protein_g * 4 + 
                                 nutrition.carbs_g * 4 + 
                                 nutrition.fat_g * 9)
            if abs(calculated_calories - nutrition.calories_per_serving) / nutrition.calories_per_serving < 0.3:
                score += 0.2
        
        return min(score, 1.0)


# Global instance
recipe_validator = RecipeValidator()
