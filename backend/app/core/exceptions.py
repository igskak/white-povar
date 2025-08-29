"""
Standardized exception handling for the backend API
"""

from typing import Optional, Dict, Any
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)


class BaseAPIException(HTTPException):
    """Base exception class for API errors with consistent structure"""
    
    def __init__(
        self,
        status_code: int,
        detail: str,
        error_code: Optional[str] = None,
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(status_code=status_code, detail=detail, headers=headers)
        self.error_code = error_code


class ValidationException(BaseAPIException):
    """Exception for validation errors (400)"""
    
    def __init__(
        self,
        detail: str = "Validation error",
        error_code: str = "VALIDATION_ERROR",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class AuthenticationException(BaseAPIException):
    """Exception for authentication errors (401)"""
    
    def __init__(
        self,
        detail: str = "Authentication required",
        error_code: str = "AUTHENTICATION_REQUIRED",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            error_code=error_code,
            headers=headers or {"WWW-Authenticate": "Bearer"},
        )


class AuthorizationException(BaseAPIException):
    """Exception for authorization errors (403)"""
    
    def __init__(
        self,
        detail: str = "Access denied",
        error_code: str = "ACCESS_DENIED",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class NotFoundException(BaseAPIException):
    """Exception for resource not found errors (404)"""
    
    def __init__(
        self,
        detail: str = "Resource not found",
        error_code: str = "NOT_FOUND",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class ConflictException(BaseAPIException):
    """Exception for conflict errors (409)"""
    
    def __init__(
        self,
        detail: str = "Resource conflict",
        error_code: str = "CONFLICT",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class BusinessLogicException(BaseAPIException):
    """Exception for business logic errors (422)"""
    
    def __init__(
        self,
        detail: str = "Business logic error",
        error_code: str = "BUSINESS_LOGIC_ERROR",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class RateLimitException(BaseAPIException):
    """Exception for rate limiting errors (429)"""
    
    def __init__(
        self,
        detail: str = "Too many requests",
        error_code: str = "RATE_LIMITED",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class InternalServerException(BaseAPIException):
    """Exception for internal server errors (500)"""
    
    def __init__(
        self,
        detail: str = "Internal server error",
        error_code: str = "INTERNAL_ERROR",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


class ServiceUnavailableException(BaseAPIException):
    """Exception for service unavailable errors (503)"""
    
    def __init__(
        self,
        detail: str = "Service temporarily unavailable",
        error_code: str = "SERVICE_UNAVAILABLE",
        headers: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=detail,
            error_code=error_code,
            headers=headers,
        )


# Database-specific exceptions
class DatabaseException(InternalServerException):
    """Exception for database-related errors"""
    
    def __init__(
        self,
        detail: str = "Database error occurred",
        error_code: str = "DATABASE_ERROR",
        original_error: Optional[Exception] = None,
    ):
        super().__init__(detail=detail, error_code=error_code)
        self.original_error = original_error
        
        # Log the original error for debugging
        if original_error:
            logger.error(f"Database error: {original_error}", exc_info=True)


class RecipeNotFoundException(NotFoundException):
    """Exception for recipe not found errors"""
    
    def __init__(self, recipe_id: str):
        super().__init__(
            detail=f"Recipe with ID '{recipe_id}' not found",
            error_code="RECIPE_NOT_FOUND",
        )


class ChefNotFoundException(NotFoundException):
    """Exception for chef not found errors"""
    
    def __init__(self, chef_id: str):
        super().__init__(
            detail=f"Chef with ID '{chef_id}' not found",
            error_code="CHEF_NOT_FOUND",
        )


class InvalidRecipeDataException(ValidationException):
    """Exception for invalid recipe data"""
    
    def __init__(self, detail: str = "Invalid recipe data provided"):
        super().__init__(
            detail=detail,
            error_code="INVALID_RECIPE_DATA",
        )


class SearchQueryException(ValidationException):
    """Exception for invalid search queries"""
    
    def __init__(self, detail: str = "Invalid search query"):
        super().__init__(
            detail=detail,
            error_code="INVALID_SEARCH_QUERY",
        )


# Utility functions for error handling
def handle_database_error(error: Exception, operation: str = "database operation") -> DatabaseException:
    """Convert database errors to standardized exceptions"""
    logger.error(f"Database error during {operation}: {error}", exc_info=True)
    
    error_str = str(error).lower()
    
    if "connection" in error_str or "timeout" in error_str:
        return DatabaseException(
            detail="Database connection error. Please try again later.",
            error_code="DATABASE_CONNECTION_ERROR",
            original_error=error,
        )
    
    if "constraint" in error_str or "unique" in error_str:
        return ConflictException(
            detail="Data conflict occurred. The resource may already exist.",
            error_code="DATA_CONFLICT",
        )
    
    if "not found" in error_str or "does not exist" in error_str:
        return NotFoundException(
            detail="Requested resource not found in database.",
            error_code="RESOURCE_NOT_FOUND",
        )
    
    return DatabaseException(
        detail="Database operation failed. Please try again later.",
        original_error=error,
    )


def handle_validation_error(error: Exception, field: Optional[str] = None) -> ValidationException:
    """Convert validation errors to standardized exceptions"""
    detail = str(error)
    
    if field:
        detail = f"Validation error for field '{field}': {detail}"
    
    return ValidationException(detail=detail)
