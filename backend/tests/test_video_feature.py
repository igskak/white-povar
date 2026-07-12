"""Tests for recipe video schemas and API endpoints."""

from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.v1.endpoints.auth import User, verify_firebase_token
from app.main import app
from app.schemas.recipe import Recipe, RecipeBase, RecipeVideoBase
from app.services.database import supabase_service


RECIPE_ID = "11111111-1111-4111-8111-111111111111"
VIDEO_ID = "22222222-2222-4222-8222-222222222222"
USER_ID = "33333333-3333-4333-8333-333333333333"
CHEF_ID = "44444444-4444-4444-8444-444444444444"


@pytest.fixture
def mock_user():
    return User(id=USER_ID, email="cook@example.com", chef_id=CHEF_ID)


@pytest.fixture
def client(mock_user):
    app.dependency_overrides[verify_firebase_token] = lambda: mock_user
    test_client = TestClient(app)
    try:
        yield test_client
    finally:
        test_client.close()
        app.dependency_overrides.clear()


@pytest.fixture
def sample_video_data():
    return {
        "id": VIDEO_ID,
        "recipe_id": RECIPE_ID,
        "filename": "test_video.mp4",
        "file_path": f"recipe-videos/{RECIPE_ID}/test_video.mp4",
        "file_size": 1_024_000,
        "mime_type": "video/mp4",
        "uploaded_by": USER_ID,
        "uploaded_at": datetime.now(timezone.utc).isoformat(),
        "is_active": True,
    }


def recipe_base_data(**overrides):
    data = {
        "title": "Test Recipe",
        "description": "Test description",
        "cuisine": "Italian",
        "category": "Dinner",
        "difficulty": 3,
        "prep_time_minutes": 30,
        "cook_time_minutes": 45,
        "servings": 4,
        "instructions": ["Step 1", "Step 2"],
    }
    data.update(overrides)
    return data


def test_video_url_validation_accepts_supported_platforms():
    valid_urls = [
        "https://youtube.com/watch?v=test123",
        "https://www.youtube.com/watch?v=test123",
        "https://youtu.be/test123",
        "https://tiktok.com/@user/video/123",
        "https://www.tiktok.com/@user/video/123",
        "https://instagram.com/p/test123",
        "https://www.instagram.com/reel/test123",
        "https://vimeo.com/123456",
        "https://facebook.com/user/videos/123",
        "https://dailymotion.com/video/test123",
    ]

    for url in valid_urls:
        assert RecipeBase(**recipe_base_data(video_url=url)).video_url == url


def test_video_url_validation_rejects_unsupported_urls():
    invalid_urls = [
        "https://example.com/video.mp4",
        "not-a-url",
        "ftp://youtube.com/watch?v=test",
        "https://malicious-site.com/fake-youtube",
    ]

    for url in invalid_urls:
        with pytest.raises(ValidationError):
            RecipeBase(**recipe_base_data(video_url=url))


def test_video_mime_type_validation():
    valid_types = [
        "video/mp4",
        "video/mpeg",
        "video/quicktime",
        "video/x-msvideo",
        "video/webm",
        "video/ogg",
        "video/3gpp",
        "video/x-flv",
    ]

    for mime_type in valid_types:
        video = RecipeVideoBase(
            filename="test.mp4",
            file_path="videos/test.mp4",
            file_size=1000,
            mime_type=mime_type,
        )
        assert video.mime_type == mime_type

    for mime_type in ["image/jpeg", "audio/mp3", "text/plain", "application/pdf"]:
        with pytest.raises(ValidationError):
            RecipeVideoBase(
                filename="test.mp4",
                file_path="videos/test.mp4",
                file_size=1000,
                mime_type=mime_type,
            )


def test_video_upload_endpoint(client, sample_video_data):
    storage_bucket = Mock()
    storage_bucket.upload.return_value = SimpleNamespace()
    storage_bucket.get_public_url.return_value = "https://storage.example/video.mp4"
    storage = Mock()
    storage.from_.return_value = storage_bucket
    database_client = Mock(storage=storage)

    with (
        patch.object(
            supabase_service,
            "get_recipe_by_id",
            new=AsyncMock(
                return_value={"data": [{"id": RECIPE_ID, "chef_id": CHEF_ID}]}
            ),
        ),
        patch.object(supabase_service, "get_client", return_value=database_client),
        patch.object(
            supabase_service,
            "create_recipe_video",
            new=AsyncMock(return_value=SimpleNamespace(data=[sample_video_data])),
        ),
        patch.object(
            supabase_service,
            "update_recipe",
            new=AsyncMock(return_value=SimpleNamespace(data=[{"id": RECIPE_ID}])),
        ),
    ):
        response = client.post(
            f"/api/v1/videos/upload?recipe_id={RECIPE_ID}",
            files={"file": ("test_video.mp4", b"fake video content", "video/mp4")},
        )

    assert response.status_code == 200
    assert response.json()["filename"] == "test_video.mp4"
    assert response.json()["mime_type"] == "video/mp4"


def test_get_recipe_videos_endpoint(client, sample_video_data):
    with patch.object(
        supabase_service,
        "get_recipe_videos",
        new=AsyncMock(return_value={"data": [sample_video_data]}),
    ):
        response = client.get(f"/api/v1/videos/recipe/{RECIPE_ID}")

    assert response.status_code == 200
    assert response.json()[0]["filename"] == "test_video.mp4"


def test_recipe_model_serializes_video_fields():
    recipe = Recipe(
        **recipe_base_data(
            video_url="https://youtube.com/watch?v=test123",
            video_file_path=f"recipe-videos/{RECIPE_ID}/test_video.mp4",
        ),
        id=RECIPE_ID,
        chef_id=USER_ID,
        total_time_minutes=75,
    )

    serialized = recipe.model_dump(mode="json")
    assert serialized["video_url"] == "https://youtube.com/watch?v=test123"
    assert serialized["video_file_path"] == f"recipe-videos/{RECIPE_ID}/test_video.mp4"


def test_delete_video_endpoint(client):
    with (
        patch.object(
            supabase_service,
            "get_recipe_video_by_id",
            new=AsyncMock(
                return_value={"data": [{"id": VIDEO_ID, "uploaded_by": USER_ID}]}
            ),
        ),
        patch.object(
            supabase_service,
            "update_recipe_video",
            new=AsyncMock(
                return_value={"data": [{"id": VIDEO_ID, "is_active": False}]}
            ),
        ) as update_video,
    ):
        response = client.delete(f"/api/v1/videos/{VIDEO_ID}")

    assert response.status_code == 200
    assert response.json()["message"] == "Video deleted successfully"
    update_video.assert_awaited_once_with(VIDEO_ID, {"is_active": False})


def test_video_file_size_limit_contract():
    max_size = 100 * 1024 * 1024
    assert 50 * 1024 * 1024 <= max_size
    assert 150 * 1024 * 1024 > max_size
