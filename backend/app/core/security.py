import httpx
from jose import jwt
from typing import Dict, Any, Optional
from datetime import datetime, timedelta, timezone
import logging
import time

from app.core.settings import settings

logger = logging.getLogger(__name__)

class SupabaseAuth:
    """Supabase Authentication service for token verification"""

    _ASYMMETRIC_ALGORITHMS = {"RS256", "ES256"}
    _JWKS_CACHE_SECONDS = 10 * 60

    def __init__(self):
        self.supabase_url = settings.supabase_url.rstrip("/")
        self.issuer = f"{self.supabase_url}/auth/v1"
        self.jwks_url = f"{self.issuer}/.well-known/jwks.json"
        self._jwks: Dict[str, Any] = {"keys": []}
        self._jwks_loaded_at = 0.0
        logger.info("Supabase authentication verifier initialized")

    async def verify_token(self, token: str) -> Dict[str, Any]:
        """Verify a Supabase access token and return trusted claims."""
        try:
            header = jwt.get_unverified_header(token)
            algorithm = header.get("alg")

            if algorithm == "HS256":
                claims = await self._verify_legacy_token(token)
            elif algorithm in self._ASYMMETRIC_ALGORITHMS:
                claims = await self._verify_asymmetric_token(token, header)
            else:
                raise ValueError("Unsupported token signing algorithm")

            self._validate_claims(claims)
            logger.info("Supabase access token verified")
            return claims

        except jwt.ExpiredSignatureError:
            logger.warning("Supabase token has expired")
            raise ValueError("Token has expired")
        except jwt.JWTClaimsError as e:
            logger.warning("Invalid Supabase token claims: %s", e)
            raise ValueError(f"Invalid token claims: {str(e)}")
        except jwt.JWTError as e:
            logger.warning("Invalid Supabase token")
            raise ValueError(f"Invalid token: {str(e)}")
        except ValueError:
            raise
        except Exception as e:
            logger.warning("Supabase token verification failed")
            raise ValueError("Token verification failed") from e

    async def _verify_asymmetric_token(
        self,
        token: str,
        header: Dict[str, Any],
    ) -> Dict[str, Any]:
        key_id = header.get("kid")
        if not key_id:
            raise ValueError("Token is missing a signing key id")

        key = await self._get_signing_key(key_id)
        if key is None:
            key = await self._get_signing_key(key_id, force_refresh=True)
        if key is None:
            raise ValueError("Token signing key is not trusted")

        return jwt.decode(
            token,
            key,
            algorithms=[header["alg"]],
            audience="authenticated",
            issuer=self.issuer,
            options={
                "verify_exp": True,
                "verify_iat": True,
                "verify_signature": True,
                "verify_aud": True,
                "verify_iss": True,
            },
        )

    async def _verify_legacy_token(self, token: str) -> Dict[str, Any]:
        """Validate legacy HS256 tokens through Supabase Auth itself."""
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(
                f"{self.issuer}/user",
                headers={
                    "apikey": settings.supabase_key,
                    "Authorization": f"Bearer {token}",
                },
            )

        if response.status_code != 200:
            raise ValueError("Invalid token")

        user = response.json()
        claims = jwt.get_unverified_claims(token)
        if not user.get("id") or user["id"] != claims.get("sub"):
            raise ValueError("Token subject does not match authenticated user")
        return claims

    async def _get_signing_key(
        self,
        key_id: str,
        *,
        force_refresh: bool = False,
    ) -> Optional[Dict[str, Any]]:
        cache_expired = time.monotonic() - self._jwks_loaded_at >= self._JWKS_CACHE_SECONDS
        if force_refresh or cache_expired or not self._jwks.get("keys"):
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(self.jwks_url)
            if response.status_code != 200:
                raise ValueError("Could not load trusted token signing keys")
            payload = response.json()
            if not isinstance(payload.get("keys"), list):
                raise ValueError("Invalid token signing key response")
            self._jwks = payload
            self._jwks_loaded_at = time.monotonic()

        return next(
            (key for key in self._jwks["keys"] if key.get("kid") == key_id),
            None,
        )

    def _validate_claims(self, claims: Dict[str, Any]) -> None:
        now = datetime.now(timezone.utc).timestamp()
        if claims.get("exp", 0) < now:
            raise ValueError("Token has expired")
        if claims.get("iat", 0) > now + 300:
            raise ValueError("Token issued in the future")
        if claims.get("iss") != self.issuer:
            raise ValueError("Token issuer is not trusted")

        audience = claims.get("aud")
        valid_audience = audience == "authenticated" or (
            isinstance(audience, list) and "authenticated" in audience
        )
        if not valid_audience:
            raise ValueError("Token audience is not trusted")
        if not claims.get("sub"):
            raise ValueError("Token missing user ID (sub)")
        if claims.get("role") != "authenticated":
            raise ValueError("Token role is not authenticated")


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
