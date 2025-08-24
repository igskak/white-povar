import asyncio
import logging
from typing import Optional
from contextlib import asynccontextmanager

from app.ingestion.file_watcher import FileWatcher, directory_manager
from app.ingestion.processor import recipe_processor
from app.core.settings import settings

logger = logging.getLogger(__name__)


class IngestionService:
    """Main ingestion service that coordinates file watching and processing"""
    
    def __init__(self):
        self.file_watcher: Optional[FileWatcher] = None
        self.processing_queue = asyncio.Queue()
        self.worker_tasks = []
        self.is_running = False
        self.num_workers = getattr(settings, 'ingestion_workers', 2)
    
    async def start(self):
        """Start the ingestion service"""
        if self.is_running:
            logger.warning("Ingestion service is already running")
            return
        
        logger.info("Starting ingestion service...")
        
        # Setup directories
        directory_manager.setup_directories()
        
        # Start file watcher
        inbox_path = directory_manager.get_inbox_path()
        self.file_watcher = FileWatcher(inbox_path, self._enqueue_file)
        
        # Process any existing files first
        await self.file_watcher.process_existing_files()
        
        # Start file watcher
        self.file_watcher.start()
        
        # Start worker tasks
        for i in range(self.num_workers):
            task = asyncio.create_task(self._worker(f"worker-{i}"))
            self.worker_tasks.append(task)
        
        self.is_running = True
        logger.info(f"Ingestion service started with {self.num_workers} workers")
    
    async def stop(self):
        """Stop the ingestion service"""
        if not self.is_running:
            return
        
        logger.info("Stopping ingestion service...")
        
        # Stop file watcher
        if self.file_watcher:
            self.file_watcher.stop()
        
        # Cancel worker tasks
        for task in self.worker_tasks:
            task.cancel()
        
        # Wait for tasks to complete
        if self.worker_tasks:
            await asyncio.gather(*self.worker_tasks, return_exceptions=True)
        
        self.worker_tasks.clear()
        self.is_running = False
        
        logger.info("Ingestion service stopped")
    
    async def _enqueue_file(self, file_path: str):
        """Enqueue a file for processing"""
        try:
            await self.processing_queue.put(file_path)
            logger.info(f"Enqueued file for processing: {file_path}")
        except Exception as e:
            logger.error(f"Failed to enqueue file {file_path}: {str(e)}")
    
    async def _worker(self, worker_name: str):
        """Worker task that processes files from the queue"""
        logger.info(f"Started worker: {worker_name}")
        
        try:
            while True:
                try:
                    # Get file from queue with timeout
                    file_path = await asyncio.wait_for(
                        self.processing_queue.get(), 
                        timeout=1.0
                    )
                    
                    logger.info(f"{worker_name} processing: {file_path}")
                    
                    # Process the file
                    result = await recipe_processor.process_file(file_path)
                    
                    if result.success:
                        if result.is_duplicate:
                            logger.info(f"{worker_name} completed (duplicate): {file_path}")
                        elif result.needs_review:
                            logger.info(f"{worker_name} completed (needs review): {file_path}")
                        else:
                            logger.info(f"{worker_name} completed successfully: {file_path}")
                    else:
                        logger.error(f"{worker_name} failed: {file_path} - {result.error_message}")
                    
                    # Mark task as done
                    self.processing_queue.task_done()
                    
                except asyncio.TimeoutError:
                    # No files to process, continue waiting
                    continue
                    
                except asyncio.CancelledError:
                    logger.info(f"Worker {worker_name} cancelled")
                    break
                    
                except Exception as e:
                    logger.error(f"Worker {worker_name} error: {str(e)}")
                    # Continue processing other files
                    
        except Exception as e:
            logger.error(f"Worker {worker_name} crashed: {str(e)}")
        
        logger.info(f"Worker {worker_name} stopped")
    
    async def process_single_file(self, file_path: str):
        """Process a single file immediately (for manual processing)"""
        logger.info(f"Processing single file: {file_path}")
        return await recipe_processor.process_file(file_path)
    
    def get_status(self) -> dict:
        """Get service status"""
        return {
            'is_running': self.is_running,
            'num_workers': len(self.worker_tasks),
            'queue_size': self.processing_queue.qsize(),
            'file_watcher_running': self.file_watcher.is_running if self.file_watcher else False,
            'inbox_path': directory_manager.get_inbox_path()
        }


# Global instance
ingestion_service = IngestionService()


@asynccontextmanager
async def lifespan_manager():
    """Context manager for service lifecycle"""
    try:
        await ingestion_service.start()
        yield ingestion_service
    finally:
        await ingestion_service.stop()


# Startup and shutdown functions for FastAPI
async def startup_ingestion():
    """Startup function for FastAPI"""
    await ingestion_service.start()


async def shutdown_ingestion():
    """Shutdown function for FastAPI"""
    await ingestion_service.stop()
