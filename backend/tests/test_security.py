import asyncio
from datetime import datetime, timezone

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from jose import jwk, jwt

from app.core.security import SupabaseAuth
from app.api.v1.endpoints import auth as auth_endpoint


def _claims(auth: SupabaseAuth, **overrides):
    now = int(datetime.now(timezone.utc).timestamp())
    claims = {
        "sub": "35e6f7a4-e495-4db2-a90d-78f90a16cf1e",
        "email": "cook@example.com",
        "role": "authenticated",
        "aud": "authenticated",
        "iss": auth.issuer,
        "iat": now - 10,
        "exp": now + 3600,
    }
    claims.update(overrides)
    return claims


def test_legacy_token_requires_auth_server_validation(monkeypatch):
    auth = SupabaseAuth()
    claims = _claims(auth)
    token = jwt.encode(claims, "test-secret", algorithm="HS256")
    calls = []

    async def verified_by_auth_server(received_token):
        calls.append(received_token)
        return claims

    monkeypatch.setattr(auth, "_verify_legacy_token", verified_by_auth_server)

    assert asyncio.run(auth.verify_token(token))["sub"] == claims["sub"]
    assert calls == [token]


@pytest.mark.parametrize(
    "claim_overrides",
    [
        {"role": "anon"},
        {"aud": "service_role"},
        {"iss": "https://attacker.invalid/auth/v1"},
        {"sub": ""},
        {"exp": 1},
    ],
)
def test_access_token_claims_fail_closed(monkeypatch, claim_overrides):
    auth = SupabaseAuth()
    claims = _claims(auth, **claim_overrides)
    token = jwt.encode(claims, "test-secret", algorithm="HS256")

    async def verified_by_auth_server(_):
        return claims

    monkeypatch.setattr(auth, "_verify_legacy_token", verified_by_auth_server)

    with pytest.raises(ValueError):
        asyncio.run(auth.verify_token(token))


def test_unsupported_signing_algorithm_is_rejected():
    auth = SupabaseAuth()
    token = jwt.encode(_claims(auth), "test-secret", algorithm="HS512")

    with pytest.raises(ValueError, match="Unsupported token signing algorithm"):
        asyncio.run(auth.verify_token(token))


def test_asymmetric_token_uses_matching_jwks_key(monkeypatch):
    auth = SupabaseAuth()
    claims = _claims(auth)
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_pem = private_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    public_pem = private_key.public_key().public_bytes(
        serialization.Encoding.PEM,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    public_jwk = jwk.construct(public_pem, algorithm="RS256").to_dict()
    public_jwk["kid"] = "rotation-key-1"
    token = jwt.encode(
        claims,
        private_pem,
        algorithm="RS256",
        headers={"kid": "rotation-key-1"},
    )
    requested_keys = []

    async def signing_key(key_id, *, force_refresh=False):
        requested_keys.append((key_id, force_refresh))
        return public_jwk

    monkeypatch.setattr(auth, "_get_signing_key", signing_key)

    assert asyncio.run(auth.verify_token(token))["sub"] == claims["sub"]
    assert requested_keys == [("rotation-key-1", False)]


def test_user_sync_ignores_untrusted_identity_fields(monkeypatch):
    calls = []

    class Result:
        data = []

    class FakeDatabase:
        async def execute_query(self, table, operation, **kwargs):
            calls.append((table, operation, kwargs))
            return Result()

    monkeypatch.setattr(auth_endpoint, "supabase_service", FakeDatabase())
    request = auth_endpoint.UserSyncRequest(
        id="attacker-selected-id",
        email="attacker-selected@example.com",
        display_name="Home cook",
    )
    current_user = auth_endpoint.User(
        id="trusted-jwt-sub",
        email="trusted@example.com",
    )

    result = asyncio.run(auth_endpoint.sync_user(request, current_user))

    assert result == {"message": "User synced successfully"}
    assert calls[0][2]["filters"] == {"id": "trusted-jwt-sub"}
    inserted = calls[1][2]["data"]
    assert inserted["id"] == "trusted-jwt-sub"
    assert inserted["email"] == "trusted@example.com"
    assert inserted["display_name"] == "Home cook"


def test_chef_membership_is_read_from_trusted_user_record():
    class Result:
        data = [{"chef_id": "7fc59573-8297-4287-a3d8-5ac4a61cc507"}]

    assert (
        auth_endpoint._chef_id_from_user_result(Result())
        == "7fc59573-8297-4287-a3d8-5ac4a61cc507"
    )
