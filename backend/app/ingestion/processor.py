import os
import asyncio
from typing import Optional, Dict, Any
from uuid import uuid4
import logging
from datetime import datetime

from app.schemas.ingestion import (
    IngestionJobCreate, IngestionJobUpdate, IngestionStatus, 
    ParsedRecipe, ProcessingResult
)
from app.schemas.recipe import RecipeCreate, IngredientCreate, NutritionBase
from app.services.database import supabase_service
from app.ingestion.extractor import text_extractor
from app.ingestion.language import language_detector
from app.ingestion.ai_parser import ai_parser
from app.ingestion.validation import recipe_validator
from app.ingestion.dedupe import recipe_deduplicator
from app.ingestion.file_watcher import directory_manager
from app.ingestion.ingredient_matcher import ingredient_matcher

logger = logging.getLogger(__name__)


class RecipeProcessor:
    """Main recipe processing pipeline"""
    
    def __init__(self):
        self.max_retries = 3
        self.retry_delays = [1, 2, 4]  # Exponential backoff
    
    async def process_file(self, file_path: str) -> ProcessingResult:
        """
        Process a single recipe file through the complete pipeline
        
        Args:
            file_path: Path to the file to process
            
        Returns:
            ProcessingResult with outcome details
        """
        job_id = None
        
        try:
            # Create ingestion job
            job_id = await self._create_ingestion_job(file_path)
            
            # Update status to processing
            await self._update_job_status(job_id, IngestionStatus.PROCESSING)
            
            # Extract text
            text, extraction_method = text_extractor.extract_text(file_path)
            logger.info(f"Extracted {len(text)} characters using {extraction_method}")
            
            # Detect language
            detected_lang, lang_confidence = language_detector.detect_language(text)
            logger.info(f"Detected language: {detected_lang} (confidence: {lang_confidence:.2f})")
            
            # Parse with AI
            parsed_recipe, ai_metadata = await ai_parser.parse_recipe(text, detected_lang)
            logger.info(f"AI parsing completed for: {parsed_recipe.title}")
            
            # Validate recipe
            is_valid, issues, confidence_score = recipe_validator.validate_recipe(parsed_recipe)
            logger.info(f"Validation completed: valid={is_valid}, confidence={confidence_score:.2f}")
            
            # Check for duplicates
            is_duplicate, duplicate_id, similar_ids = await recipe_deduplicator.check_duplicates(parsed_recipe)
            
            if is_duplicate:
                # Handle exact duplicate
                await self._handle_duplicate(job_id, duplicate_id, file_path)
                return ProcessingResult(
                    success=True,
                    job_id=job_id,
                    is_duplicate=True,
                    duplicate_of_recipe_id=duplicate_id
                )
            
            # Determine if manual review is needed
            needs_review = (not is_valid or 
                          confidence_score < 0.75 or 
                          len(similar_ids) > 0 or
                          len(issues) > 3)
            
            if needs_review:
                # Send to manual review
                await self._send_to_review(job_id, parsed_recipe, issues, similar_ids, confidence_score)
                return ProcessingResult(
                    success=True,
                    job_id=job_id,
                    needs_review=True,
                    confidence_score=confidence_score
                )
            
            # Create recipe in database
            recipe_id = await self._create_recipe(parsed_recipe, job_id)
            
            # Create fingerprint
            await recipe_deduplicator.create_fingerprint_record(recipe_id, parsed_recipe)
            
            # Update job as completed
            await self._update_job_status(
                job_id,
                IngestionStatus.COMPLETED,
                recipe_id=recipe_id,
                confidence_score=confidence_score
            )
            
            # Move file to processed directory
            directory_manager.move_file(file_path, 'processed')
            
            logger.info(f"Successfully processed recipe: {parsed_recipe.title} (ID: {recipe_id})")
            
            return ProcessingResult(
                success=True,
                job_id=job_id,
                recipe_id=recipe_id,
                confidence_score=confidence_score
            )
            
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Error processing file {file_path}: {error_msg}")
            
            if job_id:
                # Try to update job with error
                try:
                    await self._handle_processing_error(job_id, error_msg, file_path)
                except Exception as update_error:
                    logger.error(f"Failed to update job {job_id} with error: {update_error}")
            
            return ProcessingResult(
                success=False,
                job_id=job_id,
                error_message=error_msg
            )
    
    async def _create_ingestion_job(self, file_path: str) -> str:
        """Create a new ingestion job record"""
        file_info = text_extractor.get_file_info(file_path)

        job_data = IngestionJobCreate(
            source_path=file_path,
            original_filename=file_info['filename'],
            file_size_bytes=file_info['size_bytes'],
            mime_type=file_info['mime_type']
        )

        # Add the required status field
        job_dict = job_data.dict()
        job_dict['status'] = IngestionStatus.PENDING.value

        result = await supabase_service.create_ingestion_job(job_dict)

        if not result.data:
            raise Exception("Failed to create ingestion job")

        return result.data[0]['id']
    
    async def _update_job_status(self, job_id: str, status: IngestionStatus, **kwargs):
        """Update ingestion job status and metadata"""
        updates = {'status': status.value}
        updates.update(kwargs)
        
        await supabase_service.update_ingestion_job(job_id, updates)
    
    async def _handle_duplicate(self, job_id: str, duplicate_recipe_id: str, file_path: str):
        """Handle exact duplicate recipe"""
        await self._update_job_status(
            job_id,
            IngestionStatus.COMPLETED_DUPLICATE,
            duplicate_of_recipe_id=duplicate_recipe_id
        )
        
        # Move file to processed directory
        directory_manager.move_file(file_path, 'processed')
        
        logger.info(f"File {file_path} is duplicate of recipe {duplicate_recipe_id}")
    
    async def _send_to_review(self, job_id: str, recipe: ParsedRecipe, issues: list, 
                            similar_ids: list, confidence_score: float):
        """Send recipe to manual review queue"""
        meta = {
            'issues': issues,
            'similar_recipe_ids': similar_ids,
            'parsed_recipe': recipe.dict()
        }
        
        await self._update_job_status(
            job_id,
            IngestionStatus.NEEDS_REVIEW,
            confidence_score=confidence_score,
            meta=meta
        )
        
        logger.info(f"Recipe sent to manual review: {recipe.title}")
    
    async def _create_recipe(self, parsed_recipe: ParsedRecipe, job_id: str) -> str:
        """Create recipe in database from parsed data"""
        # Map category name to category_id
        category_id = await self._get_category_id(parsed_recipe.category)

        # Add cuisine to tags if detected and not 'unknown'
        tags = parsed_recipe.tags.copy() if parsed_recipe.tags else []
        if parsed_recipe.cuisine and parsed_recipe.cuisine.lower() != 'unknown':
            # Add cuisine as a tag if not already present
            cuisine_tag = parsed_recipe.cuisine.lower()
            if cuisine_tag not in [tag.lower() for tag in tags]:
                tags.append(parsed_recipe.cuisine)

        # Convert to database schema - map to actual column names
        recipe_data = {
            'id': str(uuid4()),
            'chef_id': 'a06dccc2-0e3d-45ee-9d16-cb348898dd7a',  # Use existing chef
            'title': parsed_recipe.title,
            'description': parsed_recipe.description,
            'category_id': category_id,  # Map to category_id using lookup
            'difficulty_level': parsed_recipe.difficulty,  # Map to difficulty_level
            'prep_time_minutes': parsed_recipe.prep_time_minutes,
            'cook_time_minutes': parsed_recipe.cook_time_minutes,
            'servings': parsed_recipe.servings,
            'instructions': '\n'.join(parsed_recipe.instructions),  # Convert list to text
            'tags': tags,  # Include cuisine in tags
            'is_featured': False
        }

        # Process ingredients with smart matching to existing base ingredients
        logger.info(f"Processing {len(parsed_recipe.ingredients)} ingredients...")
        processed_ingredients = await ingredient_matcher.process_ingredients(parsed_recipe.ingredients)
        logger.info(f"Successfully processed {len(processed_ingredients)} ingredients")

        # Create recipe with ingredients
        result = await supabase_service.create_recipe_with_ingredients(recipe_data, processed_ingredients)
        
        if not result.data:
            raise Exception("Failed to create recipe in database")
        
        return result.data[0]['id']

    async def _get_category_id(self, category_name: str) -> Optional[str]:
        """Map category name to category_id"""
        if not category_name or category_name.lower() == 'unknown':
            return None

        # Comprehensive category mapping based on available categories
        category_mapping = {
            # Appetizers
            'appetizer': '20000000-0000-0000-0000-000000000001',
            'appetizers': '20000000-0000-0000-0000-000000000001',
            'starter': '20000000-0000-0000-0000-000000000001',
            'antipasti': '20000000-0000-0000-0000-000000000001',
            'hors d\'oeuvres': '20000000-0000-0000-0000-000000000001',

            # First Courses (Pasta, Soups, etc.)
            'first course': '20000000-0000-0000-0000-000000000002',
            'pasta': '20000000-0000-0000-0000-000000000002',
            'soup': '20000000-0000-0000-0000-000000000002',
            'soups': '20000000-0000-0000-0000-000000000002',
            'risotto': '20000000-0000-0000-0000-000000000002',
            'noodles': '20000000-0000-0000-0000-000000000002',
            'ramen': '20000000-0000-0000-0000-000000000002',
            'pho': '20000000-0000-0000-0000-000000000002',

            # Second Courses (Main dishes)
            'main course': '20000000-0000-0000-0000-000000000003',
            'main': '20000000-0000-0000-0000-000000000003',
            'entree': '20000000-0000-0000-0000-000000000003',
            'main dish': '20000000-0000-0000-0000-000000000003',
            'dinner': '20000000-0000-0000-0000-000000000003',
            'lunch': '20000000-0000-0000-0000-000000000003',
            'meat': '20000000-0000-0000-0000-000000000003',
            'chicken': '20000000-0000-0000-0000-000000000003',
            'beef': '20000000-0000-0000-0000-000000000003',
            'pork': '20000000-0000-0000-0000-000000000003',
            'fish': '20000000-0000-0000-0000-000000000003',
            'seafood': '20000000-0000-0000-0000-000000000003',
            'curry': '20000000-0000-0000-0000-000000000003',
            'stew': '20000000-0000-0000-0000-000000000003',
            'casserole': '20000000-0000-0000-0000-000000000003',

            # Side Dishes
            'side dish': '20000000-0000-0000-0000-000000000004',
            'side': '20000000-0000-0000-0000-000000000004',
            'sides': '20000000-0000-0000-0000-000000000004',
            'vegetable': '20000000-0000-0000-0000-000000000004',
            'vegetables': '20000000-0000-0000-0000-000000000004',
            'accompaniment': '20000000-0000-0000-0000-000000000004',

            # Desserts
            'dessert': '20000000-0000-0000-0000-000000000005',
            'desserts': '20000000-0000-0000-0000-000000000005',
            'sweet': '20000000-0000-0000-0000-000000000005',
            'sweets': '20000000-0000-0000-0000-000000000005',
            'cake': '20000000-0000-0000-0000-000000000005',
            'cookies': '20000000-0000-0000-0000-000000000005',
            'ice cream': '20000000-0000-0000-0000-000000000005',
            'pudding': '20000000-0000-0000-0000-000000000005',
            'pie': '20000000-0000-0000-0000-000000000005',
            'tart': '20000000-0000-0000-0000-000000000005',

            # Beverages
            'beverage': '20000000-0000-0000-0000-000000000006',
            'beverages': '20000000-0000-0000-0000-000000000006',
            'drink': '20000000-0000-0000-0000-000000000006',
            'drinks': '20000000-0000-0000-0000-000000000006',
            'cocktail': '20000000-0000-0000-0000-000000000006',
            'cocktails': '20000000-0000-0000-0000-000000000006',
            'smoothie': '20000000-0000-0000-0000-000000000006',
            'smoothies': '20000000-0000-0000-0000-000000000006',
            'juice': '20000000-0000-0000-0000-000000000006',
            'tea': '20000000-0000-0000-0000-000000000006',
            'coffee': '20000000-0000-0000-0000-000000000006',

            # Bread & Baked Goods
            'bread': '20000000-0000-0000-0000-000000000007',
            'bread & baked goods': '20000000-0000-0000-0000-000000000007',
            'baked': '20000000-0000-0000-0000-000000000007',
            'baked goods': '20000000-0000-0000-0000-000000000007',
            'pizza': '20000000-0000-0000-0000-000000000007',
            'sandwich': '20000000-0000-0000-0000-000000000007',
            'sandwiches': '20000000-0000-0000-0000-000000000007',
            'pastry': '20000000-0000-0000-0000-000000000007',
            'pastries': '20000000-0000-0000-0000-000000000007',
            'muffin': '20000000-0000-0000-0000-000000000007',
            'muffins': '20000000-0000-0000-0000-000000000007',

            # Salads
            'salad': '20000000-0000-0000-0000-000000000008',
            'salads': '20000000-0000-0000-0000-000000000008',

            # Special categories that should map to specific sections
            'sauce': '20000000-0000-0000-0000-000000000004',  # Side Dishes (sauces are accompaniments)
            'sauces': '20000000-0000-0000-0000-000000000004',
            'marinade': '20000000-0000-0000-0000-000000000004',
            'marinades': '20000000-0000-0000-0000-000000000004',
            'dressing': '20000000-0000-0000-0000-000000000008',  # Salads (dressings go with salads)
            'dressings': '20000000-0000-0000-0000-000000000008',
            'breakfast': '20000000-0000-0000-0000-000000000002',  # First Courses
            'brunch': '20000000-0000-0000-0000-000000000002',
            'snack': '20000000-0000-0000-0000-000000000001',  # Appetizers
            'snacks': '20000000-0000-0000-0000-000000000001',
        }

        category_lower = category_name.lower().strip()
        category_id = category_mapping.get(category_lower)

        if category_id:
            logger.info(f"Mapped category '{category_name}' to ID: {category_id}")
            return category_id
        else:
            logger.info(f"No mapping found for category '{category_name}', using 'Other'")
            return '20000000-0000-0000-0000-000000000099'  # Other

    async def _handle_processing_error(self, job_id: str, error_msg: str, file_path: str):
        """Handle processing error with retry logic"""
        # Get current job to check retry count
        job_result = await supabase_service.get_ingestion_job(job_id)
        
        if not job_result.data:
            logger.error(f"Could not find job {job_id} to update error")
            return
        
        job = job_result.data[0]
        retries = job.get('retries', 0)
        
        if retries < self.max_retries:
            # Increment retry count and schedule retry
            await self._update_job_status(
                job_id,
                IngestionStatus.PENDING,
                retries=retries + 1,
                error_message=error_msg
            )
            
            # Schedule retry with delay
            delay = self.retry_delays[min(retries, len(self.retry_delays) - 1)]
            logger.info(f"Scheduling retry {retries + 1} for job {job_id} in {delay}s")
            
            # In a real implementation, you'd use a proper job queue
            # For now, we'll just log the retry intent
            
        else:
            # Max retries exceeded, send to DLQ
            await self._update_job_status(
                job_id,
                IngestionStatus.DLQ,
                error_message=f"Max retries exceeded: {error_msg}"
            )
            
            # Move file to DLQ directory
            directory_manager.move_file(file_path, 'dlq')
            
            logger.error(f"Job {job_id} moved to DLQ after {retries} retries")


# Global instance
recipe_processor = RecipeProcessor()
