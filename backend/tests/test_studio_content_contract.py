import asyncio
from pathlib import Path
from uuid import uuid4

from app.api.v1.endpoints.auth import User
from app.api.v1.endpoints.studio import create_collection, create_content, publish_content, save_merchandising
from app.core.tenant import TenantContext
from app.schemas.studio import StudioCollectionUpsert, StudioContentUpsert, StudioMerchandisingUpsert
from app.services.database import supabase_service


def _membership():
    return User(id=str(uuid4()), email='studio@example.test'), TenantContext(str(uuid4()), 'tenant-a'), 'admin'


def _content():
    return StudioContentUpsert(title='Техніка', description='Опис', contentKind='technique')


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

    monkeypatch.setattr(supabase_service, 'studio_publish_content', publish)
    assert asyncio.run(publish_content(row['id'], membership))['is_public'] is True


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
