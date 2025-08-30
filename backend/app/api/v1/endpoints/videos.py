from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, status
from typing import Optional, List
from uuid import UUID
import logging
import os
import tempfile
from pathlib import Path

from app.schemas.recipe import RecipeVideo, RecipeVideoCreate
from app.services.database import supabase_service
from app.api.v1.endpoints.auth import verify_firebase_token, User
from app.core.settings import settings

router = APIRouter()
logger = logging.getLogger(__name__)

# Maximum video file size (100MB)
MAX_VIDEO_SIZE = 100 * 1024 * 1024

# Allowed video formats
ALLOWED_VIDEO_TYPES = {
    'video/mp4',
    'video/mpeg', 
    'video/quicktime',
    'video/x-msvideo',  # AVI
    'video/webm',
    'video/ogg',
    'video/3gpp',  # 3GP
    'video/x-flv'  # FLV
}

@router.post("/upload", response_model=RecipeVideo)
async def upload_video(
    recipe_id: str,
    file: UploadFile = File(...),
    current_user: User = Depends(verify_firebase_token)
):
    """Upload a video file for a recipe"""
    try:
        # Validate recipe_id format
        try:
            recipe_uuid = UUID(recipe_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid recipe ID format"
            )
        
        # Validate file type
        if file.content_type not in ALLOWED_VIDEO_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported video format: {file.content_type}. Allowed formats: {', '.join(ALLOWED_VIDEO_TYPES)}"
            )
        
        # Check file size
        file_content = await file.read()
        if len(file_content) > MAX_VIDEO_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Video file too large. Maximum size: {MAX_VIDEO_SIZE // (1024*1024)}MB"
            )
        
        # Reset file pointer
        await file.seek(0)
        
        # Verify recipe exists and user has permission
        recipe_result = await supabase_service.get_recipe_by_id(recipe_id)
        if not recipe_result.get('data'):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Recipe not found"
            )
        
        recipe_data = recipe_result['data'][0]
        if recipe_data.get('chef_id') != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only upload videos to your own recipes"
            )
        
        # Generate unique filename
        file_extension = Path(file.filename).suffix.lower()
        if not file_extension:
            file_extension = '.mp4'  # Default extension
        
        unique_filename = f"recipe_{recipe_id}_{current_user.uid}_{file.filename}"
        storage_path = f"recipe-videos/{recipe_id}/{unique_filename}"
        
        # Upload to Supabase storage
        try:
            client = supabase_service.get_client(use_service_key=True)
            
            # Upload file to storage
            upload_result = client.storage.from_("recipe-videos").upload(
                storage_path,
                file_content,
                file_options={
                    "content-type": file.content_type,
                    "cache-control": "3600"
                }
            )
            
            if upload_result.error:
                logger.error(f"Supabase storage upload error: {upload_result.error}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to upload video file"
                )
            
            # Get public URL
            public_url = client.storage.from_("recipe-videos").get_public_url(storage_path)
            
        except Exception as e:
            logger.error(f"Video upload error: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to upload video file"
            )
        
        # Save video metadata to database
        video_data = {
            'recipe_id': recipe_id,
            'filename': file.filename,
            'file_path': storage_path,
            'file_size': len(file_content),
            'mime_type': file.content_type,
            'uploaded_by': current_user.uid,
            'is_active': True
        }
        
        # TODO: Extract video metadata (duration, dimensions) using ffmpeg or similar
        # For now, we'll leave these as None
        
        result = await supabase_service.create_recipe_video(video_data)
        
        if not result.get('data'):
            # Clean up uploaded file if database insert fails
            try:
                client.storage.from_("recipe-videos").remove([storage_path])
            except:
                pass  # Log but don't fail the request
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save video metadata"
            )
        
        # Update recipe with video file path
        await supabase_service.update_recipe(recipe_id, {
            'video_file_path': storage_path
        })
        
        return RecipeVideo(**result['data'][0])
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error uploading video: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload video"
        )

@router.get("/recipe/{recipe_id}", response_model=List[RecipeVideo])
async def get_recipe_videos(recipe_id: str):
    """Get all videos for a recipe"""
    try:
        # Validate recipe_id format
        try:
            UUID(recipe_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid recipe ID format"
            )
        
        result = await supabase_service.get_recipe_videos(recipe_id)
        
        if not result.get('data'):
            return []
        
        return [RecipeVideo(**video) for video in result['data']]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting recipe videos: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get recipe videos"
        )

@router.delete("/{video_id}")
async def delete_video(
    video_id: str,
    current_user: User = Depends(verify_firebase_token)
):
    """Delete a video (soft delete)"""
    try:
        # Validate video_id format
        try:
            UUID(video_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid video ID format"
            )
        
        # Get video info
        video_result = await supabase_service.get_recipe_video_by_id(video_id)
        if not video_result.get('data'):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Video not found"
            )
        
        video_data = video_result['data'][0]
        
        # Check permission
        if video_data.get('uploaded_by') != current_user.uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only delete your own videos"
            )
        
        # Soft delete (mark as inactive)
        result = await supabase_service.update_recipe_video(video_id, {
            'is_active': False
        })
        
        if not result.get('data'):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete video"
            )
        
        return {"message": "Video deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting video: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete video"
        )
