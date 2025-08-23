from supabase import create_client, Client
from typing import Optional, List, Dict, Any
import asyncio
from functools import wraps

from app.core.settings import settings

class SupabaseService:
    """Service class for Supabase database operations"""
    
    def __init__(self):
        self.client: Client = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        self.service_client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_key
        )
    
    def get_client(self, use_service_key: bool = False) -> Client:
        """Get Supabase client (service key for admin operations)"""
        return self.service_client if use_service_key else self.client
    
    async def execute_query(self, table: str, operation: str, data: Optional[Dict] = None,
                          filters: Optional[Dict] = None, use_service_key: bool = False) -> Dict[str, Any]:
        """Execute database query asynchronously"""
        def _execute():
            client = self.get_client(use_service_key)
            query = client.table(table)

            if operation == "select":
                query = query.select('*')
                if filters:
                    for key, value in filters.items():
                        if isinstance(value, list):
                            query = query.in_(key, value)
                        else:
                            query = query.eq(key, value)
                return query.execute()

            elif operation == "insert":
                return query.insert(data).execute()

            elif operation == "update":
                query = query.update(data)
                if filters:
                    for key, value in filters.items():
                        query = query.eq(key, value)
                return query.execute()

            elif operation == "delete":
                if filters:
                    for key, value in filters.items():
                        query = query.eq(key, value)
                return query.delete().execute()

            else:
                raise ValueError(f"Unsupported operation: {operation}")

        # Run in thread pool to avoid blocking
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)
    
    async def get_recipes(self, filters: Optional[Dict] = None, limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """Get recipes with optional filtering"""
        def _execute():
            client = self.get_client()
            try:
                # Build the query
                query = client.table('recipes').select('*')

                # Apply filters if provided
                if filters:
                    for key, value in filters.items():
                        if isinstance(value, list):
                            query = query.in_(key, value)
                        else:
                            query = query.eq(key, value)

                # Apply limit and offset
                if limit:
                    query = query.limit(limit)
                if offset:
                    query = query.offset(offset)

                # Execute the query
                result = query.execute()

                print(f"Query successful! Result: {result}")
                return result

            except Exception as e:
                print(f"Supabase query error: {str(e)}")
                print(f"Error type: {type(e)}")
                import traceback
                traceback.print_exc()
                raise e

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)
    
    async def get_recipe_by_id(self, recipe_id: str) -> Dict[str, Any]:
        """Get single recipe by ID"""
        def _execute():
            client = self.get_client()
            try:
                # Simple select by ID first
                recipe_result = client.table('recipes').select('*').eq('id', recipe_id).execute()
                if not recipe_result.data:
                    return {"data": None}

                recipe = recipe_result.data[0]
                return {"data": [recipe]}
            except Exception as e:
                print(f"Supabase query error: {str(e)}")
                raise e

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def get_recipe_ingredients(self, recipe_id: str) -> Dict[str, Any]:
        """Get ingredients for a specific recipe"""
        def _execute():
            client = self.get_client()
            try:
                # Get ingredients ordered by their order field
                ingredients_result = client.table('ingredients').select('*').eq('recipe_id', recipe_id).order('order').execute()
                return {"data": ingredients_result.data}
            except Exception as e:
                print(f"Supabase ingredients query error: {str(e)}")
                raise e

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)
    
    async def search_recipes_by_text(self, query: str, chef_id: Optional[str] = None,
                                   limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """Search recipes by text query"""
        def _execute():
            client = self.get_client()
            try:
                # Build search query
                search_query = client.table('recipes').select('*')

                # Add chef filter if provided
                if chef_id:
                    search_query = search_query.eq('chef_id', chef_id)

                # Apply limit and offset
                if limit:
                    search_query = search_query.limit(limit)
                if offset:
                    search_query = search_query.offset(offset)

                return search_query.execute()
            except Exception as e:
                print(f"Supabase search error: {str(e)}")
                raise e

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)
    
    async def get_chef_config(self, chef_id: str) -> Dict[str, Any]:
        """Get chef configuration"""
        return await self.execute_query('chefs', 'select', filters={'id': chef_id})
    
    async def create_recipe(self, recipe_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create new recipe with ingredients"""
        def _execute():
            client = self.get_client(use_service_key=True)
            
            # Extract ingredients from recipe data
            ingredients = recipe_data.pop('ingredients', [])
            nutrition = recipe_data.pop('nutrition', None)
            
            # Insert recipe
            recipe_result = client.table('recipes').insert(recipe_data).execute()
            if not recipe_result.data:
                raise Exception("Failed to create recipe")
            
            recipe_id = recipe_result.data[0]['id']
            
            # Insert ingredients
            if ingredients:
                for ingredient in ingredients:
                    ingredient['recipe_id'] = recipe_id
                client.table('ingredients').insert(ingredients).execute()
            
            # Insert nutrition if provided
            if nutrition:
                nutrition['recipe_id'] = recipe_id
                client.table('nutrition').insert(nutrition).execute()
            
            return recipe_result
        
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

# Global instance
supabase_service = SupabaseService()
