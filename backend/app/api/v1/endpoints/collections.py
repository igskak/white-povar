"""Tenant-scoped consumer collection discovery and detail API."""
from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from app.api.v1.endpoints.auth import User, get_optional_user
from app.api.v1.endpoints.recipes import _content_item_from_row, _premium_teaser
from app.core.collection_access import resolve_collection_access
from app.core.content_access import resolve_recipe_access
from app.core.tenant import TenantContext, require_tenant_context
from app.middleware.localization import get_localization_context
from app.schemas.collection import CollectionDetail, CollectionItem, CollectionList, CollectionSummary
from app.services.database import supabase_service

router = APIRouter()


def _result_data(result: Any) -> list[dict[str, Any]]:
    if isinstance(result, dict):
        return result.get('data') or []
    return getattr(result, 'data', None) or []


def _localized_text(value: Any, locale: str) -> str:
    """Choose the requested localized field, with the tenant's Ukrainian fallback."""
    if isinstance(value, str):
        return value
    if not isinstance(value, dict):
        return ''
    return str(value.get(locale) or value.get('uk') or next(iter(value.values()), ''))


def _summary_from_row(row: dict[str, Any], *, locale: str, is_locked: bool) -> CollectionSummary:
    raw_items = row.get('collection_items') or []
    count = row.get('item_count')
    if count is None and raw_items and isinstance(raw_items[0], dict) and 'count' in raw_items[0]:
        count = raw_items[0]['count']
    if count is None:
        count = len(raw_items)
    return CollectionSummary(
        id=row['id'], chef_id=row['chef_id'], slug=row['slug'],
        title=_localized_text(row.get('title_i18n'), locale),
        description=_localized_text(row.get('description_i18n'), locale),
        cover_url=row.get('cover_url'), is_premium=row.get('is_premium', False),
        is_locked=is_locked, item_count=int(count),
        published_at=row.get('published_at'),
    )


@router.get('/', response_model=CollectionList)
async def get_collections(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: Optional[User] = Depends(get_optional_user),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """List published collections for only the resolved tenant."""
    result = await supabase_service.get_published_collections(tenant.chef_id, limit, offset)
    rows = _result_data(result)
    locale = get_localization_context(request).primary_language
    collections = []
    for row in rows:
        access = await resolve_collection_access(row, tenant, current_user)
        if access.exists_in_tenant:
            collections.append(_summary_from_row(row, locale=locale, is_locked=not access.can_read_items))
    total_count = getattr(result, 'count', None)
    return CollectionList(
        collections=collections,
        total_count=int(total_count) if total_count is not None else len(collections),
        has_more=(offset + len(rows)) < total_count if total_count is not None else len(rows) == limit,
    )


@router.get('/{collection_id}', response_model=CollectionDetail)
async def get_collection(
    collection_id: str,
    request: Request,
    current_user: Optional[User] = Depends(get_optional_user),
    tenant: TenantContext = Depends(require_tenant_context),
):
    """Return ordered items; locked collections expose only item teasers."""
    try:
        UUID(collection_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Invalid collection ID format')
    result = await supabase_service.get_published_collection_by_id(collection_id, tenant.chef_id)
    rows = _result_data(result)
    if not rows:
        # Unpublished and cross-tenant IDs intentionally look like missing IDs.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Collection not found')

    row = rows[0]
    access = await resolve_collection_access(row, tenant, current_user)
    if not access.exists_in_tenant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Collection not found')

    locale = get_localization_context(request).primary_language
    summary = _summary_from_row(row, locale=locale, is_locked=not access.can_read_items)
    items = []
    for item in sorted(row.get('collection_items') or [], key=lambda value: (value.get('position', 0), str(value.get('id')))):
        content = item.get('content')
        if not content:
            continue
        if not access.can_read_items and not item.get('is_preview', False):
            projected = _premium_teaser(content)
        else:
            content_access = await resolve_recipe_access(content, tenant, current_user)
            if not content_access.exists_in_tenant:
                continue
            projected = _content_item_from_row(content) if content_access.can_read_body else _premium_teaser(content)
        items.append(CollectionItem(
            id=item['id'], position=item['position'], is_preview=item.get('is_preview', False), content=projected,
        ))
    return CollectionDetail(**summary.model_dump(), items=items)
