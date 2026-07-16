import asyncio

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints import auth as auth_endpoint


def test_account_deletion_logs_no_provider_exception_text(monkeypatch, caplog):
    class FailingDatabase:
        async def execute_query(self, *_args, **_kwargs):
            raise RuntimeError('provider response included cook@example.com')

    monkeypatch.setattr(auth_endpoint, 'supabase_service', FailingDatabase())
    user = auth_endpoint.User(id='user-a', email='cook@example.com')

    with pytest.raises(HTTPException) as error:
        asyncio.run(auth_endpoint.delete_current_user(user))

    assert error.value.status_code == 502
    assert 'provider response included cook@example.com' not in caplog.text
    assert 'cook@example.com' not in caplog.text
