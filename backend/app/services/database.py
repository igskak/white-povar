from supabase import create_client, Client
from typing import Optional, List, Dict, Any
import asyncio
from datetime import datetime, timezone
from functools import wraps
import logging

from app.core.settings import settings
from app.schemas.brand_config import validate_brand_config
from pydantic import ValidationError

logger = logging.getLogger(__name__)

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
        """Execute database query asynchronously with proper error handling"""
        try:
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

                # Execute synchronously but wrap in try-catch for better error handling
                result = query.execute()
                logger.debug(f"Query executed successfully: {table} {operation}")
                return result

            elif operation == "insert":
                result = query.insert(data).execute()
                logger.debug(f"Insert executed successfully: {table}")
                return result

            elif operation == "update":
                query = query.update(data)
                if filters:
                    for key, value in filters.items():
                        query = query.eq(key, value)
                result = query.execute()
                logger.debug(f"Update executed successfully: {table}")
                return result

            elif operation == "delete":
                if filters:
                    for key, value in filters.items():
                        query = query.eq(key, value)
                result = query.delete().execute()
                logger.debug(f"Delete executed successfully: {table}")
                return result

            else:
                raise ValueError(f"Unsupported operation: {operation}")

        except Exception as e:
            logger.error(f"Database query error: {table} {operation} - {str(e)}")
            raise e
    
    async def get_recipes(self, filters: Optional[Dict] = None, limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """Get recipes with optional filtering"""
        try:
            client = self.get_client(use_service_key=True)

            # Build the query with JOIN to include ingredients
            query = client.table('recipes').select('''
                *,
                recipe_ingredients(*)
            ''')

            # Apply filters if provided
            if filters:
                for key, value in filters.items():
                    if key == 'max_time':
                        query = query.lte('total_time_minutes', value)
                    elif key == 'tags_contains':
                        query = query.contains('tags', value)
                    elif isinstance(value, list):
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
            logger.debug(f"Get recipes query successful: {len(result.data) if result.data else 0} recipes")
            return result

        except Exception as e:
            logger.error(f"Supabase get_recipes error: {str(e)}")
            raise e

    async def get_active_tenant(self, tenant_slug: str) -> Optional[Dict[str, Any]]:
        """Resolve an active tenant once; callers must never accept a raw chef id."""
        client = self.get_client(use_service_key=True)
        result = (
            client.table('chefs').select('id,slug').eq('slug', tenant_slug)
            .eq('is_active', True).limit(1).execute()
        )
        return (result.data or [None])[0]

    async def get_published_collections(self, chef_id: str, limit: int, offset: int):
        """Return only consumer-visible collection metadata in a stable order."""
        return (
            self.get_client(use_service_key=True).table('collections')
            .select('*, collection_items(count)', count='exact')
            .eq('chef_id', chef_id).eq('status', 'published')
            .order('published_at', desc=True).order('id')
            .range(offset, offset + limit - 1).execute()
        )

    async def get_published_collection_by_id(self, collection_id: str, chef_id: str):
        """Load one published collection with its reusable recipe-backed items."""
        return (
            self.get_client(use_service_key=True).table('collections')
            .select('*, collection_items(id,position,is_preview,content:recipes(*,recipe_ingredients(*),recipe_nutrition(*)))')
            .eq('id', collection_id).eq('chef_id', chef_id).eq('status', 'published')
            .limit(1).execute()
        )

    async def get_commerce_entitlements(self, user_id: str, chef_id: str) -> List[Dict[str, Any]]:
        """Read entitlement scope and authoritative product-content mapping together."""
        result = (
            self.get_client(use_service_key=True).table('commerce_entitlements')
            .select('*, product:products(kind,product_content(collection_id))')
            .eq('user_id', user_id).eq('chef_id', chef_id).execute()
        )
        return result.data or []

    async def get_active_store_products(self, chef_id: str, store: str) -> List[Dict[str, Any]]:
        """Return only identifiers needed by the native store SDK, scoped to a tenant."""
        result = (
            self.get_client(use_service_key=True).table('store_product_mappings')
            .select('store_product_id, product:products(product_key,kind)')
            .eq('chef_id', chef_id).eq('provider', 'revenuecat').eq('store', store)
            .eq('status', 'active').execute()
        )
        return result.data or []

    async def process_revenuecat_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Use the migration-owned transactional RPC for idempotent webhook processing."""
        result = self.get_client(use_service_key=True).rpc(
            'process_revenuecat_event', {'event_payload': event}
        ).execute()
        return (result.data or [{}])[0]

    async def get_preference_profile(self, user_id: str, chef_id: str) -> Optional[Dict[str, Any]]:
        result = await self.execute_query(
            'user_preference_profiles', 'select',
            filters={'user_id': user_id, 'chef_id': chef_id}, use_service_key=True,
        )
        return (result.data or [None])[0]

    async def upsert_preference_profile(self, user_id: str, chef_id: str, data: Dict[str, Any]):
        payload = {'user_id': user_id, 'chef_id': chef_id, **data}
        client = self.get_client(use_service_key=True)
        return client.table('user_preference_profiles').upsert(
            payload, on_conflict='user_id,chef_id'
        ).execute()

    async def delete_preference_profile(self, user_id: str, chef_id: str):
        return await self.execute_query(
            'user_preference_profiles', 'delete',
            filters={'user_id': user_id, 'chef_id': chef_id}, use_service_key=True,
        )

    async def analytics_consent(self, user_id: str, chef_id: str) -> bool:
        result = await self.execute_query('analytics_consents', 'select', filters={
            'user_id': user_id, 'chef_id': chef_id,
        }, use_service_key=True)
        return bool((result.data or [{}])[0].get('analytics_consent'))

    async def set_analytics_consent(self, user_id: str, chef_id: str, consent: bool):
        return self.get_client(use_service_key=True).table('analytics_consents').upsert({
            'user_id': user_id, 'chef_id': chef_id, 'analytics_consent': consent,
        }, on_conflict='user_id,chef_id').execute()

    async def record_analytics_event(self, user_id: str, chef_id: str, name: str,
                                     outcome: str, client_version: Optional[str] = None) -> None:
        """Write an allowlisted aggregate event only after tenant-scoped consent."""
        if not await self.analytics_consent(user_id, chef_id):
            return
        self.get_client(use_service_key=True).table('analytics_events').insert({
            'user_id': user_id, 'chef_id': chef_id, 'name': name,
            'outcome': outcome, 'client_version': client_version,
        }).execute()

    async def get_generated_recipe_drafts(self, user_id: str, chef_id: str) -> List[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('generated_recipe_drafts').select('*')
                  .eq('user_id', user_id).eq('chef_id', chef_id)
                  .order('updated_at', desc=True).execute())
        return result.data or []

    async def create_generated_recipe_draft(self, user_id: str, chef_id: str, recipe: Dict[str, Any], allergen_warning: str) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).table('generated_recipe_drafts').insert({
            'user_id': user_id, 'chef_id': chef_id, 'recipe': recipe,
            'allergen_warning': allergen_warning,
        }).execute()
        return result.data[0]

    async def update_generated_recipe_draft(self, draft_id: str, user_id: str, chef_id: str, recipe: Dict[str, Any], allergen_warning: str) -> Optional[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('generated_recipe_drafts').update({
            'recipe': recipe, 'allergen_warning': allergen_warning, 'updated_at': 'now()',
        }).eq('id', draft_id).eq('user_id', user_id).eq('chef_id', chef_id).execute())
        return (result.data or [None])[0]

    async def delete_generated_recipe_draft(self, draft_id: str, user_id: str, chef_id: str):
        """Hard-delete the draft and its cascading feedback; no recoverable user content remains."""
        return await self.execute_query('generated_recipe_drafts', 'delete', filters={
            'id': draft_id, 'user_id': user_id, 'chef_id': chef_id,
        }, use_service_key=True)

    async def add_generated_recipe_draft_feedback(self, draft_id: str, user_id: str, chef_id: str, feedback: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        draft = (self.get_client(use_service_key=True).table('generated_recipe_drafts').select('id')
                 .eq('id', draft_id).eq('user_id', user_id).eq('chef_id', chef_id).limit(1).execute())
        if not draft.data:
            return None
        result = self.get_client(use_service_key=True).table('generated_recipe_draft_feedback').insert({
            'draft_id': draft_id, 'rating': feedback['rating'],
            'safety_issue': feedback['safety_issue'], 'comment': feedback.get('comment'),
        }).execute()
        return result.data[0]

    async def get_pantry_items(self, user_id: str, chef_id: str) -> List[Dict[str, Any]]:
        client = self.get_client(use_service_key=True)
        result = (client.table('pantry_items').select('*').eq('user_id', user_id)
                  .eq('chef_id', chef_id).order('name').execute())
        return result.data or []

    async def create_pantry_item(self, user_id: str, chef_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).table('pantry_items').insert(
            {'user_id': user_id, 'chef_id': chef_id, **data}
        ).execute()
        return result.data[0]

    async def update_pantry_item(self, item_id: str, user_id: str, chef_id: str, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('pantry_items').update(data)
                  .eq('id', item_id).eq('user_id', user_id).eq('chef_id', chef_id).execute())
        return (result.data or [None])[0]

    async def delete_pantry_item(self, item_id: str, user_id: str, chef_id: str):
        return await self.execute_query('pantry_items', 'delete', filters={'id': item_id, 'user_id': user_id, 'chef_id': chef_id}, use_service_key=True)

    async def get_shopping_list_items(self, user_id: str, chef_id: str) -> List[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('shopping_list_items').select('*')
                  .eq('user_id', user_id).eq('chef_id', chef_id).order('checked').order('category').order('name').execute())
        return result.data or []

    async def create_shopping_list_item(self, user_id: str, chef_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).table('shopping_list_items').insert(
            {'user_id': user_id, 'chef_id': chef_id, **data}
        ).execute()
        return result.data[0]

    async def update_shopping_list_item(self, item_id: str, user_id: str, chef_id: str, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('shopping_list_items').update(data)
                  .eq('id', item_id).eq('user_id', user_id).eq('chef_id', chef_id).execute())
        return (result.data or [None])[0]

    async def add_recipe_missing_ingredients(self, user_id: str, chef_id: str, recipe: Dict[str, Any], servings: int) -> List[Dict[str, Any]]:
        pantry = await self.get_pantry_items(user_id, chef_id)
        pantry_names = {str(item['name']).strip().lower() for item in pantry}
        factor = servings / max(int(recipe.get('servings') or 1), 1)
        missing = []
        for ingredient in recipe.get('recipe_ingredients') or []:
            name = str(ingredient.get('display_name') or '').strip().lower()
            if not name or name in pantry_names:
                continue
            amount = ingredient.get('amount')
            missing.append({
                'user_id': user_id, 'chef_id': chef_id, 'recipe_id': recipe['id'], 'name': name,
                'quantity': float(amount) * factor if amount else None,
                'unit': ingredient.get('unit_id'), 'category': 'Інше', 'checked': False,
            })
        if missing:
            self.get_client(use_service_key=True).table('shopping_list_items').insert(missing).execute()
        return await self.get_shopping_list_items(user_id, chef_id)
    
    async def get_recipe_by_id(self, recipe_id: str, chef_id: str) -> Dict[str, Any]:
        """Get one recipe only inside an already resolved tenant."""
        try:
            client = self.get_client(use_service_key=True)

            # Select recipe with ingredients using JOIN
            recipe_result = client.table('recipes').select('''
                *,
                recipe_ingredients(*),
                recipe_nutrition(*)
            ''').eq('id', recipe_id).eq('chef_id', chef_id).execute()

            if not recipe_result.data:
                return {"data": None}

            logger.debug(f"Get recipe by ID successful: {recipe_id}")
            return {"data": recipe_result.data}

        except Exception as e:
            logger.error(f"Supabase get_recipe_by_id error: {str(e)}")
            raise e

    async def get_recipe_ingredients(self, recipe_id: str) -> Dict[str, Any]:
        """Get ingredients for a specific recipe"""
        def _execute():
            client = self.get_client(use_service_key=True)
            try:
                # Get ingredients ordered by their order field
                ingredients_result = client.table('recipe_ingredients').select('*').eq('recipe_id', recipe_id).order('sort_order').execute()
                return {"data": ingredients_result.data}
            except Exception as e:
                print(f"Supabase ingredients query error: {str(e)}")
                raise e

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)
    
    async def search_recipes_by_text(self, query: str, chef_id: str,
                                   limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """Search recipes by text query"""
        try:
            client = self.get_client(use_service_key=True)

            # Build search query with actual text search
            search_query = client.table('recipes').select('''
                *,
                recipe_ingredients(*)
            ''').eq('is_public', True)

            # Add text search filters - search in title, description, and tags
            search_query = search_query.or_(
                f'title.ilike.%{query}%,'
                f'description.ilike.%{query}%,'
                f'tags.cs.{{{query}}}'
            )

            # Tenant scope is mandatory: a client cannot opt out of it.
            search_query = search_query.eq('chef_id', chef_id)

            # Apply limit and offset
            if limit:
                search_query = search_query.limit(limit)
            if offset:
                search_query = search_query.offset(offset)

            result = search_query.execute()
            logger.debug(f"Search recipes successful: query='{query}', results={len(result.data) if result.data else 0}")
            return result

        except Exception as e:
            logger.error(f"Supabase search_recipes_by_text error: {str(e)}")
            raise e

    async def search_catalog_recipes(
        self,
        *,
        chef_id: str,
        query_text: Optional[str] = None,
        tags: Optional[List[str]] = None,
        difficulty: Optional[int] = None,
        max_total_time: Optional[int] = None,
        is_featured: Optional[bool] = None,
        limit: int = 20,
        offset: int = 0,
    ) -> Dict[str, Any]:
        """Query discovery rows in the database, never by downloading a catalog.

        The ordering includes the primary key as a tie breaker so consecutive
        offset pages cannot duplicate rows when timestamps match.
        """
        try:
            client = self.get_client(use_service_key=True)
            request = (
                client.table('recipes')
                .select('*, recipe_ingredients(*), recipe_nutrition(*)', count='exact')
                .eq('chef_id', chef_id)
                .eq('is_public', True)
            )
            if query_text:
                escaped = query_text.replace('%', r'\%').replace(',', ' ')
                request = request.or_(
                    f'title.ilike.%{escaped}%,description.ilike.%{escaped}%,tags.cs.{{{escaped}}}'
                )
            if tags:
                request = request.contains('tags', tags)
            if difficulty is not None:
                request = request.eq('difficulty_level', difficulty)
            if max_total_time is not None:
                request = request.lte('total_time_minutes', max_total_time)
            if is_featured is not None:
                request = request.eq('is_featured', is_featured)

            result = (
                request.order('created_at', desc=True)
                .order('id')
                .range(offset, offset + limit)
                .execute()
            )
            return result
        except Exception as e:
            logger.error(f'Supabase search_catalog_recipes error: {str(e)}')
            raise
    
    async def get_chef_config(self, chef_id: str) -> Dict[str, Any]:
        """Get chef configuration"""
        return await self.execute_query('chefs', 'select', filters={'id': chef_id})

    async def get_tenant_bootstrap(self, tenant_slug: str) -> Dict[str, Any]:
        """Return published runtime configuration without exposing other tenants."""
        try:
            client = self.get_client(use_service_key=True)
            chef_result = (
                client.table('chefs')
                .select('id,slug,is_active')
                .eq('slug', tenant_slug)
                .eq('is_active', True)
                .limit(1)
                .execute()
            )
            chefs = chef_result.data or []
            if not chefs:
                return {'state': 'tenant_not_found'}

            chef = chefs[0]
            brand_result = (
                client.table('brand_configs')
                .select('version,config')
                .eq('chef_id', chef['id'])
                .eq('status', 'published')
                .order('version', desc=True)
                .limit(1)
                .execute()
            )
            product_result = (
                client.table('product_configs')
                .select('version,config')
                .eq('chef_id', chef['id'])
                .eq('status', 'published')
                .order('version', desc=True)
                .limit(1)
                .execute()
            )
            brands = brand_result.data or []
            products = product_result.data or []
            if not brands or not products:
                return {'state': 'config_not_published'}

            brand, product = brands[0], products[0]
            if not isinstance(brand.get('config'), dict) or not isinstance(product.get('config'), dict):
                return {'state': 'config_malformed'}

            try:
                # This is also the publish safety net for legacy/direct database
                # writes: invalid drafts cannot become runtime configuration.
                brand_config = validate_brand_config(brand['config'])
            except ValidationError:
                logger.warning('Published BrandConfig failed validation for tenant %s', tenant_slug)
                return {'state': 'config_malformed'}

            return {
                'state': 'ok',
                'tenant': {'id': chef['id'], 'slug': chef['slug']},
                'brand_config': brand_config,
                'product_config': product['config'],
                'config_version': f"brand-{brand['version']}-product-{product['version']}",
            }
        except Exception:
            logger.exception('Unable to load bootstrap for tenant slug %s', tenant_slug)
            raise

    async def get_studio_role(self, user_id: str, chef_id: str) -> Optional[str]:
        result = (self.get_client(use_service_key=True).table('studio_memberships').select('role')
                  .eq('user_id', user_id).eq('chef_id', chef_id).limit(1).execute())
        rows = result.data or []
        return rows[0].get('role') if rows else None

    async def get_studio_brand_draft(self, chef_id: str) -> Optional[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('studio_brand_drafts')
                  .select('config,version,updated_at').eq('chef_id', chef_id).limit(1).execute())
        rows = result.data or []
        return rows[0] if rows else None

    async def get_published_brand_draft_seed(self, chef_id: str) -> Optional[Dict[str, Any]]:
        result = (self.get_client(use_service_key=True).table('brand_configs').select('config,version,published_at')
                  .eq('chef_id', chef_id).eq('status', 'published').order('version', desc=True).limit(1).execute())
        rows = result.data or []
        if not rows:
            return None
        row = rows[0]
        return {'config': row['config'], 'version': row['version'], 'updated_at': row.get('published_at')}

    async def save_studio_brand_draft(self, *, chef_id: str, user_id: str, config: Dict[str, Any], expected_version: int) -> Optional[Dict[str, Any]]:
        """Compare-and-swap a draft so concurrent Studio edits cannot overwrite."""
        result = self.get_client(use_service_key=True).rpc('save_studio_brand_draft', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_config': config,
            'p_expected_version': expected_version,
        }).execute()
        rows = result.data or []
        return rows[0] if rows else None

    async def create_studio_asset(self, *, asset_id: str, chef_id: str, user_id: str, object_path: str, content_type: str, size_bytes: int) -> None:
        self.get_client(use_service_key=True).table('studio_assets').insert({'id': asset_id, 'chef_id': chef_id, 'created_by': user_id, 'source_path': object_path, 'content_type': content_type, 'size_bytes': size_bytes, 'state': 'uploading'}).execute()

    async def get_studio_asset(self, asset_id: str, chef_id: str) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).table('studio_assets').select('*').eq('id', asset_id).eq('chef_id', chef_id).limit(1).execute()
        return (result.data or [None])[0]

    async def list_studio_assets(self, chef_id: str) -> list[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).table('studio_assets').select('*').eq('chef_id', chef_id).eq('state', 'ready').order('created_at', desc=True).execute()
        return result.data or []

    async def finalize_studio_asset(self, asset_id: str, chef_id: str, values: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).table('studio_assets').update(values).eq('id', asset_id).eq('chef_id', chef_id).eq('state', 'uploading').execute()
        return (result.data or [None])[0]

    async def reject_studio_asset(self, asset_id: str, chef_id: str, reason: str) -> None:
        self.get_client(use_service_key=True).table('studio_assets').update({'state': 'rejected', 'rejection_reason': reason}).eq('id', asset_id).eq('chef_id', chef_id).execute()

    async def publish_studio_brand_draft(self, *, chef_id: str, user_id: str, expected_version: int) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).rpc('publish_studio_brand_draft', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_expected_version': expected_version,
        }).execute()
        return (result.data or [None])[0]

    async def rollback_studio_brand_config(self, *, chef_id: str, user_id: str, source_version: int) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).rpc('rollback_studio_brand_config', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_source_version': source_version,
        }).execute()
        return (result.data or [None])[0]

    async def get_studio_release_status(self, chef_id: str) -> Dict[str, Any]:
        client = self.get_client(use_service_key=True)
        config = client.table('brand_configs').select('version,published_at').eq('chef_id', chef_id).eq('status', 'published').limit(1).execute().data or []
        jobs = client.table('studio_release_jobs').select('*').eq('chef_id', chef_id).order('requested_at', desc=True).limit(50).execute().data or []
        return {'config': config[0] if config else None, 'jobs': jobs}

    async def create_studio_release(self, *, chef_id: str, user_id: str, kind: str, platform: Optional[str], config_version: int) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).rpc('create_studio_release_job', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_kind': kind,
            'p_platform': platform, 'p_config_version': config_version,
        }).execute()
        return (result.data or [None])[0]

    async def update_studio_release(self, *, release_id: str, chef_id: str, user_id: str, values: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).rpc('update_studio_release_job', {
            'p_release_id': release_id, 'p_chef_id': chef_id, 'p_user_id': user_id,
            'p_status': values['status'], 'p_store_release_status': values.get('store_release_status'),
            'p_failure_reason': values.get('failure_reason'),
        }).execute()
        return (result.data or [None])[0]

    async def studio_content_rows(self, chef_id: str) -> list[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).table('recipes').select('*').eq('chef_id', chef_id).order('updated_at', desc=True).execute()
        return result.data or []

    async def studio_collection_rows(self, chef_id: str) -> list[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).table('collections').select('*, collection_items(recipe_id,position,is_preview)').eq('chef_id', chef_id).order('updated_at', desc=True).execute()
        return result.data or []

    async def studio_save_content(self, *, chef_id: str, user_id: str, content_id: str | None, values: Dict[str, Any]) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).rpc('studio_save_content', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_content_id': content_id, 'p_values': values,
        }).execute()
        return (result.data or [None])[0]

    async def studio_publish_content(self, *, chef_id: str, user_id: str, content_id: str) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).rpc('studio_publish_content', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_content_id': content_id,
        }).execute()
        return (result.data or [None])[0]

    async def studio_delete_content_impact(self, chef_id: str, content_id: str) -> Dict[str, Any]:
        client = self.get_client(use_service_key=True)
        collections = client.table('collection_items').select('collection_id, collections!inner(id,chef_id,status,title_i18n)').eq('recipe_id', content_id).eq('collections.chef_id', chef_id).execute().data or []
        collection_ids = [row['collection_id'] for row in collections]
        buyers = (client.table('commerce_entitlements').select('id', count='exact').eq('chef_id', chef_id)
                  .in_('collection_id', collection_ids).execute()) if collection_ids else None
        return {'collections': collections, 'buyer_count': (buyers.count or 0) if buyers else 0}

    async def studio_save_collection(self, *, chef_id: str, user_id: str, collection_id: str | None, values: Dict[str, Any]) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).rpc('studio_save_collection', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_collection_id': collection_id, 'p_values': values,
        }).execute()
        return (result.data or [None])[0]

    async def studio_publish_collection(self, *, chef_id: str, user_id: str, collection_id: str) -> Optional[Dict[str, Any]]:
        result = self.get_client(use_service_key=True).rpc('studio_publish_collection', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_collection_id': collection_id,
        }).execute()
        return (result.data or [None])[0]

    async def studio_save_merchandising(self, *, chef_id: str, user_id: str, values: Dict[str, Any]) -> Dict[str, Any]:
        result = self.get_client(use_service_key=True).rpc('studio_save_merchandising', {
            'p_chef_id': chef_id, 'p_user_id': user_id, 'p_values': values,
        }).execute()
        return (result.data or [None])[0]

    # Video-related methods
    async def create_recipe_video(self, video_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new recipe video record"""
        try:
            client = self.get_client(use_service_key=True)
            result = client.table('recipe_videos').insert(video_data).execute()
            logger.debug(f"Create recipe video successful: {video_data.get('filename')}")
            return result
        except Exception as e:
            logger.error(f"Supabase create_recipe_video error: {str(e)}")
            raise e

    async def get_recipe_videos(self, recipe_id: str) -> Dict[str, Any]:
        """Get all active videos for a recipe"""
        try:
            client = self.get_client()
            result = client.table('recipe_videos').select('*').eq('recipe_id', recipe_id).eq('is_active', True).order('uploaded_at', desc=True).execute()
            logger.debug(f"Get recipe videos successful: {recipe_id}")
            return result
        except Exception as e:
            logger.error(f"Supabase get_recipe_videos error: {str(e)}")
            raise e

    async def get_recipe_video_by_id(self, video_id: str) -> Dict[str, Any]:
        """Get a specific video by ID"""
        try:
            client = self.get_client()
            result = client.table('recipe_videos').select('*').eq('id', video_id).execute()
            logger.debug(f"Get recipe video by ID successful: {video_id}")
            return result
        except Exception as e:
            logger.error(f"Supabase get_recipe_video_by_id error: {str(e)}")
            raise e

    async def update_recipe_video(self, video_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update a recipe video"""
        try:
            client = self.get_client(use_service_key=True)
            result = client.table('recipe_videos').update(update_data).eq('id', video_id).execute()
            logger.debug(f"Update recipe video successful: {video_id}")
            return result
        except Exception as e:
            logger.error(f"Supabase update_recipe_video error: {str(e)}")
            raise e

    async def update_recipe(self, recipe_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update a recipe"""
        try:
            client = self.get_client(use_service_key=True)
            result = client.table('recipes').update(update_data).eq('id', recipe_id).execute()
            logger.debug(f"Update recipe successful: {recipe_id}")
            return result
        except Exception as e:
            logger.error(f"Supabase update_recipe error: {str(e)}")
            raise e
    
    async def create_recipe(self, recipe_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a recipe and its canonical ingredient/nutrition records."""
        def _execute():
            client = self.get_client(use_service_key=True)

            # Extract ingredients from recipe data
            recipe_row = dict(recipe_data)
            ingredients = recipe_row.pop('ingredients', [])
            nutrition = recipe_row.pop('nutrition', None)

            # Insert recipe
            recipe_result = client.table('recipes').insert(recipe_row).execute()
            if not recipe_result.data:
                raise Exception("Failed to create recipe")

            recipe_id = recipe_result.data[0]['id']

            # Insert ingredients
            if ingredients:
                ingredient_rows = [
                    {**ingredient, 'recipe_id': recipe_id}
                    for ingredient in ingredients
                ]
                client.table('recipe_ingredients').insert(ingredient_rows).execute()

            # Insert nutrition if provided
            if nutrition:
                nutrition_row = {**nutrition, 'recipe_id': recipe_id}
                client.table('recipe_nutrition').insert(nutrition_row).execute()

            return recipe_result

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def update_owned_recipe(
        self,
        recipe_id: str,
        chef_id: str,
        recipe_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Update a recipe owned by ``chef_id`` and replace supplied child rows."""
        def _execute():
            client = self.get_client(use_service_key=True)
            recipe_row = dict(recipe_data)
            ingredients = recipe_row.pop('ingredients', None)
            nutrition = recipe_row.pop('nutrition', None)

            query = client.table('recipes').update(recipe_row).eq('id', recipe_id).eq('chef_id', chef_id)
            recipe_result = query.execute()
            if not recipe_result.data:
                return recipe_result

            if ingredients is not None:
                client.table('recipe_ingredients').delete().eq('recipe_id', recipe_id).execute()
                if ingredients:
                    rows = [{**ingredient, 'recipe_id': recipe_id} for ingredient in ingredients]
                    client.table('recipe_ingredients').insert(rows).execute()

            if nutrition is not None:
                client.table('recipe_nutrition').delete().eq('recipe_id', recipe_id).execute()
                if nutrition:
                    client.table('recipe_nutrition').insert(
                        {**nutrition, 'recipe_id': recipe_id}
                    ).execute()

            return recipe_result

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def delete_owned_recipe(self, recipe_id: str, chef_id: str) -> Dict[str, Any]:
        """Delete a recipe only when it belongs to ``chef_id``."""
        return await self.execute_query(
            'recipes',
            'delete',
            filters={'id': recipe_id, 'chef_id': chef_id},
            use_service_key=True,
        )

    async def get_user_chef_id(self, user_id: str) -> Optional[str]:
        """Return the chef explicitly linked to a user, if one exists."""
        result = await self.execute_query(
            'users',
            'select',
            filters={'id': user_id},
            use_service_key=True,
        )
        if not result.data:
            return None
        chef_id = result.data[0].get('chef_id')
        return str(chef_id) if chef_id else None

    async def get_user_favorite_ids(self, user_id: str) -> List[str]:
        """Return recipe IDs from the canonical user_favorites junction table."""
        result = await self.execute_query(
            'user_favorites', 'select', filters={'user_id': user_id}, use_service_key=True
        )
        return [str(row['recipe_id']) for row in (result.data or [])]

    async def toggle_user_favorite(self, user_id: str, recipe_id: str) -> bool:
        """Toggle one user/recipe favorite pair and return its new state."""
        existing = await self.execute_query(
            'user_favorites',
            'select',
            filters={'user_id': user_id, 'recipe_id': recipe_id},
            use_service_key=True,
        )
        if existing.data:
            await self.execute_query(
                'user_favorites',
                'delete',
                filters={'user_id': user_id, 'recipe_id': recipe_id},
                use_service_key=True,
            )
            return False

        await self.execute_query(
            'user_favorites',
            'insert',
            data={'user_id': user_id, 'recipe_id': recipe_id},
            use_service_key=True,
        )
        return True

    async def set_user_favorite(
        self, user_id: str, recipe_id: str, is_favorite: bool
    ) -> bool:
        """Idempotently persist the requested favorite state.

        The consumer sends a desired state rather than a toggle so retries and
        rapid taps cannot invert the final server state.
        """
        if not is_favorite:
            await self.execute_query(
                'user_favorites',
                'delete',
                filters={'user_id': user_id, 'recipe_id': recipe_id},
                use_service_key=True,
            )
            return False

        def _execute():
            client = self.get_client(use_service_key=True)
            return client.table('user_favorites').upsert(
                {'user_id': user_id, 'recipe_id': recipe_id},
                on_conflict='user_id,recipe_id',
            ).execute()

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _execute)
        return True

    async def record_recipe_history(
        self, user_id: str, chef_id: str, recipe_id: str, event: str
    ) -> None:
        """Upsert a private view/cook event scoped to the resolved tenant."""
        field = {'viewed': 'viewed_at', 'cooked': 'cooked_at'}[event]

        def _execute():
            client = self.get_client(use_service_key=True)
            return client.table('user_recipe_history').upsert(
                {
                    'user_id': user_id,
                    'chef_id': chef_id,
                    'recipe_id': recipe_id,
                    field: datetime.now(timezone.utc).isoformat(),
                    'updated_at': datetime.now(timezone.utc).isoformat(),
                },
                on_conflict='user_id,chef_id,recipe_id',
            ).execute()

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _execute)

    # Ingestion-related methods
    async def create_ingestion_job(self, job_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new ingestion job"""
        def _execute():
            client = self.get_client(use_service_key=True)
            return client.table('ingestion_jobs').insert(job_data).execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def update_ingestion_job(self, job_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
        """Update an ingestion job"""
        def _execute():
            client = self.get_client(use_service_key=True)
            return client.table('ingestion_jobs').update(updates).eq('id', job_id).execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def get_ingestion_job(self, job_id: str) -> Dict[str, Any]:
        """Get ingestion job by ID"""
        def _execute():
            client = self.get_client()
            return client.table('ingestion_jobs').select('*').eq('id', job_id).execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def get_ingestion_jobs(self, status: Optional[str] = None, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """Get ingestion jobs with optional status filter"""
        def _execute():
            client = self.get_client()
            query = client.table('ingestion_jobs').select('*')

            if status:
                query = query.eq('status', status)

            query = query.order('created_at', desc=True).limit(limit).offset(offset)
            return query.execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def create_recipe_fingerprint(self, fingerprint_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create or update recipe fingerprint"""
        def _execute():
            client = self.get_client(use_service_key=True)
            # Use upsert to handle duplicates
            return client.table('recipe_fingerprints').upsert(fingerprint_data).execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def find_duplicate_recipes(self, fingerprint_hash: str) -> Dict[str, Any]:
        """Find recipes with matching fingerprint"""
        def _execute():
            client = self.get_client()
            return client.table('recipe_fingerprints').select('recipe_id').eq('fingerprint_hash', fingerprint_hash).execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def find_similar_recipes(self, title_normalized: str, cuisine_normalized: str, total_time_minutes: int, time_tolerance: int = 10) -> Dict[str, Any]:
        """Find potentially similar recipes for fuzzy duplicate detection"""
        def _execute():
            client = self.get_client()
            time_min = max(0, total_time_minutes - time_tolerance)
            time_max = total_time_minutes + time_tolerance

            return client.table('recipe_fingerprints').select('recipe_id, title_normalized').eq('cuisine_normalized', cuisine_normalized).gte('total_time_minutes', time_min).lte('total_time_minutes', time_max).execute()

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def create_recipe_with_ingredients(self, recipe_data: Dict[str, Any], ingredients: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Create recipe with ingredients using the proper recipe_ingredients table"""
        def _execute():
            client = self.get_client(use_service_key=True)

            # Insert recipe
            recipe_result = client.table('recipes').insert(recipe_data).execute()
            if not recipe_result.data:
                raise Exception("Failed to create recipe")

            recipe_id = recipe_result.data[0]['id']

            # Insert ingredients into recipe_ingredients table
            if ingredients:
                ingredients_to_insert = []

                # Ensure all ingredients have the same structure
                for i, ingredient in enumerate(ingredients):
                    ingredient_data = {
                        'recipe_id': recipe_id,
                        'display_name': ingredient['display_name'],
                        'sort_order': ingredient.get('sort_order', i + 1)
                    }

                    # Add optional fields consistently
                    if 'amount' in ingredient and ingredient['amount'] is not None:
                        ingredient_data['amount'] = ingredient['amount']
                    if 'unit_id' in ingredient and ingredient['unit_id'] is not None:
                        ingredient_data['unit_id'] = ingredient['unit_id']
                    if 'preparation_notes' in ingredient and ingredient['preparation_notes'] is not None:
                        ingredient_data['preparation_notes'] = ingredient['preparation_notes']
                    if 'base_ingredient_id' in ingredient and ingredient['base_ingredient_id'] is not None:
                        ingredient_data['base_ingredient_id'] = ingredient['base_ingredient_id']

                    ingredients_to_insert.append(ingredient_data)

                # Insert ingredients one by one to avoid key mismatch issues
                for ingredient_data in ingredients_to_insert:
                    client.table('recipe_ingredients').insert(ingredient_data).execute()

            return recipe_result

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _execute)

    async def find_base_ingredient_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Find base ingredient by name or alias"""
        def _execute():
            client = self.get_client()
            # Search by exact name match first
            result = client.table('base_ingredients').select('*').ilike('name_en', f'%{name}%').execute()
            return result

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, _execute)
        return result.data[0] if result.data else None

    async def find_unit_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Find unit by name or abbreviation"""
        def _execute():
            client = self.get_client()
            # Search by abbreviation first, then name
            result = client.table('units').select('*').or_(f'abbreviation_en.ilike.%{name}%,name_en.ilike.%{name}%').execute()
            return result

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, _execute)
        return result.data[0] if result.data else None

# Global instance
supabase_service = SupabaseService()
