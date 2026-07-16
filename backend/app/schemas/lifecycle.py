from datetime import time
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


class NotificationPreferences(BaseModel):
    """Tenant-scoped choices. Marketing never defaults to enabled."""

    marketing_consent: bool = False
    new_content: bool = False
    saved_recipe_reminders: bool = False
    cooking_reminders: bool = False
    timer_alerts: bool = True
    quiet_hours_start: Optional[time] = None
    quiet_hours_end: Optional[time] = None
    timezone: str = Field(default='Europe/Prague', min_length=1, max_length=64)

    @field_validator('timezone')
    @classmethod
    def timezone_must_be_an_identifier(cls, value: str) -> str:
        if '/' not in value or value.strip() != value:
            raise ValueError('Use an IANA timezone identifier')
        return value


class PushDeviceRegistration(BaseModel):
    token: str = Field(min_length=16, max_length=4096)
    platform: Literal['ios', 'android', 'web']


class LifecycleDeepLink(BaseModel):
    """Validated payload shape for a worker; it never accepts arbitrary URLs."""

    kind: Literal['recipe', 'collection', 'purchase']
    resource_id: Optional[str] = Field(default=None, max_length=128)

    def path(self) -> str:
        if self.kind == 'purchase':
            return '/offers/subscription'
        prefix = '/recipes' if self.kind == 'recipe' else '/collections'
        return f'{prefix}/{self.resource_id}'
