import asyncio
from uuid import uuid4

import pytest
from fastapi import HTTPException
from starlette.requests import Request
from starlette.responses import Response

from app.api.v1.endpoints import config
from app.schemas.bootstrap import TenantBootstrap
from app.services.database import SupabaseService


def _request(headers=None):
    return Request({
        'type': 'http',
        'method': 'GET',
        'path': '/api/v1/bootstrap/ohorodnik-oleksandr',
        'headers': [
            (key.lower().encode(), value.encode()) for key, value in (headers or {}).items()
        ],
    })


def _bootstrap():
    return {
        'state': 'ok',
        'tenant': {'id': str(uuid4()), 'slug': 'ohorodnik-oleksandr'},
        'brand_config': {'name': 'Огороднік Олександр'},
        'product_config': {'locale': 'uk', 'features': {}},
        'config_version': 'brand-2-product-3',
    }


def test_bootstrap_returns_published_configs_and_etag(monkeypatch):
    async def fake_bootstrap(slug):
        assert slug == 'ohorodnik-oleksandr'
        return _bootstrap()

    monkeypatch.setattr(config.supabase_service, 'get_tenant_bootstrap', fake_bootstrap)
    response = Response()
    result = asyncio.run(config.get_tenant_bootstrap('ohorodnik-oleksandr', _request(), response))

    assert result['tenant']['slug'] == 'ohorodnik-oleksandr'
    assert result['brand_config']['name'] == 'Огороднік Олександр'
    assert result['product_config']['locale'] == 'uk'
    assert result['config_version'] == 'brand-2-product-3'
    assert response.headers['etag'] == '"brand-2-product-3"'
    assert TenantBootstrap.model_validate(result).model_dump(by_alias=True)['configVersion'] == (
        'brand-2-product-3'
    )


def test_bootstrap_honors_matching_if_none_match(monkeypatch):
    monkeypatch.setattr(config.supabase_service, 'get_tenant_bootstrap', lambda _: _async(_bootstrap()))

    response = Response()
    result = asyncio.run(config.get_tenant_bootstrap(
        'ohorodnik-oleksandr', _request({'if-none-match': '"brand-2-product-3"'}), response
    ))

    assert result.status_code == 304
    assert result.headers['etag'] == '"brand-2-product-3"'


@pytest.mark.parametrize('state', ['tenant_not_found'])
def test_bootstrap_hides_unknown_and_inactive_tenants(monkeypatch, state):
    monkeypatch.setattr(config.supabase_service, 'get_tenant_bootstrap', lambda _: _async({'state': state}))

    with pytest.raises(HTTPException) as error:
        asyncio.run(config.get_tenant_bootstrap('unknown', _request(), Response()))

    assert error.value.status_code == 404
    assert error.value.detail == 'Tenant not found'


@pytest.mark.parametrize('state', ['config_not_published', 'config_malformed'])
def test_bootstrap_handles_missing_or_malformed_published_config(monkeypatch, state):
    monkeypatch.setattr(config.supabase_service, 'get_tenant_bootstrap', lambda _: _async({'state': state}))

    with pytest.raises(HTTPException) as error:
        asyncio.run(config.get_tenant_bootstrap('ohorodnik-oleksandr', _request(), Response()))

    assert error.value.status_code == 409


async def _async(value):
    return value


class _Result:
    def __init__(self, data):
        self.data = data


class _Query:
    def __init__(self, data):
        self.data = data

    def select(self, *_args):
        return self

    def eq(self, *_args):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, *_args):
        return self

    def execute(self):
        return _Result(self.data)


class _BootstrapClient:
    def __init__(self, chefs, brand=None, product=None):
        self.rows = {
            'chefs': chefs,
            'brand_configs': brand or [],
            'product_configs': product or [],
        }

    def table(self, name):
        return _Query(self.rows[name])


def test_database_bootstrap_treats_inactive_tenant_as_not_found(monkeypatch):
    service = SupabaseService.__new__(SupabaseService)
    monkeypatch.setattr(
        service,
        'get_client',
        lambda **_kwargs: _BootstrapClient([]),
    )

    assert asyncio.run(service.get_tenant_bootstrap('inactive-tenant')) == {
        'state': 'tenant_not_found'
    }


def test_database_bootstrap_rejects_non_object_config(monkeypatch):
    chef_id = str(uuid4())
    service = SupabaseService.__new__(SupabaseService)
    monkeypatch.setattr(
        service,
        'get_client',
        lambda **_kwargs: _BootstrapClient(
            [{'id': chef_id, 'slug': 'ohorodnik-oleksandr', 'is_active': True}],
            [{'version': 1, 'config': []}],
            [{'version': 1, 'config': {'locale': 'uk'}}],
        ),
    )

    assert asyncio.run(service.get_tenant_bootstrap('ohorodnik-oleksandr')) == {
        'state': 'config_malformed'
    }


def test_database_bootstrap_rejects_invalid_published_brand_config(monkeypatch):
    chef_id = str(uuid4())
    service = SupabaseService.__new__(SupabaseService)
    monkeypatch.setattr(
        service,
        'get_client',
        lambda **_kwargs: _BootstrapClient(
            [{'id': chef_id, 'slug': 'ohorodnik-oleksandr', 'is_active': True}],
            [{'version': 1, 'config': {'schemaVersion': 1, 'tenantSlug': 'ohorodnik-oleksandr'}}],
            [{'version': 1, 'config': {'locale': 'uk'}}],
        ),
    )

    assert asyncio.run(service.get_tenant_bootstrap('ohorodnik-oleksandr')) == {
        'state': 'config_malformed'
    }
