"""Privacy-preserving analytics contract.

Event payloads intentionally contain no free-form fields.  This prevents a
transcript, email address, ingredient list or store receipt from being added
to analytics by an otherwise harmless client change.
"""
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


AnalyticsEventName = Literal[
    'activation_completed', 'search_completed', 'voice_search_completed',
    'recipe_viewed', 'cooking_completed', 'recipe_saved', 'paywall_viewed',
    'purchase_confirmed',
]


class AnalyticsConsent(BaseModel):
    analytics_consent: bool


class AnalyticsEventInput(BaseModel):
    model_config = ConfigDict(extra='forbid')

    name: AnalyticsEventName
    # A coarse result bucket is enough for funnel aggregation and is not user
    # content.  Event-specific properties are deliberately not accepted.
    outcome: Literal['success', 'empty', 'cancelled', 'failed'] = 'success'
    client_version: str | None = Field(default=None, max_length=40)
