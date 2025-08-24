from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File, status
from typing import Optional, List
from uuid import UUID
import logging
import os
import tempfile

from app.schemas.ingestion import (
    IngestionJob, IngestionJobList, IngestionStats, ProcessingResult,
    IngestionStatus, ReviewDecision
)
from app.services.database import supabase_service
from app.ingestion.service import ingestion_service
from app.ingestion.file_watcher import directory_manager
from app.api.v1.endpoints.auth import verify_firebase_token, User

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/status")
async def get_ingestion_status():
    """Get ingestion service status"""
    try:
        service_status = ingestion_service.get_status()
        return {
            "service": service_status,
            "directories": {
                "inbox": directory_manager.get_inbox_path(),
                "processed": str(directory_manager.processed_dir),
                "failed": str(directory_manager.failed_dir),
                "dlq": str(directory_manager.dlq_dir)
            }
        }
    except Exception as e:
        logger.error(f"Error getting ingestion status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get ingestion status"
        )


@router.get("/jobs", response_model=IngestionJobList)
async def get_ingestion_jobs(
    status_filter: Optional[IngestionStatus] = Query(None, description="Filter by job status"),
    limit: int = Query(50, ge=1, le=100, description="Number of jobs to return"),
    offset: int = Query(0, ge=0, description="Number of jobs to skip"),
    current_user: User = Depends(verify_firebase_token)
):
    """Get ingestion jobs with optional filtering"""
    try:
        status_value = status_filter.value if status_filter else None
        result = await supabase_service.get_ingestion_jobs(status_value, limit, offset)
        
        if not result.data:
            return IngestionJobList(jobs=[], total_count=0, has_more=False)
        
        jobs = [IngestionJob(**job) for job in result.data]
        
        # Get total count for pagination
        # Note: In a real implementation, you'd want a separate count query
        total_count = len(jobs)
        has_more = len(jobs) == limit
        
        return IngestionJobList(
            jobs=jobs,
            total_count=total_count,
            has_more=has_more
        )
        
    except Exception as e:
        logger.error(f"Error getting ingestion jobs: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get ingestion jobs"
        )


@router.get("/jobs/{job_id}", response_model=IngestionJob)
async def get_ingestion_job(
    job_id: UUID,
    current_user: User = Depends(verify_firebase_token)
):
    """Get specific ingestion job by ID"""
    try:
        result = await supabase_service.get_ingestion_job(str(job_id))
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Ingestion job not found"
            )
        
        return IngestionJob(**result.data[0])
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting ingestion job {job_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get ingestion job"
        )


@router.post("/jobs/{job_id}/reprocess")
async def reprocess_job(
    job_id: UUID,
    current_user: User = Depends(verify_firebase_token)
):
    """Reprocess a failed or DLQ job"""
    try:
        # Get the job
        result = await supabase_service.get_ingestion_job(str(job_id))
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Ingestion job not found"
            )
        
        job = result.data[0]
        
        # Check if job can be reprocessed
        if job['status'] not in ['FAILED', 'DLQ']:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only failed or DLQ jobs can be reprocessed"
            )
        
        # Check if source file still exists
        source_path = job['source_path']
        if not os.path.exists(source_path):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Source file no longer exists"
            )
        
        # Reset job status and retry count
        await supabase_service.update_ingestion_job(str(job_id), {
            'status': 'PENDING',
            'retries': 0,
            'error_message': None
        })
        
        # Process the file
        result = await ingestion_service.process_single_file(source_path)
        
        return {
            "message": "Job reprocessing initiated",
            "job_id": str(job_id),
            "result": result.dict()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error reprocessing job {job_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to reprocess job"
        )


@router.post("/jobs/{job_id}/review")
async def review_job(
    job_id: UUID,
    decision: ReviewDecision,
    notes: Optional[str] = None,
    current_user: User = Depends(verify_firebase_token)
):
    """Make a review decision on a job that needs manual review"""
    try:
        # Get the job
        result = await supabase_service.get_ingestion_job(str(job_id))
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Ingestion job not found"
            )
        
        job = result.data[0]
        
        # Check if job needs review
        if job['status'] != 'NEEDS_REVIEW':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Job is not in review status"
            )
        
        if decision == ReviewDecision.APPROVED:
            # Extract parsed recipe from meta and create it
            meta = job.get('meta', {})
            parsed_recipe_data = meta.get('parsed_recipe')
            
            if not parsed_recipe_data:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No parsed recipe data found in job"
                )
            
            # Process the approved recipe
            # This would involve creating the recipe in the database
            # For now, just update the job status
            await supabase_service.update_ingestion_job(str(job_id), {
                'status': 'COMPLETED',
                'reviewer_notes': notes,
                'reviewed_at': 'NOW()'
            })
            
            message = "Recipe approved and created"
            
        elif decision == ReviewDecision.REJECTED:
            await supabase_service.update_ingestion_job(str(job_id), {
                'status': 'FAILED',
                'reviewer_notes': notes,
                'reviewed_at': 'NOW()',
                'error_message': f"Rejected by reviewer: {notes or 'No reason provided'}"
            })
            
            message = "Recipe rejected"
            
        else:  # NEEDS_REVISION
            await supabase_service.update_ingestion_job(str(job_id), {
                'status': 'PENDING',
                'reviewer_notes': notes,
                'reviewed_at': 'NOW()',
                'retries': 0
            })
            
            message = "Recipe sent back for revision"
        
        return {
            "message": message,
            "job_id": str(job_id),
            "decision": decision.value
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error reviewing job {job_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to review job"
        )


@router.post("/upload", response_model=ProcessingResult)
async def upload_recipe_file(
    file: UploadFile = File(...),
    current_user: User = Depends(verify_firebase_token)
):
    """Upload a recipe file for processing"""
    try:
        # Validate file type
        allowed_types = {
            'text/plain', 'application/pdf',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/msword'
        }
        
        if file.content_type not in allowed_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported file type: {file.content_type}"
            )
        
        # Save file to inbox
        inbox_path = directory_manager.get_inbox_path()
        file_path = os.path.join(inbox_path, file.filename)
        
        # Ensure unique filename
        counter = 1
        original_path = file_path
        while os.path.exists(file_path):
            name, ext = os.path.splitext(original_path)
            file_path = f"{name}_{counter}{ext}"
            counter += 1
        
        # Write file
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        
        logger.info(f"Uploaded file saved to: {file_path}")
        
        # Process the file immediately
        result = await ingestion_service.process_single_file(file_path)
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload and process file"
        )


@router.get("/stats", response_model=IngestionStats)
async def get_ingestion_stats(
    current_user: User = Depends(verify_firebase_token)
):
    """Get ingestion pipeline statistics"""
    try:
        # Get job counts by status
        stats_data = {
            'total_jobs': 0,
            'pending_jobs': 0,
            'processing_jobs': 0,
            'needs_review_jobs': 0,
            'completed_jobs': 0,
            'failed_jobs': 0,
            'dlq_jobs': 0,
            'duplicate_jobs': 0
        }
        
        # Get all jobs (in a real implementation, you'd use aggregation queries)
        result = await supabase_service.get_ingestion_jobs(None, 1000, 0)
        
        if result.data:
            stats_data['total_jobs'] = len(result.data)
            
            for job in result.data:
                status = job['status']
                if status == 'PENDING':
                    stats_data['pending_jobs'] += 1
                elif status == 'PROCESSING':
                    stats_data['processing_jobs'] += 1
                elif status == 'NEEDS_REVIEW':
                    stats_data['needs_review_jobs'] += 1
                elif status == 'COMPLETED':
                    stats_data['completed_jobs'] += 1
                elif status == 'FAILED':
                    stats_data['failed_jobs'] += 1
                elif status == 'DLQ':
                    stats_data['dlq_jobs'] += 1
                elif status == 'COMPLETED_DUPLICATE':
                    stats_data['duplicate_jobs'] += 1
        
        # Calculate rates
        total = stats_data['total_jobs']
        if total > 0:
            success_rate = (stats_data['completed_jobs'] + stats_data['duplicate_jobs']) / total
            review_rate = stats_data['needs_review_jobs'] / total
        else:
            success_rate = 0.0
            review_rate = 0.0
        
        stats_data['success_rate'] = success_rate
        stats_data['review_rate'] = review_rate
        
        return IngestionStats(**stats_data)
        
    except Exception as e:
        logger.error(f"Error getting ingestion stats: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get ingestion statistics"
        )
