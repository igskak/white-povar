from app.core.settings import settings
import asyncio

import pytest
from fastapi.testclient import TestClient

from app.main import app, readiness_check


def test_production_readiness_requirements_never_expose_values(monkeypatch):
    monkeypatch.setattr(settings, "environment", "production")
    monkeypatch.setattr(settings, "secret_key", "")
    missing = settings.missing_required_production_settings()

    assert "SECRET_KEY" in missing
    assert "" not in missing
    assert all("secret" not in item.lower() or item == "SECRET_KEY" for item in missing)

    with pytest.raises(Exception) as error:
        asyncio.run(readiness_check())
    assert getattr(error.value, "status_code", None) == 503
    assert error.value.detail == {"status": "not_ready", "missing": ["SECRET_KEY"]}


def test_production_requires_the_configured_web_origin(monkeypatch):
    monkeypatch.setattr(settings, "environment", "production")
    monkeypatch.setattr(settings, "web_app_url", "https://pilot.example")
    monkeypatch.setattr(settings, "allowed_origins", "https://other.example")

    assert "ALLOWED_ORIGINS" in settings.missing_required_production_settings()


def test_development_does_not_block_startup_for_production_only_contract(monkeypatch):
    monkeypatch.setattr(settings, "environment", "development")
    monkeypatch.setattr(settings, "secret_key", "")

    settings.validate_startup_configuration()


def test_render_web_origin_passes_cors_preflight():
    response = TestClient(app).options(
        "/api/v1/recipes",
        headers={
            "Origin": "https://white-povar-p79r.onrender.com",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == (
        "https://white-povar-p79r.onrender.com"
    )
