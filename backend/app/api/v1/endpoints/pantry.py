from typing import List

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.pantry import PantryItem, PantryItemInput, RecipeShoppingRequest, ShoppingList, ShoppingListItem, ShoppingListItemInput
from app.services.database import supabase_service

router = APIRouter()


def _require_confirmed_camera(item: PantryItemInput) -> None:
    if item.source == 'camera' and ((item.confidence or 0) < .7 or not item.confirmed):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail='Low-confidence camera items require explicit confirmation')


@router.get('/pantry', response_model=List[PantryItem])
async def get_pantry(current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    return await supabase_service.get_pantry_items(current_user.id, tenant.chef_id)


@router.post('/pantry', response_model=PantryItem, status_code=status.HTTP_201_CREATED)
async def add_pantry_item(item: PantryItemInput, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    _require_confirmed_camera(item)
    return await supabase_service.create_pantry_item(current_user.id, tenant.chef_id, item.model_dump(mode='json'))


@router.put('/pantry/{item_id}', response_model=PantryItem)
async def update_pantry_item(item_id: str, item: PantryItemInput, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    _require_confirmed_camera(item)
    result = await supabase_service.update_pantry_item(item_id, current_user.id, tenant.chef_id, item.model_dump(mode='json'))
    if not result:
        raise HTTPException(status_code=404, detail='Pantry item not found')
    return result


@router.delete('/pantry/{item_id}', status_code=status.HTTP_204_NO_CONTENT)
async def delete_pantry_item(item_id: str, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    await supabase_service.delete_pantry_item(item_id, current_user.id, tenant.chef_id)


@router.get('/shopping-list', response_model=ShoppingList)
async def get_shopping_list(current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    return ShoppingList(items=await supabase_service.get_shopping_list_items(current_user.id, tenant.chef_id))


@router.post('/shopping-list', response_model=ShoppingListItem, status_code=status.HTTP_201_CREATED)
async def add_shopping_item(item: ShoppingListItemInput, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    return await supabase_service.create_shopping_list_item(current_user.id, tenant.chef_id, item.model_dump())


@router.put('/shopping-list/{item_id}', response_model=ShoppingListItem)
async def update_shopping_item(item_id: str, item: ShoppingListItemInput, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    result = await supabase_service.update_shopping_list_item(item_id, current_user.id, tenant.chef_id, item.model_dump())
    if not result:
        raise HTTPException(status_code=404, detail='Shopping list item not found')
    return result


@router.post('/shopping-list/from-recipe/{recipe_id}', response_model=ShoppingList)
async def add_recipe_to_shopping_list(recipe_id: str, request: RecipeShoppingRequest, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    recipe = await supabase_service.get_recipe_by_id(recipe_id, tenant.chef_id)
    rows = recipe.get('data') or []
    if not rows:
        raise HTTPException(status_code=404, detail='Recipe not found')
    return ShoppingList(items=await supabase_service.add_recipe_missing_ingredients(current_user.id, tenant.chef_id, rows[0], request.servings))
