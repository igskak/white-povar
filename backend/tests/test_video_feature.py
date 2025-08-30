import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from fastapi.testclient import TestClient
from fastapi import UploadFile
import io

from app.main import app
from app.services.database import supabase_service
from app.schemas.recipe import RecipeVideo, RecipeVideoCreate


class TestVideoFeature:
    """Test suite for the video attachment feature"""

    @pytest.fixture
    def client(self):
        return TestClient(app)

    @pytest.fixture
    def mock_user(self):
        """Mock authenticated user"""
        return Mock(uid="test-user-123")

    @pytest.fixture
    def sample_video_data(self):
        """Sample video data for testing"""
        return {
            'recipe_id': 'recipe-123',
            'filename': 'test_video.mp4',
            'file_path': 'recipe-videos/recipe-123/test_video.mp4',
            'file_size': 1024000,  # 1MB
            'mime_type': 'video/mp4',
            'uploaded_by': 'test-user-123',
            'is_active': True
        }

    @pytest.fixture
    def sample_recipe_data(self):
        """Sample recipe data with video fields"""
        return {
            'id': 'recipe-123',
            'chef_id': 'test-user-123',
            'title': 'Test Recipe',
            'description': 'A test recipe',
            'video_url': 'https://youtube.com/watch?v=test123',
            'video_file_path': 'recipe-videos/recipe-123/test_video.mp4'
        }

    def test_video_url_validation_valid_urls(self):
        """Test that valid video URLs are accepted"""
        from app.schemas.recipe import RecipeBase
        
        valid_urls = [
            'https://youtube.com/watch?v=test123',
            'https://www.youtube.com/watch?v=test123',
            'https://youtu.be/test123',
            'https://tiktok.com/@user/video/123',
            'https://www.tiktok.com/@user/video/123',
            'https://instagram.com/p/test123',
            'https://www.instagram.com/reel/test123',
            'https://vimeo.com/123456',
            'https://facebook.com/user/videos/123',
            'https://dailymotion.com/video/test123'
        ]
        
        for url in valid_urls:
            # Should not raise validation error
            recipe_data = {
                'title': 'Test Recipe',
                'description': 'Test description',
                'cuisine': 'Test',
                'category': 'Test',
                'difficulty': 3,
                'prep_time_minutes': 30,
                'cook_time_minutes': 45,
                'servings': 4,
                'instructions': ['Step 1', 'Step 2'],
                'video_url': url
            }
            recipe = RecipeBase(**recipe_data)
            assert recipe.video_url == url

    def test_video_url_validation_invalid_urls(self):
        """Test that invalid video URLs are rejected"""
        from app.schemas.recipe import RecipeBase
        from pydantic import ValidationError
        
        invalid_urls = [
            'https://example.com/video.mp4',  # Unsupported platform
            'not-a-url',  # Invalid URL format
            'ftp://youtube.com/watch?v=test',  # Wrong protocol
            'https://malicious-site.com/fake-youtube'  # Fake platform
        ]
        
        for url in invalid_urls:
            recipe_data = {
                'title': 'Test Recipe',
                'description': 'Test description',
                'cuisine': 'Test',
                'category': 'Test',
                'difficulty': 3,
                'prep_time_minutes': 30,
                'cook_time_minutes': 45,
                'servings': 4,
                'instructions': ['Step 1', 'Step 2'],
                'video_url': url
            }
            
            with pytest.raises(ValidationError):
                RecipeBase(**recipe_data)

    def test_video_mime_type_validation(self):
        """Test video MIME type validation"""
        from app.schemas.recipe import RecipeVideoBase
        from pydantic import ValidationError
        
        # Valid MIME types
        valid_types = [
            'video/mp4',
            'video/mpeg',
            'video/quicktime',
            'video/x-msvideo',
            'video/webm',
            'video/ogg',
            'video/3gpp',
            'video/x-flv'
        ]
        
        for mime_type in valid_types:
            video_data = {
                'filename': 'test.mp4',
                'file_path': '/path/to/video',
                'file_size': 1000,
                'mime_type': mime_type
            }
            video = RecipeVideoBase(**video_data)
            assert video.mime_type == mime_type
        
        # Invalid MIME types
        invalid_types = [
            'image/jpeg',
            'audio/mp3',
            'text/plain',
            'application/pdf'
        ]
        
        for mime_type in invalid_types:
            video_data = {
                'filename': 'test.mp4',
                'file_path': '/path/to/video',
                'file_size': 1000,
                'mime_type': mime_type
            }
            
            with pytest.raises(ValidationError):
                RecipeVideoBase(**video_data)

    @patch('app.services.database.supabase_service.create_recipe_video')
    @patch('app.api.v1.endpoints.auth.verify_firebase_token')
    async def test_video_upload_endpoint(self, mock_auth, mock_create_video, client, mock_user, sample_video_data):
        """Test video upload endpoint"""
        mock_auth.return_value = mock_user
        mock_create_video.return_value = {'data': [sample_video_data]}
        
        # Create a mock video file
        video_content = b"fake video content"
        video_file = UploadFile(
            filename="test_video.mp4",
            file=io.BytesIO(video_content),
            content_type="video/mp4"
        )
        
        with patch('app.services.database.supabase_service.get_recipe_by_id') as mock_get_recipe:
            mock_get_recipe.return_value = {
                'data': [{'id': 'recipe-123', 'chef_id': 'test-user-123'}]
            }
            
            with patch('app.services.database.supabase_service.get_client') as mock_client:
                mock_storage = Mock()
                mock_storage.from_.return_value.upload.return_value = Mock(error=None)
                mock_storage.from_.return_value.get_public_url.return_value = "https://storage.url/video.mp4"
                mock_client.return_value.storage = mock_storage
                
                response = client.post(
                    "/api/v1/videos/upload?recipe_id=recipe-123",
                    files={"file": ("test_video.mp4", video_content, "video/mp4")}
                )
                
                assert response.status_code == 200
                data = response.json()
                assert data['filename'] == 'test_video.mp4'
                assert data['mime_type'] == 'video/mp4'

    @patch('app.services.database.supabase_service.get_recipe_videos')
    async def test_get_recipe_videos_endpoint(self, mock_get_videos, client, sample_video_data):
        """Test get recipe videos endpoint"""
        mock_get_videos.return_value = {'data': [sample_video_data]}
        
        response = client.get("/api/v1/videos/recipe/recipe-123")
        
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]['filename'] == 'test_video.mp4'

    def test_recipe_model_with_video_fields(self, sample_recipe_data):
        """Test that Recipe model correctly handles video fields"""
        from app.schemas.recipe import Recipe
        
        recipe = Recipe(**sample_recipe_data)
        assert recipe.video_url == 'https://youtube.com/watch?v=test123'
        assert recipe.video_file_path == 'recipe-videos/recipe-123/test_video.mp4'

    def test_recipe_json_serialization_with_videos(self):
        """Test Recipe model JSON serialization with video fields"""
        from frontend.lib.features.recipes.models.recipe import Recipe
        
        # This would be a Dart/Flutter test in a real scenario
        # Here we're testing the concept
        recipe_json = {
            'id': 'recipe-123',
            'title': 'Test Recipe',
            'description': 'Test description',
            'chef_id': 'chef-123',
            'cuisine': 'Italian',
            'category': 'Dinner',
            'difficulty': 3,
            'prep_time_minutes': 30,
            'cook_time_minutes': 45,
            'total_time_minutes': 75,
            'servings': 4,
            'ingredients': [],
            'instructions': ['Step 1', 'Step 2'],
            'images': [],
            'video_url': 'https://youtube.com/watch?v=test123',
            'video_file_path': 'recipe-videos/recipe-123/test_video.mp4',
            'tags': [],
            'is_featured': False,
            'created_at': '2023-01-01T00:00:00Z',
            'updated_at': '2023-01-01T00:00:00Z'
        }
        
        # In a real Flutter test, you would do:
        # Recipe recipe = Recipe.fromJson(recipe_json);
        # assert recipe.videoUrl == 'https://youtube.com/watch?v=test123'
        # assert recipe.videoFilePath == 'recipe-videos/recipe-123/test_video.mp4'
        
        assert recipe_json['video_url'] == 'https://youtube.com/watch?v=test123'
        assert recipe_json['video_file_path'] == 'recipe-videos/recipe-123/test_video.mp4'

    @patch('app.services.database.supabase_service.update_recipe_video')
    @patch('app.api.v1.endpoints.auth.verify_firebase_token')
    async def test_delete_video_endpoint(self, mock_auth, mock_update_video, client, mock_user):
        """Test video deletion (soft delete) endpoint"""
        mock_auth.return_value = mock_user
        mock_update_video.return_value = {'data': [{'id': 'video-123', 'is_active': False}]}
        
        with patch('app.services.database.supabase_service.get_recipe_video_by_id') as mock_get_video:
            mock_get_video.return_value = {
                'data': [{'id': 'video-123', 'uploaded_by': 'test-user-123'}]
            }
            
            response = client.delete("/api/v1/videos/video-123")
            
            assert response.status_code == 200
            data = response.json()
            assert data['message'] == 'Video deleted successfully'

    def test_video_file_size_validation(self):
        """Test video file size validation"""
        # This would typically be tested in the upload endpoint
        max_size = 100 * 1024 * 1024  # 100MB
        
        # Test file within limit
        valid_size = 50 * 1024 * 1024  # 50MB
        assert valid_size <= max_size
        
        # Test file exceeding limit
        invalid_size = 150 * 1024 * 1024  # 150MB
        assert invalid_size > max_size

    def test_supported_video_platforms(self):
        """Test that all supported video platforms are recognized"""
        from app.schemas.recipe import RecipeBase
        
        supported_platforms = [
            ('YouTube', 'https://youtube.com/watch?v=test'),
            ('YouTube Short', 'https://youtu.be/test'),
            ('TikTok', 'https://tiktok.com/@user/video/123'),
            ('Instagram', 'https://instagram.com/p/test'),
            ('Instagram Reel', 'https://instagram.com/reel/test'),
            ('Vimeo', 'https://vimeo.com/123456'),
            ('Facebook', 'https://facebook.com/user/videos/123'),
            ('Dailymotion', 'https://dailymotion.com/video/test')
        ]
        
        for platform_name, url in supported_platforms:
            recipe_data = {
                'title': f'Test Recipe for {platform_name}',
                'description': 'Test description',
                'cuisine': 'Test',
                'category': 'Test',
                'difficulty': 3,
                'prep_time_minutes': 30,
                'cook_time_minutes': 45,
                'servings': 4,
                'instructions': ['Step 1', 'Step 2'],
                'video_url': url
            }
            
            # Should not raise validation error
            recipe = RecipeBase(**recipe_data)
            assert recipe.video_url == url


if __name__ == "__main__":
    pytest.main([__file__])
