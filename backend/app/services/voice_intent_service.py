"""Safe local parsing for the first voice-recommendation retrieval step.

This is intentionally not an LLM prompt.  The transcript is treated as data,
not instructions, and only recognised cooking vocabulary can affect filters.
"""
import re
from typing import List, Tuple

from app.schemas.search import VoiceIntent


_TIME = [
    (r'\b(?:до|за)\s*(\d{1,3})\s*(?:хв|хвилин)', 1),
    (r'\b(\d{1,2})\s*год(?:ина|ини|ин)?', 60),
]
_SERVINGS = r'\b(?:на|для)\s*(\d{1,2})\s*(?:осіб|людей|порці(?:ї|й)?)'
_INGREDIENTS = ('томати', 'помідори', 'паста', 'курка', 'курятина', 'риба',
                'лосось', 'яловичина', 'свинина', 'квасоля', 'гриби', 'сир',
                'яйця', 'картопля', 'кабачок', 'рис')
_ALLERGENS = ('горіхи', 'молоко', 'молочне', 'глютен', 'яйця', 'риба', 'соя')


def _unique(values: List[str]) -> List[str]:
    return list(dict.fromkeys(values))


def parse_voice_intent(transcript: str, confirmed_servings: int | None = None) -> Tuple[VoiceIntent, List[str]]:
    text = transcript.lower().strip()
    # Strip control-like phrases from the searchable portion. They can never
    # change tenant, access, or any server policy regardless.
    searchable = re.sub(r'\b(?:ігноруй|ignore|system|prompt|інструкц\w*)\b[^,.!?]*', ' ', text)
    available = [item for item in _INGREDIENTS
                 if re.search(rf'(?<!без\s)\b{re.escape(item[:-1])}\w*', searchable)]
    excluded = [item for item in _INGREDIENTS + _ALLERGENS
                if re.search(rf'\bбез\s+{re.escape(item[:-1])}\w*', searchable)]
    allergens = [item for item in _ALLERGENS
                 if item in excluded or re.search(rf'\bалергі\w*\s+на\s+{re.escape(item)}\b', searchable)]
    max_time = None
    for pattern, multiplier in _TIME:
        match = re.search(pattern, searchable)
        if match:
            max_time = int(match.group(1)) * multiplier
            break
    servings_match = re.search(_SERVINGS, searchable)
    servings = confirmed_servings or (int(servings_match.group(1)) if servings_match else None)
    confirmation = []
    if not servings and re.search(r'\b(?:для сім[’\']ї|на компанію|гостей)\b', searchable):
        confirmation.append('servings')
    dish_type = next((item for item in ('суп', 'салат', 'паста', 'сніданок', 'вечеря', 'десерт')
                      if re.search(rf'\b{item}\w*\b', searchable)), None)
    protein = next((item for item in ('курка', 'курятина', 'риба', 'лосось', 'яловичина', 'свинина', 'квасоля')
                    if re.search(rf'\b{item}\w*\b', searchable)), None)
    diets = [item for item in ('веган', 'вегетаріан', 'безглютенов') if item in searchable]
    occasion = next((item for item in ('сніданок', 'вечеря', 'обід', 'свято') if item in searchable), None)
    lightness = 'light' if re.search(r'\b(?:легк\w*|дієтич\w*)\b', searchable) else (
        'hearty' if re.search(r'\b(?:ситн\w*)\b', searchable) else None)
    terms = [term for term in re.findall(r"[а-щьюяґєіїa-z]{3,}", searchable)
             if term not in {'будь', 'ласка', 'рецепт', 'хочу', 'знайди', 'покажи', 'для', 'без'}]
    return VoiceIntent(
        occasion=occasion, available_ingredients=_unique(available),
        excluded_ingredients=_unique(excluded), dish_type=dish_type,
        protein=protein, lightness=lightness, max_total_time=max_time,
        diets=_unique(diets), allergens=_unique(allergens), servings=servings,
        search_terms=_unique(terms)[:12],
    ), confirmation
