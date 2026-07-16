from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional
import logging

from app.core.settings import settings
from app.core.security import get_auth_service, jwt_auth
from app.services.database import supabase_service
from app.core.tenant import TenantContext, require_tenant_context
from app.schemas.preferences import PreferenceProfile, StoredPreferenceProfile

router = APIRouter()
security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)
logger = logging.getLogger(__name__)

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    chef_id: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str

class User(BaseModel):
    id: str
    email: str
    chef_id: Optional[str] = None


def _chef_id_from_user_result(user_result) -> Optional[str]:
    """Read trusted chef membership without accepting it from JWT user metadata."""
    if not user_result.data:
        return None
    chef_id = user_result.data[0].get("chef_id")
    return str(chef_id) if chef_id else None

async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Verify Supabase JWT token and return user info"""
    token = credentials.credentials
    logger.info("Authentication token received")

    try:
        # Get auth service (Supabase or Mock for development)
        auth_service = get_auth_service()

        # Verify the token
        logger.info("🔍 Verifying token...")
        decoded_token = await auth_service.verify_token(token)
        logger.info(f"✅ Token verified successfully")

        # Extract user information from token
        # Supabase uses 'sub' for user ID, not 'uid'
        user_id = decoded_token.get('sub') or decoded_token.get('user_id', 'unknown')
        email = decoded_token.get('email', 'unknown@example.com')
        logger.info("Token verified for user %s", user_id)

        # Check if user exists in our database, create if not
        logger.info(f"🔍 Checking if user exists in database...")
        user_result = await supabase_service.execute_query(
            'users',
            'select',
            filters={'id': user_id},
            use_service_key=True,
        )

        chef_id = _chef_id_from_user_result(user_result)
        if not user_result.data:
            logger.info(f"➕ User not found, creating new user...")
            # Create new user in our database with default free tier subscription
            user_data = {
                'id': user_id,
                'email': email,
                'subscription_tier': 'free',  # Default to free tier
                'subscription_status': 'active'  # Active free tier
            }
            await supabase_service.execute_query(
                'users', 'insert', data=user_data, use_service_key=True
            )
            logger.info(f"✅ Created new user with free tier: {user_id}")
        else:
            logger.info(f"✅ User found in database: {user_id}")

        logger.info(f"🎉 Authentication successful for user: {user_id}")
        return User(id=user_id, email=email, chef_id=chef_id)

    except ValueError as e:
        logger.warning(f"❌ Token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"❌ Authentication error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_optional_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(optional_security)) -> Optional[User]:
    """Verify Supabase JWT token and return user info, or None if not authenticated"""
    if credentials is None:
        return None

    try:
        token = credentials.credentials
        # Get auth service (Supabase or Mock for development)
        auth_service = get_auth_service()

        # Verify the token
        decoded_token = await auth_service.verify_token(token)

        # Extract user information from token
        # Supabase uses 'sub' for user ID, not 'uid'
        user_id = decoded_token.get('sub') or decoded_token.get('user_id', 'unknown')
        email = decoded_token.get('email', 'unknown@example.com')

        # Check if user exists in our database, create if not
        user_result = await supabase_service.execute_query(
            'users',
            'select',
            filters={'id': user_id},
            use_service_key=True,
        )

        chef_id = _chef_id_from_user_result(user_result)
        if not user_result.data:
            # Create new user in our database with default free tier subscription
            user_data = {
                'id': user_id,
                'email': email,
                'subscription_tier': 'free',  # Default to free tier
                'subscription_status': 'active'  # Active free tier
            }
            await supabase_service.execute_query(
                'users', 'insert', data=user_data, use_service_key=True
            )
            logger.info(f"✅ Created new user with free tier: {user_id}")

        return User(id=user_id, email=email, chef_id=chef_id)

    except Exception as e:
        logger.warning(f"Optional authentication failed: {str(e)}")
        return None

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """Deprecated: use Supabase Auth client-side flow instead."""
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Deprecated endpoint. Use Supabase auth flow from client SDK."
    )

@router.post("/register", response_model=TokenResponse)
async def register(request: RegisterRequest):
    """Deprecated: use Supabase Auth client-side flow instead."""
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Deprecated endpoint. Use Supabase auth flow from client SDK."
    )

@router.get("/me", response_model=User)
async def get_current_user(current_user: User = Depends(verify_firebase_token)):
    """Get current user information"""
    return current_user


@router.get('/me/preferences', response_model=StoredPreferenceProfile)
async def get_preferences(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    profile = await supabase_service.get_preference_profile(current_user.id, tenant.chef_id)
    if not profile:
        return StoredPreferenceProfile(personalization_consent=False)
    return StoredPreferenceProfile(**profile)


@router.put('/me/preferences', response_model=StoredPreferenceProfile)
async def save_preferences(
    preferences: PreferenceProfile,
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    if not preferences.personalization_consent:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail='Explicit personalization consent is required; use DELETE to reset preferences.',
        )
    payload = preferences.model_dump()
    await supabase_service.upsert_preference_profile(current_user.id, tenant.chef_id, payload)
    stored = await supabase_service.get_preference_profile(current_user.id, tenant.chef_id)
    return StoredPreferenceProfile(**(stored or payload))


@router.delete('/me/preferences', status_code=status.HTTP_204_NO_CONTENT)
async def reset_preferences(
    current_user: User = Depends(verify_firebase_token),
    tenant: TenantContext = Depends(require_tenant_context),
):
    await supabase_service.delete_preference_profile(current_user.id, tenant.chef_id)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_current_user(current_user: User = Depends(verify_firebase_token)):
    """Permanently erase the authenticated user's application and auth record.

    All private application tables reference ``users`` with ``ON DELETE
    CASCADE``. Deleting the public record first therefore removes favorites,
    history and entitlements before the Supabase Admin API revokes the identity.
    """
    try:
        await supabase_service.execute_query(
            'users', 'delete', filters={'id': current_user.id}, use_service_key=True
        )
        supabase_service.service_client.auth.admin.delete_user(current_user.id)
    except Exception:
        # Error sinks must not receive provider exception text: it can contain
        # request or account data. The route and exception class are enough for
        # operational triage, matching the observability redaction policy.
        logger.error("User deletion failed for authenticated account")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not delete account",
        )

@router.post("/refresh")
async def refresh_token():
    """Deprecated: use Supabase session refresh in the client SDK."""
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Deprecated endpoint. Refresh Supabase sessions via client SDK."
    )

class UserSyncRequest(BaseModel):
    id: str
    email: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None

@router.post("/sync")
async def sync_user(request: UserSyncRequest, current_user: User = Depends(verify_firebase_token)):
    """Sync user information with backend"""
    try:
        # Update or create user in our database
        user_data = {
            'id': current_user.id,
            'email': current_user.email,
            'display_name': request.display_name,
            'avatar_url': request.avatar_url,
            'updated_at': 'now()'
        }
        
        # Check if user exists
        existing_user = await supabase_service.execute_query(
            'users',
            'select',
            filters={'id': current_user.id},
            use_service_key=True,
        )
        
        if existing_user.data:
            # Update existing user
            await supabase_service.execute_query(
                'users', 'update', 
                filters={'id': current_user.id},
                data=user_data, 
                use_service_key=True
            )
        else:
            # Create new user
            user_data['created_at'] = 'now()'
            user_data['favorites'] = []
            await supabase_service.execute_query(
                'users', 'insert', 
                data=user_data, 
                use_service_key=True
            )
        
        return {"message": "User synced successfully"}
        
    except Exception as e:
        logger.error(f"User sync failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to sync user"
        )
