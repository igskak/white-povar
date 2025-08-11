import httpx
import json
import jwt
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import logging

from app.core.settings import settings

logger = logging.getLogger(__name__)

class FirebaseAuth:
    """Firebase Authentication service for token verification"""
    
    def __init__(self):
        self.project_id = settings.firebase_project_id
        self.public_keys_url = f"https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
        self.issuer = f"https://securetoken.google.com/{self.project_id}"
        self.audience = self.project_id
        self._public_keys = {}
        self._keys_last_updated = None
    
    async def verify_token(self, token: str) -> Dict[str, Any]:
        """
        Verify Firebase ID token and return user claims
        
        Args:
            token: Firebase ID token
            
        Returns:
            Dict containing user claims
            
        Raises:
            ValueError: If token is invalid
        """
        try:
            # Get public keys for verification
            await self._update_public_keys()
            
            # Decode token header to get key ID
            unverified_header = jwt.get_unverified_header(token)
            key_id = unverified_header.get('kid')
            
            if not key_id or key_id not in self._public_keys:
                raise ValueError("Invalid token: key ID not found")
            
            # Get the public key
            public_key = self._public_keys[key_id]
            
            # Verify and decode the token
            decoded_token = jwt.decode(
                token,
                public_key,
                algorithms=['RS256'],
                audience=self.audience,
                issuer=self.issuer,
                options={
                    'verify_exp': True,
                    'verify_iat': True,
                    'verify_aud': True,
                    'verify_iss': True
                }
            )
            
            # Additional validation
            now = datetime.utcnow().timestamp()
            
            # Check if token is expired
            if decoded_token.get('exp', 0) < now:
                raise ValueError("Token has expired")
            
            # Check if token was issued in the future
            if decoded_token.get('iat', 0) > now + 300:  # 5 minute tolerance
                raise ValueError("Token issued in the future")
            
            # Check auth_time if present
            auth_time = decoded_token.get('auth_time')
            if auth_time and auth_time > now + 300:
                raise ValueError("Authentication time in the future")
            
            return decoded_token
            
        except jwt.ExpiredSignatureError:
            raise ValueError("Token has expired")
        except jwt.InvalidTokenError as e:
            raise ValueError(f"Invalid token: {str(e)}")
        except Exception as e:
            logger.error(f"Token verification error: {str(e)}")
            raise ValueError(f"Token verification failed: {str(e)}")
    
    async def _update_public_keys(self):
        """Update Firebase public keys for token verification"""
        try:
            # Check if keys need updating (cache for 1 hour)
            if (self._keys_last_updated and 
                datetime.utcnow() - self._keys_last_updated < timedelta(hours=1)):
                return
            
            async with httpx.AsyncClient() as client:
                response = await client.get(self.public_keys_url)
                response.raise_for_status()
                
                self._public_keys = response.json()
                self._keys_last_updated = datetime.utcnow()
                
                logger.info("Firebase public keys updated successfully")
                
        except Exception as e:
            logger.error(f"Failed to update Firebase public keys: {str(e)}")
            if not self._public_keys:
                raise ValueError("No public keys available for token verification")

class JWTAuth:
    """JWT token management for internal API authentication"""
    
    def __init__(self):
        self.secret_key = settings.secret_key
        self.algorithm = settings.algorithm
        self.access_token_expire_minutes = settings.access_token_expire_minutes
    
    def create_access_token(self, data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """Create a JWT access token"""
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=self.access_token_expire_minutes)
        
        to_encode.update({"exp": expire, "iat": datetime.utcnow()})
        
        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm=self.algorithm)
        return encoded_jwt
    
    def verify_token(self, token: str) -> Dict[str, Any]:
        """Verify JWT access token"""
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            return payload
        except jwt.ExpiredSignatureError:
            raise ValueError("Token has expired")
        except jwt.InvalidTokenError:
            raise ValueError("Invalid token")

# Global instances
firebase_auth = FirebaseAuth()
jwt_auth = JWTAuth()

# Development mode helpers
class MockAuth:
    """Mock authentication for development/testing"""
    
    @staticmethod
    async def verify_token(token: str) -> Dict[str, Any]:
        """Mock token verification for development"""
        if settings.environment == "development":
            # Return mock user data for development
            return {
                "uid": "dev_user_123",
                "email": "dev@example.com",
                "email_verified": True,
                "name": "Development User",
                "iss": "mock",
                "aud": "mock",
                "exp": datetime.utcnow().timestamp() + 3600,
                "iat": datetime.utcnow().timestamp()
            }
        else:
            raise ValueError("Mock auth only available in development mode")

# Choose auth method based on environment
def get_auth_service():
    """Get appropriate auth service based on environment"""
    if settings.environment == "development" and settings.debug:
        return MockAuth()
    else:
        return firebase_auth

# FastAPI Dependencies  
async def get_current_user():
    """
    Simplified dependency for development - returns mock chef data
    TODO: Implement proper authentication in production
    """
    # Return a simple dict for now to avoid circular imports
    return {
        "id": "mock-chef-id",
        "name": "Mock Chef", 
        "bio": "Mock chef for development",
        "app_name": "Mock App"
    }
