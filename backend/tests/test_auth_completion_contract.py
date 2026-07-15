import asyncio

from app.api.v1.endpoints import auth as auth_endpoint


def test_account_deletion_erases_public_user_before_auth_identity(monkeypatch):
    calls = []

    class FakeAdmin:
        def delete_user(self, user_id):
            calls.append(('auth', user_id))

    class FakeDatabase:
        service_client = type('Client', (), {'auth': type('Auth', (), {'admin': FakeAdmin()})()})()

        async def execute_query(self, table, operation, **kwargs):
            calls.append((table, operation, kwargs))

    monkeypatch.setattr(auth_endpoint, 'supabase_service', FakeDatabase())
    current_user = auth_endpoint.User(id='trusted-jwt-sub', email='trusted@example.com')

    assert asyncio.run(auth_endpoint.delete_current_user(current_user)) is None
    assert calls == [
        ('users', 'delete', {'filters': {'id': 'trusted-jwt-sub'}, 'use_service_key': True}),
        ('auth', 'trusted-jwt-sub'),
    ]
