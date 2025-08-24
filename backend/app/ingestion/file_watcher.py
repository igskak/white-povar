import os
import asyncio
from pathlib import Path
from typing import Optional, Callable, Awaitable
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileMovedEvent

logger = logging.getLogger(__name__)


class RecipeFileHandler(FileSystemEventHandler):
    """Handle file system events for recipe ingestion"""
    
    def __init__(self, callback: Callable[[str], Awaitable[None]]):
        self.callback = callback
        self.supported_extensions = {'.txt', '.pdf', '.docx', '.doc'}
        self.processing_files = set()  # Track files being processed
        
    def on_created(self, event):
        """Handle file creation events"""
        if isinstance(event, FileCreatedEvent) and not event.is_directory:
            asyncio.create_task(self._handle_file(event.src_path))
    
    def on_moved(self, event):
        """Handle file move events (e.g., when file is fully written)"""
        if isinstance(event, FileMovedEvent) and not event.is_directory:
            asyncio.create_task(self._handle_file(event.dest_path))
    
    async def _handle_file(self, file_path: str):
        """Handle a new file"""
        try:
            # Check if file has supported extension
            if not self._is_supported_file(file_path):
                logger.debug(f"Ignoring unsupported file: {file_path}")
                return
            
            # Avoid processing the same file multiple times
            if file_path in self.processing_files:
                return
            
            self.processing_files.add(file_path)
            
            try:
                # Wait a bit to ensure file is fully written
                await asyncio.sleep(1)
                
                # Check if file still exists and is readable
                if not os.path.exists(file_path):
                    logger.warning(f"File disappeared: {file_path}")
                    return
                
                # Call the processing callback
                await self.callback(file_path)
                
            finally:
                self.processing_files.discard(file_path)
                
        except Exception as e:
            logger.error(f"Error handling file {file_path}: {str(e)}")
    
    def _is_supported_file(self, file_path: str) -> bool:
        """Check if file has supported extension"""
        return Path(file_path).suffix.lower() in self.supported_extensions


class FileWatcher:
    """Watch directory for new recipe files"""
    
    def __init__(self, watch_directory: str, callback: Callable[[str], Awaitable[None]]):
        self.watch_directory = Path(watch_directory)
        self.callback = callback
        self.observer = None
        self.handler = None
        self._running = False
    
    def start(self):
        """Start watching the directory"""
        if self._running:
            logger.warning("File watcher is already running")
            return
        
        # Ensure directory exists
        self.watch_directory.mkdir(parents=True, exist_ok=True)
        
        # Create handler and observer
        self.handler = RecipeFileHandler(self.callback)
        self.observer = Observer()
        self.observer.schedule(self.handler, str(self.watch_directory), recursive=False)
        
        # Start observer
        self.observer.start()
        self._running = True
        
        logger.info(f"Started watching directory: {self.watch_directory}")
    
    def stop(self):
        """Stop watching the directory"""
        if not self._running:
            return
        
        if self.observer:
            self.observer.stop()
            self.observer.join()
        
        self._running = False
        logger.info("Stopped file watcher")
    
    async def process_existing_files(self):
        """Process any existing files in the watch directory"""
        if not self.watch_directory.exists():
            return
        
        logger.info(f"Processing existing files in {self.watch_directory}")
        
        for file_path in self.watch_directory.iterdir():
            if file_path.is_file() and self.handler._is_supported_file(str(file_path)):
                try:
                    await self.callback(str(file_path))
                except Exception as e:
                    logger.error(f"Error processing existing file {file_path}: {str(e)}")
    
    @property
    def is_running(self) -> bool:
        """Check if watcher is running"""
        return self._running


class DirectoryManager:
    """Manage ingestion directories"""
    
    def __init__(self, base_path: str = "data/ingestion"):
        self.base_path = Path(base_path)
        self.inbox_dir = self.base_path / "inbox"
        self.processed_dir = self.base_path / "processed"
        self.failed_dir = self.base_path / "failed"
        self.dlq_dir = self.base_path / "dlq"
    
    def setup_directories(self):
        """Create all necessary directories"""
        directories = [self.inbox_dir, self.processed_dir, self.failed_dir, self.dlq_dir]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.info(f"Created directory: {directory}")
    
    def move_file(self, source_path: str, destination: str) -> str:
        """
        Move file to destination directory
        
        Args:
            source_path: Source file path
            destination: 'processed', 'failed', or 'dlq'
            
        Returns:
            New file path
        """
        source = Path(source_path)
        
        if destination == 'processed':
            dest_dir = self.processed_dir
        elif destination == 'failed':
            dest_dir = self.failed_dir
        elif destination == 'dlq':
            dest_dir = self.dlq_dir
        else:
            raise ValueError(f"Invalid destination: {destination}")
        
        # Create unique filename if file already exists
        dest_path = dest_dir / source.name
        counter = 1
        while dest_path.exists():
            stem = source.stem
            suffix = source.suffix
            dest_path = dest_dir / f"{stem}_{counter}{suffix}"
            counter += 1
        
        # Move file
        source.rename(dest_path)
        logger.info(f"Moved file from {source_path} to {dest_path}")
        
        return str(dest_path)
    
    def get_inbox_path(self) -> str:
        """Get inbox directory path"""
        return str(self.inbox_dir)
    
    def cleanup_old_files(self, days: int = 30):
        """Clean up old processed files"""
        import time
        
        cutoff_time = time.time() - (days * 24 * 60 * 60)
        
        for directory in [self.processed_dir, self.failed_dir]:
            if not directory.exists():
                continue
                
            for file_path in directory.iterdir():
                if file_path.is_file() and file_path.stat().st_mtime < cutoff_time:
                    try:
                        file_path.unlink()
                        logger.info(f"Cleaned up old file: {file_path}")
                    except Exception as e:
                        logger.error(f"Error cleaning up file {file_path}: {str(e)}")


# Global instances
directory_manager = DirectoryManager()
