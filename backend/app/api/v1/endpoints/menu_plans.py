"""Private, tenant-scoped weekly menu plans.

Slots deliberately contain only a recipe reference and display snapshot.  They
are not an entitlement: recipe access remains checked when the user opens it.
"""
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.menu_plan import (
    MenuPlanReorder, MenuPlanShare, MenuPlanShoppingRequest, MenuPlanSlot,
    MenuPlanSlotInput, MenuPlanWeek,
)
from app.services.database import supabase_service

router = APIRouter()


def _week_end(week_start: date) -> date:
    if week_start.weekday() != 0:
        raise HTTPException(status_code=422, detail='week_start must be a Monday')
    return week_start + timedelta(days=6)


@router.get('/menu-plan', response_model=MenuPlanWeek)
async def get_menu_plan(week_start: date, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    return MenuPlanWeek(week_start=week_start, slots=await supabase_service.get_menu_plan_slots(current_user.id, tenant.chef_id, week_start, _week_end(week_start)))


@router.post('/menu-plan/slots', response_model=MenuPlanSlot, status_code=status.HTTP_201_CREATED)
async def add_menu_plan_slot(item: MenuPlanSlotInput, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    recipe = await supabase_service.get_menu_plan_recipe(item.recipe_id, tenant.chef_id, item.collection_id)
    if not recipe:
        raise HTTPException(status_code=404, detail='Recipe or collection item was not found for this tenant')
    return await supabase_service.create_menu_plan_slot(current_user.id, tenant.chef_id, item.model_dump(), recipe)


@router.put('/menu-plan/slots/{slot_id}', response_model=MenuPlanSlot)
async def update_menu_plan_slot(slot_id: str, item: MenuPlanSlotInput, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    recipe = await supabase_service.get_menu_plan_recipe(item.recipe_id, tenant.chef_id, item.collection_id)
    if not recipe:
        raise HTTPException(status_code=404, detail='Recipe or collection item was not found for this tenant')
    result = await supabase_service.update_menu_plan_slot(slot_id, current_user.id, tenant.chef_id, item.model_dump(), recipe)
    if not result:
        raise HTTPException(status_code=404, detail='Menu plan slot not found')
    return result


@router.delete('/menu-plan/slots/{slot_id}', status_code=status.HTTP_204_NO_CONTENT)
async def delete_menu_plan_slot(slot_id: str, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    await supabase_service.delete_menu_plan_slot(slot_id, current_user.id, tenant.chef_id)


@router.put('/menu-plan/reorder', response_model=MenuPlanWeek)
async def reorder_menu_plan(payload: MenuPlanReorder, week_start: date, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    try:
        await supabase_service.reorder_menu_plan_slots(payload.slot_ids, current_user.id, tenant.chef_id)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    return MenuPlanWeek(week_start=week_start, slots=await supabase_service.get_menu_plan_slots(current_user.id, tenant.chef_id, week_start, _week_end(week_start)))


@router.post('/menu-plan/shopping-list')
async def add_menu_plan_to_shopping_list(payload: MenuPlanShoppingRequest, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    items = await supabase_service.add_menu_plan_missing_ingredients(current_user.id, tenant.chef_id, payload.week_start, _week_end(payload.week_start))
    return {'items': items}


@router.post('/menu-plan/share')
async def share_menu_plan(payload: MenuPlanShare, current_user: User = Depends(verify_firebase_token), tenant: TenantContext = Depends(require_tenant_context)):
    slots = await supabase_service.get_menu_plan_slots(current_user.id, tenant.chef_id, payload.week_start, _week_end(payload.week_start))
    lines = [f'Меню на тиждень від {payload.week_start.isoformat()}:']
    for slot in slots:
        lines.append(f"{slot['planned_for']}: {slot['title']} — {slot['servings']} порц.")
    return {'text': '\n'.join(lines)}
