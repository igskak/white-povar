import httpx
import json
from jose import jwt
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import logging

from app.core.settings import settings

logger = logging.getLogger(__name__)

class SupabaseAuth:
    """Supabase Authentication service for token verification"""

    def __init__(self):
        # Extract the Supabase project URL for issuer validation
        self.supabase_url = settings.supabase_url
        # Use dedicated JWT secret if available, otherwise fall back to service key
        # The JWT secret is found in Supabase Dashboard -> Settings -> API -> JWT Secret
        self.jwt_secret = settings.supabase_jwt_secret or settings.supabase_service_key
        logger.info(f"🔐 SupabaseAuth initialized with JWT secret: {'custom' if settings.supabase_jwt_secret else 'service_key'}")
    
    async def verify_token(self, token: str) -> Dict[str, Any]:
        """
        Verify Supabase JWT token and return user claims

        Args:
            token: Supabase JWT token

        Returns:
            Dict containing user claims (sub, email, role, etc.)

        Raises:
            ValueError: If token is invalid
        """
        try:
            # Log token info for debugging (first 20 chars only)
            logger.info(f"🔍 Verifying token: {token[:20]}...")
            logger.info(f"🔑 Using JWT secret: {self.jwt_secret[:10]}..." if self.jwt_secret else "❌ NO JWT SECRET SET!")

            if not self.jwt_secret:
                raise ValueError("JWT secret not configured. Set SUPABASE_JWT_SECRET environment variable.")

            # Decode and verify the token using Supabase JWT secret
            # Supabase uses HS256 algorithm (symmetric key)
            decoded_token = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=['HS256'],
                options={
                    'verify_exp': True,
                    'verify_iat': True,
                    'verify_signature': True
                }
            )

            # Validate token claims
            now = datetime.utcnow().timestamp()

            # Check if token is expired
            if decoded_token.get('exp', 0) < now:
                raise ValueError("Token has expired")

            # Check if token was issued in the future
            if decoded_token.get('iat', 0) > now + 300:  # 5 minute tolerance
                raise ValueError("Token issued in the future")

            # Supabase tokens should have 'sub' (user ID) and 'role'
            if not decoded_token.get('sub'):
                raise ValueError("Token missing user ID (sub)")

            logger.info(f"✅ Token verified successfully for user: {decoded_token.get('sub')}")
            return decoded_token

        except jwt.ExpiredSignatureError:
            logger.error("❌ Token has expired")
            raise ValueError("Token has expired")
        except jwt.JWTClaimsError as e:
            logger.error(f"❌ Invalid token claims: {str(e)}")
            raise ValueError(f"Invalid token claims: {str(e)}")
        except jwt.JWTError as e:
            logger.error(f"❌ JWT Error: {str(e)}")
            raise ValueError(f"Invalid token: {str(e)}")
        except Exception as e:
            logger.error(f"❌ Token verification error: {str(e)}")
            raise ValueError(f"Token verification failed: {str(e)}")


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
supabase_auth = SupabaseAuth()
jwt_auth = JWTAuth()

# Development mode helpers
class MockAuth:
    """Mock authentication for development/testing"""

    @staticmethod
    async def verify_token(token: str) -> Dict[str, Any]:
        """Mock token verification for development"""
        if settings.environment == "development":
            # Return mock user data for development
            # Use 'sub' instead of 'uid' to match Supabase token format
            return {
                "sub": "dev_user_123",
                "email": "dev@example.com",
                "email_verified": True,
                "name": "Development User",
                "role": "authenticated",
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
        return supabase_auth  # Changed from firebase_auth

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
