from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional
import logging

from app.core.settings import settings
from app.core.security import get_auth_service, jwt_auth
from app.services.database import supabase_service

router = APIRouter()
security = HTTPBearer()
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

async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Verify Firebase ID token and return user info"""
    token = credentials.credentials

    try:
        # Get auth service (Firebase or Mock for development)
        auth_service = get_auth_service()

        # Verify the token
        decoded_token = await auth_service.verify_token(token)

        # Extract user information from token
        user_id = decoded_token.get('uid') or decoded_token.get('user_id', 'unknown')
        email = decoded_token.get('email', 'unknown@example.com')

        # Check if user exists in our database, create if not
        user_result = await supabase_service.execute_query(
            'users', 'select', filters={'id': user_id}
        )

        if not user_result.data:
            # Create new user in our database
            user_data = {
                'id': user_id,
                'email': email,
                'chef_id': None,
                'favorites': []
            }
            await supabase_service.execute_query(
                'users', 'insert', data=user_data, use_service_key=True
            )
            chef_id = None
        else:
            chef_id = user_result.data[0].get('chef_id')

        return User(id=user_id, email=email, chef_id=chef_id)

    except ValueError as e:
        logger.warning(f"Token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Authentication error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """Login with email and password"""
    # TODO: Implement actual authentication logic
    # For now, return mock response
    if request.email == "test@example.com" and request.password == "password":
        return TokenResponse(
            access_token="mock_access_token",
            user_id="mock_user_id"
        )
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect email or password"
    )

@router.post("/register", response_model=TokenResponse)
async def register(request: RegisterRequest):
    """Register new user"""
    # TODO: Implement actual registration logic
    # For now, return mock response
    return TokenResponse(
        access_token="mock_access_token",
        user_id="new_user_id"
    )

@router.get("/me", response_model=User)
async def get_current_user(current_user: User = Depends(verify_firebase_token)):
    """Get current user information"""
    return current_user

@router.post("/refresh")
async def refresh_token():
    """Refresh access token"""
    # TODO: Implement token refresh logic
    return {"access_token": "new_mock_token", "token_type": "bearer"}
