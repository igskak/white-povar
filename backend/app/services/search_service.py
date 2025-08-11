from typing import List, Dict, Any, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func, text
from ..models.recipe import Recipe
from ..models.ingredient import Ingredient
from ..models.chef import Chef
import logging

logger = logging.getLogger(__name__)

class SearchService:
    def __init__(self, db: Session):
        self.db = db
    
    async def search_recipes(
        self,
        query: Optional[str] = None,
        cuisine: Optional[str] = None,
        category: Optional[str] = None,
        difficulty: Optional[int] = None,
        max_prep_time: Optional[int] = None,
        max_cook_time: Optional[int] = None,
        max_total_time: Optional[int] = None,
        dietary_restrictions: Optional[List[str]] = None,
        ingredients: Optional[List[str]] = None,
        chef_id: Optional[str] = None,
        is_featured: Optional[bool] = None,
        tags: Optional[List[str]] = None,
        min_servings: Optional[int] = None,
        max_servings: Optional[int] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
        page: int = 1,
        page_size: int = 20
    ) -> Tuple[List[Recipe], int]:
        """
        Advanced recipe search with multiple filters and full-text search
        """
        
        # Start with base query
        query_builder = self.db.query(Recipe)
        
        # Apply filters
        filters = []
        
        # Full-text search across title, description
        if query:
            search_filter = or_(
                Recipe.title.ilike(f"%{query}%"),
                Recipe.description.ilike(f"%{query}%"),
                Recipe.instructions.op("@>")(f'["{query}"]'),  # Search in instructions array
                Recipe.tags.op("@>")(f'["{query}"]')  # Search in tags array
            )
            filters.append(search_filter)
        
        # Cuisine filter
        if cuisine:
            filters.append(Recipe.cuisine.ilike(f"%{cuisine}%"))
        
        # Category filter
        if category:
            filters.append(Recipe.category.ilike(f"%{category}%"))
        
        # Difficulty filter
        if difficulty:
            filters.append(Recipe.difficulty == difficulty)
        
        # Time filters
        if max_prep_time:
            filters.append(Recipe.prep_time_minutes <= max_prep_time)
        
        if max_cook_time:
            filters.append(Recipe.cook_time_minutes <= max_cook_time)
        
        if max_total_time:
            filters.append(Recipe.total_time_minutes <= max_total_time)
        
        # Servings filters
        if min_servings:
            filters.append(Recipe.servings >= min_servings)
        
        if max_servings:
            filters.append(Recipe.servings <= max_servings)
        
        # Chef filter
        if chef_id:
            filters.append(Recipe.chef_id == chef_id)
        
        # Featured filter
        if is_featured is not None:
            filters.append(Recipe.is_featured == is_featured)
        
        # Tags filter
        if tags:
            for tag in tags:
                filters.append(Recipe.tags.op("@>")(f'["{tag}"]'))
        
        # Dietary restrictions filter (search in tags and ingredients)
        if dietary_restrictions:
            dietary_filters = []
            for restriction in dietary_restrictions:
                dietary_filters.append(Recipe.tags.op("@>")(f'["{restriction}"]'))
            filters.append(or_(*dietary_filters))
        
        # Ingredients filter (recipes that contain specific ingredients)
        if ingredients:
            ingredient_subquery = self.db.query(Ingredient.recipe_id).filter(
                or_(*[Ingredient.name.ilike(f"%{ing}%") for ing in ingredients])
            ).subquery()
            filters.append(Recipe.id.in_(ingredient_subquery))
        
        # Apply all filters
        if filters:
            query_builder = query_builder.filter(and_(*filters))
        
        # Get total count before pagination
        total_count = query_builder.count()
        
        # Apply sorting
        sort_column = getattr(Recipe, sort_by, Recipe.created_at)
        if sort_order.lower() == "desc":
            query_builder = query_builder.order_by(sort_column.desc())
        else:
            query_builder = query_builder.order_by(sort_column.asc())
        
        # Apply pagination
        offset = (page - 1) * page_size
        recipes = query_builder.offset(offset).limit(page_size).all()
        
        return recipes, total_count
    
    async def get_search_suggestions(
        self,
        query: str,
        limit: int = 10
    ) -> Dict[str, List[str]]:
        """
        Get search suggestions for autocomplete
        """
        
        suggestions = {
            "recipes": [],
            "cuisines": [],
            "ingredients": [],
            "tags": []
        }
        
        # Recipe title suggestions
        recipe_titles = self.db.query(Recipe.title).filter(
            Recipe.title.ilike(f"%{query}%")
        ).limit(limit).all()
        suggestions["recipes"] = [title[0] for title in recipe_titles]
        
        # Cuisine suggestions
        cuisines = self.db.query(Recipe.cuisine).filter(
            Recipe.cuisine.ilike(f"%{query}%")
        ).distinct().limit(limit).all()
        suggestions["cuisines"] = [cuisine[0] for cuisine in cuisines if cuisine[0]]
        
        # Ingredient suggestions
        ingredients = self.db.query(Ingredient.name).filter(
            Ingredient.name.ilike(f"%{query}%")
        ).distinct().limit(limit).all()
        suggestions["ingredients"] = [ing[0] for ing in ingredients]
        
        # Tag suggestions (flatten tags array and search)
        # This is a simplified version - in production you'd want a proper tags table
        tag_query = text("""
            SELECT DISTINCT unnest(tags) as tag 
            FROM recipes 
            WHERE unnest(tags) ILIKE :query 
            LIMIT :limit
        """)
        tag_results = self.db.execute(tag_query, {"query": f"%{query}%", "limit": limit})
        suggestions["tags"] = [row[0] for row in tag_results]
        
        return suggestions
    
    async def get_popular_searches(self, limit: int = 10) -> List[str]:
        """
        Get popular search terms (simplified - in production you'd track search analytics)
        """
        
        # For now, return popular cuisines and categories
        popular_cuisines = self.db.query(Recipe.cuisine, func.count(Recipe.id)).filter(
            Recipe.cuisine.isnot(None)
        ).group_by(Recipe.cuisine).order_by(func.count(Recipe.id).desc()).limit(limit).all()
        
        return [cuisine[0] for cuisine in popular_cuisines if cuisine[0]]
    
    async def get_filter_options(self) -> Dict[str, Any]:
        """
        Get available filter options for the search interface
        """
        
        # Get unique cuisines
        cuisines = self.db.query(Recipe.cuisine).filter(
            Recipe.cuisine.isnot(None)
        ).distinct().all()
        
        # Get unique categories
        categories = self.db.query(Recipe.category).filter(
            Recipe.category.isnot(None)
        ).distinct().all()
        
        # Get difficulty range
        difficulty_range = self.db.query(
            func.min(Recipe.difficulty),
            func.max(Recipe.difficulty)
        ).first()
        
        # Get time ranges
        time_ranges = self.db.query(
            func.min(Recipe.prep_time_minutes),
            func.max(Recipe.prep_time_minutes),
            func.min(Recipe.cook_time_minutes),
            func.max(Recipe.cook_time_minutes),
            func.min(Recipe.total_time_minutes),
            func.max(Recipe.total_time_minutes)
        ).first()
        
        # Get servings range
        servings_range = self.db.query(
            func.min(Recipe.servings),
            func.max(Recipe.servings)
        ).first()
        
        # Get popular tags (simplified)
        popular_tags_query = text("""
            SELECT unnest(tags) as tag, COUNT(*) as count
            FROM recipes 
            WHERE tags IS NOT NULL 
            GROUP BY unnest(tags) 
            ORDER BY count DESC 
            LIMIT 20
        """)
        popular_tags_result = self.db.execute(popular_tags_query)
        popular_tags = [row[0] for row in popular_tags_result]
        
        return {
            "cuisines": [c[0] for c in cuisines if c[0]],
            "categories": [c[0] for c in categories if c[0]],
            "difficulty_range": {
                "min": difficulty_range[0] or 1,
                "max": difficulty_range[1] or 5
            },
            "time_ranges": {
                "prep_time": {
                    "min": time_ranges[0] or 0,
                    "max": time_ranges[1] or 180
                },
                "cook_time": {
                    "min": time_ranges[2] or 0,
                    "max": time_ranges[3] or 300
                },
                "total_time": {
                    "min": time_ranges[4] or 0,
                    "max": time_ranges[5] or 480
                }
            },
            "servings_range": {
                "min": servings_range[0] or 1,
                "max": servings_range[1] or 12
            },
            "popular_tags": popular_tags,
            "dietary_restrictions": [
                "vegetarian", "vegan", "gluten-free", "dairy-free", 
                "nut-free", "low-carb", "keto", "paleo", "low-sodium"
            ]
        }
    
    async def save_search_query(
        self,
        user_id: str,
        query: str,
        filters: Dict[str, Any],
        results_count: int
    ) -> None:
        """
        Save search query for analytics (simplified - in production you'd have a search_history table)
        """
        # This would typically save to a search_history table
        # For now, we'll just log it
        logger.info(f"Search query: user={user_id}, query='{query}', filters={filters}, results={results_count}")
