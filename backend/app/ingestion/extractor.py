import os
import mimetypes
from pathlib import Path
from typing import Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class TextExtractor:
    """Extract text from various document formats"""
    
    def __init__(self):
        self.supported_types = {
            'text/plain': self._extract_txt,
            'application/pdf': self._extract_pdf,
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document': self._extract_docx,
            'application/msword': self._extract_doc
        }
    
    def extract_text(self, file_path: str) -> Tuple[str, str]:
        """
        Extract text from file and return (text, extraction_method)
        
        Args:
            file_path: Path to the file
            
        Returns:
            Tuple of (extracted_text, extraction_method)
            
        Raises:
            ValueError: If file type is not supported
            Exception: If extraction fails
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        # Detect MIME type
        mime_type, _ = mimetypes.guess_type(file_path)
        if not mime_type:
            # Fallback: try to detect by extension
            ext = Path(file_path).suffix.lower()
            ext_to_mime = {
                '.txt': 'text/plain',
                '.pdf': 'application/pdf',
                '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                '.doc': 'application/msword'
            }
            mime_type = ext_to_mime.get(ext)
        
        if not mime_type or mime_type not in self.supported_types:
            raise ValueError(f"Unsupported file type: {mime_type}")
        
        try:
            extractor = self.supported_types[mime_type]
            text = extractor(file_path)
            method = f"{mime_type.split('/')[-1]}_parser"
            
            if not text.strip():
                raise ValueError("No text content extracted from file")
            
            logger.info(f"Successfully extracted {len(text)} characters from {file_path}")
            return text, method
            
        except Exception as e:
            logger.error(f"Failed to extract text from {file_path}: {str(e)}")
            raise
    
    def _extract_txt(self, file_path: str) -> str:
        """Extract text from plain text file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()
        except UnicodeDecodeError:
            # Try with different encoding
            with open(file_path, 'r', encoding='latin-1') as f:
                return f.read()
    
    def _extract_pdf(self, file_path: str) -> str:
        """Extract text from PDF file"""
        try:
            import pypdf
            text = ""
            with open(file_path, 'rb') as f:
                reader = pypdf.PdfReader(f)
                for page in reader.pages:
                    text += page.extract_text() + "\n"
            return text
        except ImportError:
            raise ImportError("pypdf package required for PDF extraction. Install with: pip install pypdf")
        except Exception as e:
            # Fallback to pdfminer if pypdf fails
            try:
                return self._extract_pdf_pdfminer(file_path)
            except ImportError:
                raise Exception(f"PDF extraction failed: {str(e)}. Consider installing pdfminer.six for better PDF support.")
    
    def _extract_pdf_pdfminer(self, file_path: str) -> str:
        """Fallback PDF extraction using pdfminer"""
        from pdfminer.high_level import extract_text
        return extract_text(file_path)
    
    def _extract_docx(self, file_path: str) -> str:
        """Extract text from DOCX file"""
        try:
            import docx
            doc = docx.Document(file_path)
            text = ""
            for paragraph in doc.paragraphs:
                text += paragraph.text + "\n"
            return text
        except ImportError:
            raise ImportError("python-docx package required for DOCX extraction. Install with: pip install python-docx")
    
    def _extract_doc(self, file_path: str) -> str:
        """Extract text from legacy DOC file"""
        # For legacy DOC files, we'll try a few approaches
        try:
            # Try using textract if available
            import textract
            text = textract.process(file_path).decode('utf-8')
            return text
        except ImportError:
            # Fallback: suggest conversion
            raise ImportError(
                "Legacy DOC file support requires textract package. "
                "Install with: pip install textract, or convert the file to DOCX/PDF format."
            )
        except Exception as e:
            raise Exception(f"Failed to extract text from DOC file: {str(e)}. Consider converting to DOCX or PDF format.")
    
    def get_file_info(self, file_path: str) -> dict:
        """Get basic file information"""
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        stat = os.stat(file_path)
        mime_type, _ = mimetypes.guess_type(file_path)
        
        return {
            'filename': os.path.basename(file_path),
            'size_bytes': stat.st_size,
            'mime_type': mime_type,
            'is_supported': mime_type in self.supported_types if mime_type else False
        }


# Global instance
text_extractor = TextExtractor()
