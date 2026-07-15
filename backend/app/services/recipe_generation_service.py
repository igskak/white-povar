"""Safe, tenant-aware recipe generation for AI-01.

This service intentionally returns an ephemeral preview.  It never writes a
recipe and never supplies a model with recipe bodies, including premium bodies.
"""
from __future__ import annotations

import asyncio
import json
import logging
from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone
from typing import Awaitable, Callable

from openai import AsyncOpenAI

from app.api.v1.endpoints.auth import User
from app.core.content_access import resolve_recipe_access
from app.core.settings import settings
from app.core.tenant import TenantContext
from app.schemas.ai_generation import GeneratedRecipe, RecipeGenerationRequest
from app.services.database import supabase_service

logger = logging.getLogger(__name__)
StatusCallback = Callable[[str], Awaitable[None]]


class GenerationRejected(ValueError):
    """A user-visible, safe rejection that must not call a model."""


class ApprovedStyleProfile(dict):
    pass


# These profiles are deliberately server-owned.  A request cannot provide a
# persona or claim a creator's style.  Studio approval/configuration belongs to
# later work; until then only this pilot profile is enabled.
APPROVED_STYLE_PROFILES: dict[str, ApprovedStyleProfile] = {
    'ohorodnik-oleksandr': ApprovedStyleProfile(
        name='Огороднік Олександр',
        tone='теплий, практичний, сезонний; без імітації дослівного авторського тексту',
        principles=['домашня українська кухня', 'сезонні овочі', 'чіткі метричні кроки'],
    ),
}


class GenerationBudget:
    """Process-local guard against bursts and runaway token spend.

    It is conservative per process; deployment-wide accounting can be added to
    OBS-01 without retaining prompts or generated drafts.
    """

    def __init__(self) -> None:
        self._requests: dict[tuple[str, str], deque[datetime]] = defaultdict(deque)
        self._daily_tokens: dict[tuple[str, str], tuple[datetime, int]] = {}
        self._lock = asyncio.Lock()

    async def reserve(self, user_id: str, tenant_slug: str, estimated_tokens: int) -> None:
        now = datetime.now(timezone.utc)
        key = (user_id, tenant_slug)
        async with self._lock:
            requests = self._requests[key]
            cutoff = now - timedelta(minutes=1)
            while requests and requests[0] < cutoff:
                requests.popleft()
            if len(requests) >= settings.ai_recipe_generation_requests_per_minute:
                raise GenerationRejected('Забагато запитів. Спробуйте ще раз за хвилину.')
            day, used = self._daily_tokens.get(key, (now.date(), 0))
            if day != now.date():
                used = 0
            if used + estimated_tokens > settings.ai_recipe_generation_daily_token_budget:
                raise GenerationRejected('Денний ліміт AI-генерації вичерпано. Спробуйте завтра.')
            requests.append(now)
            self._daily_tokens[key] = (now.date(), used + estimated_tokens)


class RecipeGenerationService:
    _max_output_tokens = 1100

    def __init__(self) -> None:
        self._client: AsyncOpenAI | None = None
        self.budget = GenerationBudget()

    @property
    def client(self) -> AsyncOpenAI:
        if self._client is None:
            self._client = AsyncOpenAI(api_key=settings.openai_api_key)
        return self._client

    async def generate(
        self, request: RecipeGenerationRequest, user: User, tenant: TenantContext,
        status: StatusCallback,
    ) -> GeneratedRecipe:
        self._validate_safe_request(request)
        profile = APPROVED_STYLE_PROFILES.get(tenant.slug)
        if profile is None:
            raise GenerationRejected('AI-рецепти для цього автора ще не затверджені.')

        await self.budget.reserve(user.id, tenant.slug, self._max_output_tokens)
        await status('Підбираємо безпечний контекст автора…')
        references = await self._allowed_references(request.prompt, user, tenant)
        await status('Створюємо структуру рецепта…')
        try:
            raw = await self._call_model(request, profile, references)
            recipe = GeneratedRecipe.model_validate(raw)
        except GenerationRejected:
            raise
        except Exception as exc:
            logger.warning('AI recipe generation failed tenant=%s: %s', tenant.slug, type(exc).__name__)
            raise GenerationRejected('Не вдалося безпечно створити рецепт. Спробуйте змінити запит.') from exc
        await status('Перевіряємо структуру та обмеження…')
        return recipe

    def _validate_safe_request(self, request: RecipeGenerationRequest) -> None:
        text = request.prompt.casefold()
        unsupported = ('лікуван', 'вилікуй', 'medical diagnosis', 'діагноз', 'отрута', 'poison')
        if any(term in text for term in unsupported):
            raise GenerationRejected('AI не надає медичних порад і не допомагає з небезпечними запитами.')

    async def _allowed_references(
        self, prompt: str, user: User, tenant: TenantContext,
    ) -> list[dict[str, object]]:
        result = await supabase_service.search_catalog_recipes(
            chef_id=tenant.chef_id, query_text=prompt, tags=None, difficulty=None,
            max_total_time=None, is_featured=None, limit=12, offset=0,
        )
        references = []
        for row in result.data or []:
            access = await resolve_recipe_access(row, tenant, user)
            if not access.exists_in_tenant:
                continue
            # Metadata only.  Do not pass ingredients, instructions, nutrition,
            # descriptions, video URLs, or any premium body to the model.
            references.append({
                'title': str(row.get('title', ''))[:120],
                'tags': [str(tag)[:40] for tag in row.get('tags') or []][:6],
                'content_kind': str(row.get('content_kind') or 'recipe'),
            })
        return references[:6]

    async def _call_model(
        self, request: RecipeGenerationRequest, profile: ApprovedStyleProfile,
        references: list[dict[str, object]],
    ) -> dict[str, object]:
        system = (
            'You create an original Ukrainian home-cooking recipe preview. '
            'Return JSON only. Never claim it is published, approved by, or written by a creator. '
            'Do not reproduce source text. Use metric units. Do not provide medical advice. '
            'Respect allergies and dietary restrictions; when certainty is impossible, say so in safety_note.'
        )
        payload = {
            'request': request.prompt,
            'available_ingredients': request.available_ingredients,
            'dietary_restrictions': request.dietary_restrictions,
            'allergens_to_avoid': request.allergens,
            'approved_style_profile': dict(profile),
            'metadata_only_references': references,
            'required_json': GeneratedRecipe.model_json_schema(),
        }
        response = await self.client.chat.completions.create(
            model=settings.ai_recipe_generation_model,
            messages=[{'role': 'system', 'content': system}, {'role': 'user', 'content': json.dumps(payload, ensure_ascii=False)}],
            response_format={'type': 'json_object'},
            max_tokens=self._max_output_tokens,
            temperature=0.5,
        )
        content = response.choices[0].message.content
        if not content:
            raise GenerationRejected('AI не повернув рецепт. Спробуйте ще раз.')
        return json.loads(content)


recipe_generation_service = RecipeGenerationService()
