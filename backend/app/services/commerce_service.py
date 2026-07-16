"""Server-side RevenueCat webhook contract for COM-02.

RevenueCat is deliberately only a store-event verifier.  The database RPC is
the authority that records an event and changes an entitlement.
"""
from __future__ import annotations

import hmac
from typing import Any, Dict

from fastapi import HTTPException, status

from app.core.settings import settings
from app.services.database import supabase_service


def demo_purchase_enabled_for(email: str) -> bool:
    """Fail closed for unknown modes and never reveal the allowlist."""
    return (
        settings.normalized_commerce_mode == 'demo'
        and bool(email)
        and email.casefold() in settings.demo_commerce_allowed_email_set
    )


def verify_revenuecat_authorization(value: str | None) -> None:
    expected = settings.revenuecat_webhook_authorization
    if not expected:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                            detail='Mobile billing webhook is not configured')
    if not value or not hmac.compare_digest(value, expected):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail='Invalid billing webhook authorization')


def revenuecat_event(payload: Dict[str, Any]) -> Dict[str, Any]:
    event = payload.get('event')
    if not isinstance(event, dict):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail='RevenueCat event payload is required')
    required = ('id', 'type', 'app_user_id', 'product_id')
    if any(not event.get(key) for key in required):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail='RevenueCat event is missing a required identifier')
    return event


async def process_revenuecat_webhook(payload: Dict[str, Any]) -> Dict[str, Any]:
    # The RPC owns duplicate detection, mapping, status transitions and the
    # occurred-at ordering check.  A client purchase result is never accepted.
    return await supabase_service.process_revenuecat_event(revenuecat_event(payload))
