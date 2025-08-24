import hashlib
import re
from typing import List, Tuple, Optional, Dict, Any
import logging
from app.schemas.ingestion import ParsedRecipe
from app.services.database import supabase_service

logger = logging.getLogger(__name__)


class RecipeDeduplicator:
    """Detect duplicate and similar recipes"""
    
    def __init__(self):
        self.similarity_threshold = 0.85  # For fuzzy matching
        self.time_tolerance_minutes = 15  # Time difference tolerance
    
    async def check_duplicates(self, recipe: ParsedRecipe) -> Tuple[bool, Optional[str], List[str]]:
        """
        Check if recipe is a duplicate or similar to existing recipes
        
        Args:
            recipe: Parsed recipe to check
            
        Returns:
            Tuple of (is_duplicate, exact_duplicate_id, similar_recipe_ids)
        """
        try:
            # Generate fingerprint
            fingerprint_hash = self._generate_fingerprint(recipe)
            
            # Check for exact duplicates
            exact_duplicate = await self._find_exact_duplicate(fingerprint_hash)
            if exact_duplicate:
                logger.info(f"Found exact duplicate: {exact_duplicate}")
                return True, exact_duplicate, []
            
            # Check for similar recipes
            similar_recipes = await self._find_similar_recipes(recipe)
            
            if similar_recipes:
                logger.info(f"Found {len(similar_recipes)} similar recipes")
                return False, None, similar_recipes
            
            return False, None, []
            
        except Exception as e:
            logger.error(f"Error during duplicate check: {str(e)}")
            # Don't fail the entire process due to duplicate check errors
            return False, None, []
    
    def _generate_fingerprint(self, recipe: ParsedRecipe) -> str:
        """Generate a fingerprint hash for the recipe"""
        # Normalize components for fingerprinting
        title_norm = self._normalize_text(recipe.title)
        cuisine_norm = self._normalize_text(recipe.cuisine)
        total_time = recipe.total_time_minutes
        
        # Create fingerprint string
        fingerprint_data = f"{title_norm}|{cuisine_norm}|{total_time}"
        
        # Generate hash
        return hashlib.sha1(fingerprint_data.encode('utf-8')).hexdigest()
    
    def _normalize_text(self, text: str) -> str:
        """Normalize text for comparison"""
        if not text:
            return ""
        
        # Convert to lowercase
        normalized = text.lower()
        
        # Remove common recipe words that don't add uniqueness
        stop_words = ['recipe', 'easy', 'quick', 'simple', 'best', 'perfect', 'homemade']
        for word in stop_words:
            normalized = re.sub(rf'\b{word}\b', '', normalized)
        
        # Remove punctuation and extra spaces
        normalized = re.sub(r'[^\w\s]', '', normalized)
        normalized = ' '.join(normalized.split())
        
        return normalized.strip()
    
    async def _find_exact_duplicate(self, fingerprint_hash: str) -> Optional[str]:
        """Find exact duplicate by fingerprint hash"""
        try:
            result = await supabase_service.find_duplicate_recipes(fingerprint_hash)
            if result.data and len(result.data) > 0:
                return result.data[0]['recipe_id']
            return None
        except Exception as e:
            logger.error(f"Error finding exact duplicate: {str(e)}")
            return None
    
    async def _find_similar_recipes(self, recipe: ParsedRecipe) -> List[str]:
        """Find similar recipes using fuzzy matching"""
        try:
            # Get potentially similar recipes from database
            title_norm = self._normalize_text(recipe.title)
            cuisine_norm = self._normalize_text(recipe.cuisine)
            total_time = recipe.total_time_minutes
            
            result = await supabase_service.find_similar_recipes(
                title_norm, cuisine_norm, total_time, self.time_tolerance_minutes
            )
            
            if not result.data:
                return []
            
            similar_ids = []
            
            # Use fuzzy matching to find truly similar recipes
            try:
                from rapidfuzz import fuzz
                
                for candidate in result.data:
                    candidate_title = candidate.get('title_normalized', '')
                    
                    # Calculate similarity score
                    similarity = fuzz.partial_ratio(title_norm, candidate_title) / 100.0
                    
                    if similarity >= self.similarity_threshold:
                        similar_ids.append(candidate['recipe_id'])
                        logger.debug(f"Similar recipe found: {candidate_title} (similarity: {similarity:.2f})")
                
            except ImportError:
                logger.warning("rapidfuzz not available, using basic string matching")
                # Fallback to basic string matching
                for candidate in result.data:
                    candidate_title = candidate.get('title_normalized', '')
                    if self._basic_similarity(title_norm, candidate_title) >= self.similarity_threshold:
                        similar_ids.append(candidate['recipe_id'])
            
            return similar_ids
            
        except Exception as e:
            logger.error(f"Error finding similar recipes: {str(e)}")
            return []
    
    def _basic_similarity(self, text1: str, text2: str) -> float:
        """Basic similarity calculation without external dependencies"""
        if not text1 or not text2:
            return 0.0
        
        # Simple word overlap calculation
        words1 = set(text1.split())
        words2 = set(text2.split())
        
        if not words1 or not words2:
            return 0.0
        
        intersection = words1.intersection(words2)
        union = words1.union(words2)
        
        return len(intersection) / len(union) if union else 0.0
    
    async def create_fingerprint_record(self, recipe_id: str, recipe: ParsedRecipe) -> bool:
        """Create fingerprint record for a recipe"""
        try:
            fingerprint_data = {
                'recipe_id': recipe_id,
                'title_normalized': self._normalize_text(recipe.title),
                'cuisine_normalized': self._normalize_text(recipe.cuisine),
                'total_time_minutes': recipe.total_time_minutes,
                'fingerprint_hash': self._generate_fingerprint(recipe)
            }
            
            result = await supabase_service.create_recipe_fingerprint(fingerprint_data)
            return bool(result.data)
            
        except Exception as e:
            logger.error(f"Error creating fingerprint record: {str(e)}")
            return False
    
    def calculate_similarity_score(self, recipe1: ParsedRecipe, recipe2_data: Dict[str, Any]) -> float:
        """Calculate detailed similarity score between two recipes"""
        scores = []
        
        # Title similarity
        title1_norm = self._normalize_text(recipe1.title)
        title2_norm = self._normalize_text(recipe2_data.get('title', ''))
        
        try:
            from rapidfuzz import fuzz
            title_sim = fuzz.ratio(title1_norm, title2_norm) / 100.0
        except ImportError:
            title_sim = self._basic_similarity(title1_norm, title2_norm)
        
        scores.append(title_sim * 0.4)  # Title is most important
        
        # Cuisine similarity
        cuisine1_norm = self._normalize_text(recipe1.cuisine)
        cuisine2_norm = self._normalize_text(recipe2_data.get('cuisine', ''))
        cuisine_sim = 1.0 if cuisine1_norm == cuisine2_norm else 0.0
        scores.append(cuisine_sim * 0.2)
        
        # Time similarity
        time1 = recipe1.total_time_minutes
        time2 = recipe2_data.get('total_time_minutes', 0)
        if time1 > 0 and time2 > 0:
            time_diff = abs(time1 - time2)
            time_sim = max(0, 1 - (time_diff / max(time1, time2)))
        else:
            time_sim = 0.5  # Unknown time
        scores.append(time_sim * 0.2)
        
        # Servings similarity
        servings1 = recipe1.servings
        servings2 = recipe2_data.get('servings', 0)
        if servings1 > 0 and servings2 > 0:
            servings_sim = 1.0 if abs(servings1 - servings2) <= 2 else 0.5
        else:
            servings_sim = 0.5
        scores.append(servings_sim * 0.1)
        
        # Difficulty similarity
        diff1 = recipe1.difficulty
        diff2 = recipe2_data.get('difficulty', 0)
        if diff1 > 0 and diff2 > 0:
            diff_sim = 1.0 if abs(diff1 - diff2) <= 1 else 0.5
        else:
            diff_sim = 0.5
        scores.append(diff_sim * 0.1)
        
        return sum(scores)


# Global instance
recipe_deduplicator = RecipeDeduplicator()
