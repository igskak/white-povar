import asyncio
from types import SimpleNamespace

from app.services.database import SupabaseService


def test_delete_applies_filters_after_starting_postgrest_delete(monkeypatch):
    calls = []

    class Query:
        def delete(self):
            calls.append('delete')
            return self

        def eq(self, key, value):
            calls.append((key, value))
            return self

        def execute(self):
            calls.append('execute')
            return SimpleNamespace(data=[])

    class Client:
        def table(self, table):
            calls.append(('table', table))
            return Query()

    service = object.__new__(SupabaseService)
    monkeypatch.setattr(service, 'get_client', lambda use_service_key: Client())

    asyncio.run(service.execute_query(
        'users', 'delete', filters={'id': 'user-1'}, use_service_key=True,
    ))

    assert calls == [('table', 'users'), 'delete', ('id', 'user-1'), 'execute']
