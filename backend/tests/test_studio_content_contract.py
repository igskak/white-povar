import asyncio
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints.auth import User
from app.api.v1.endpoints.studio import (
    create_collection,
    create_content,
    publish_content,
    save_merchandising,
)
from app.core.tenant import TenantContext
from app.schemas.studio import StudioCollectionUpsert, StudioContentUpsert, StudioMerchandisingUpsert
from app.services.database import supabase_service


def _membership():
    return User(id=str(uuid4()), email='studio@example.test'), TenantContext(str(uuid4()), 'tenant-a'), 'admin'


def _content():
    return StudioContentUpsert(title='Техніка', description='Опис', contentKind='technique')


def test_recipe_draft_can_be_saved_before_ingredients_and_steps_are_complete():
    draft = StudioContentUpsert(
        title='Чернетка борщу',
        description='Робочий опис',
        contentKind='recipe',
    )
    assert draft.ingredients == []
    assert draft.instructions == []


def test_studio_content_is_created_unpublished_and_only_publish_changes_visibility(monkeypatch):
    membership = _membership()
    row = {'id': str(uuid4()), 'chef_id': membership[1].chef_id, 'title': 'Техніка', 'is_public': False}

    async def save(**kwargs):
        assert kwargs['chef_id'] == membership[1].chef_id
        assert kwargs['content_id'] is None
        return row

    monkeypatch.setattr(supabase_service, 'studio_save_content', save)
    result = asyncio.run(create_content(_content(), membership))
    assert result['is_public'] is False

    async def publish(**kwargs):
        assert kwargs['content_id'] == row['id']
        return {**row, 'is_public': True}

    async def content_row(*_):
        return {**row, 'content_kind': 'technique'}

    monkeypatch.setattr(supabase_service, 'studio_content_row', content_row)
    monkeypatch.setattr(supabase_service, 'studio_publish_content', publish)
    assert asyncio.run(publish_content(row['id'], membership))['is_public'] is True


def test_recipe_asset_is_resolved_inside_the_current_tenant(monkeypatch):
    membership = _membership()
    asset_id = str(uuid4())
    recipe_id = str(uuid4())

    async def asset(requested_id, chef_id):
        assert requested_id == asset_id
        assert chef_id == membership[1].chef_id
        return {
            'id': asset_id,
            'state': 'ready',
            'asset_kind': 'recipe',
            'url': 'https://storage.test/recipes/dish.webp',
            'alt_text': 'Борщ у тарілці',
            'width': 1600,
            'height': 1200,
        }

    async def save(**kwargs):
        presentation = kwargs['values']['image_presentation']
        assert kwargs['values']['image_url'].endswith('/dish.webp')
        assert presentation['primary']['focal'] == {'x': 0.8, 'y': 0.4}
        assert presentation['featured']['focal'] == {'x': 0.15, 'y': 0.6}
        assert presentation['featured']['url'] == presentation['primary']['url']
        assert kwargs['values']['ingredients'][0]['name'] == 'Буряк'
        return {
            'id': recipe_id,
            'chef_id': membership[1].chef_id,
            'title': 'Борщ',
            'is_public': False,
            'image_url': kwargs['values']['image_url'],
            'image_presentation': presentation,
        }

    monkeypatch.setattr(supabase_service, 'get_studio_asset', asset)
    monkeypatch.setattr(supabase_service, 'studio_save_content', save)
    payload = StudioContentUpsert(
        title='Борщ',
        description='Домашній борщ',
        contentKind='recipe',
        ingredients=[{'name': 'Буряк', 'amount': 1, 'unit': 'шт.'}],
        instructions=['Зваріть овочі'],
        imagePresentation={
            'primary': {
                'assetId': asset_id,
                'altText': 'Борщ із зеленню',
                'focal': {'x': 0.8, 'y': 0.4},
            },
            'featured': {
                'usePrimary': True,
                'focal': {'x': 0.15, 'y': 0.6},
            },
        },
    )
    result = asyncio.run(create_content(payload, membership))
    assert result['image_presentation']['primary']['alt_text'] == 'Борщ із зеленню'


@pytest.mark.parametrize(
    ('state', 'asset_kind'),
    [('uploading', 'recipe'), ('ready', 'brand')],
)
def test_recipe_rejects_unready_and_non_recipe_assets(
    monkeypatch, state, asset_kind
):
    membership = _membership()
    asset_id = str(uuid4())

    async def asset(*_):
        return {
            'id': asset_id,
            'state': state,
            'asset_kind': asset_kind,
            'url': 'https://storage.test/asset.webp',
        }

    monkeypatch.setattr(supabase_service, 'get_studio_asset', asset)
    payload = StudioContentUpsert(
        title='Чернетка',
        description='Опис',
        contentKind='recipe',
        imagePresentation={'primary': {'assetId': asset_id}},
    )

    with pytest.raises(HTTPException) as error:
        asyncio.run(create_content(payload, membership))
    assert error.value.status_code == 422


def test_collection_and_merchandising_are_tenant_bound(monkeypatch):
    membership = _membership()
    content_id = str(uuid4())
    payload = StudioCollectionUpsert(slug='maisternia', titleI18n={'uk': 'Майстерня'}, items=[{'recipeId': content_id, 'isPreview': True}])

    async def save_collection(**kwargs):
        assert kwargs['chef_id'] == membership[1].chef_id
        assert kwargs['values']['items'][0]['recipe_id'] == content_id
        return {'id': str(uuid4()), 'chef_id': membership[1].chef_id}

    monkeypatch.setattr(supabase_service, 'studio_save_collection', save_collection)
    assert asyncio.run(create_collection(payload, membership))['chef_id'] == membership[1].chef_id

    async def save_merch(**kwargs):
        assert kwargs['chef_id'] == membership[1].chef_id
        assert kwargs['values']['collection_id'] == content_id
        return {'status': 'draft'}

    monkeypatch.setattr(supabase_service, 'studio_save_merchandising', save_merch)
    merch = StudioMerchandisingUpsert(productKey='course', kind='one_off', offerKey='course-offer', collectionId=content_id)
    assert asyncio.run(save_merchandising(merch, membership))['status'] == 'draft'


def test_studio_content_migration_has_atomic_publish_schedule_audit_and_tenant_guards():
    source = Path(__file__).resolve().parents[1] / 'migrations/2026_07_16_studio_content_merchandising.sql'
    sql = source.read_text(encoding='utf-8')
    assert 'studio_content_audit' in sql
    assert 'studio_scheduled_publications' in sql
    assert 'studio_publish_content' in sql and 'is_public=true' in sql
    assert 'Collection material must belong to tenant' in sql
    assert 'Collection must belong to tenant' in sql
    assert 'studio_save_merchandising' in sql

    image_source = (
        Path(__file__).resolve().parents[1]
        / 'migrations/2026_07_26_recipe_image_presentation.sql'
    )
    image_sql = image_source.read_text(encoding='utf-8')
    assert 'image_presentation' in image_sql
    assert 'studio-content-assets' in image_sql
    assert 'DELETE FROM recipe_ingredients' in image_sql
    assert 'Recipe is incomplete and cannot be published' in image_sql
