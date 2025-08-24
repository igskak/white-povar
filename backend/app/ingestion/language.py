from typing import Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class LanguageDetector:
    """Detect language of text content"""
    
    def __init__(self):
        self._detector = None
        self._initialize_detector()
    
    def _initialize_detector(self):
        """Initialize language detection library"""
        try:
            import langdetect
            self._detector = langdetect
            logger.info("Language detector initialized with langdetect")
        except ImportError:
            logger.warning("langdetect not available. Language detection will be disabled.")
            self._detector = None
    
    def detect_language(self, text: str) -> Tuple[Optional[str], float]:
        """
        Detect language of text
        
        Args:
            text: Text to analyze
            
        Returns:
            Tuple of (language_code, confidence)
            language_code: ISO 639-1 code (e.g., 'en', 'es', 'fr') or None if detection fails
            confidence: Confidence score 0.0-1.0
        """
        if not self._detector or not text.strip():
            return None, 0.0
        
        try:
            # Clean text for better detection
            clean_text = self._clean_text_for_detection(text)
            if len(clean_text) < 50:  # Too short for reliable detection
                return None, 0.0
            
            # Detect language
            detected = self._detector.detect(clean_text)
            
            # Get confidence using detect_langs
            try:
                langs = self._detector.detect_langs(clean_text)
                confidence = langs[0].prob if langs else 0.0
            except:
                confidence = 0.8  # Default confidence if we can't get probability
            
            logger.info(f"Detected language: {detected} (confidence: {confidence:.2f})")
            return detected, confidence
            
        except Exception as e:
            logger.warning(f"Language detection failed: {str(e)}")
            return None, 0.0
    
    def _clean_text_for_detection(self, text: str) -> str:
        """Clean text to improve language detection accuracy"""
        import re
        
        # Remove common recipe-specific patterns that might confuse detection
        patterns_to_remove = [
            r'\d+\s*(cups?|tbsp|tsp|oz|lbs?|kg|g|ml|l)\b',  # Measurements
            r'\d+\s*°[CF]',  # Temperatures
            r'\d+\s*minutes?',  # Time
            r'\d+\s*hours?',
            r'\d+\s*servings?',
            r'[^\w\s]',  # Punctuation (keep only words and spaces)
        ]
        
        cleaned = text
        for pattern in patterns_to_remove:
            cleaned = re.sub(pattern, ' ', cleaned, flags=re.IGNORECASE)
        
        # Remove extra whitespace
        cleaned = ' '.join(cleaned.split())
        
        return cleaned
    
    def needs_translation(self, text: str, target_language: str = 'en') -> bool:
        """
        Check if text needs translation to target language
        
        Args:
            text: Text to check
            target_language: Target language code (default: 'en')
            
        Returns:
            True if translation is needed, False otherwise
        """
        detected_lang, confidence = self.detect_language(text)
        
        # If detection failed or confidence is low, assume no translation needed
        if not detected_lang or confidence < 0.7:
            return False
        
        # If detected language is different from target, translation is needed
        return detected_lang != target_language


# Global instance
language_detector = LanguageDetector()
