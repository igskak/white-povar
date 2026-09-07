"""Diet classification for recipes: one lexicon, applied once at write time.

A "без м'яса" filter is an *exclusion*, and exclusions are expensive and
fragile to evaluate per query: the only honest signal lives in the ingredient
rows, so a query-time answer means scanning ingredients for every candidate and
post-filtering a page the database already sized. Instead each recipe carries a
single derived `diet_type`, computed here when the recipe is written, and
discovery filters it with an ordinary indexed predicate.

The lexicon therefore exists exactly once, in this module. `classify_diet` is
used by ingestion, by the one-off backfill, and — for rows written before the
column existed — by the read-time resolver used by the discovery endpoints.

Matching is token-based, never a raw substring search over the whole name:
"куркума" must not read as "курка" and "печиво" must not read as "печінка".
Every stem with a plausible innocent neighbour has that neighbour listed in
`NEVER_ANIMAL_TOKENS`, which is consulted before any stem.
"""

from __future__ import annotations

import re
from typing import Any, Dict, Iterable, List, Optional, Sequence

# Ordered from most to least restrictive. `meat` also covers poultry and any
# land-animal derivative; `fish` covers fish and seafood.
DIET_TYPES = ('meat', 'fish', 'vegetarian', 'vegan')

# What a client may ask for, and which stored values satisfy it. A dietary
# filter is a promise, so each answer set holds only diets strictly compatible
# with the request.
DIET_FILTERS: Dict[str, tuple] = {
    'no_meat': ('vegetarian', 'vegan'),
    'no_fish': ('meat', 'vegetarian', 'vegan'),
    'vegetarian': ('vegetarian', 'vegan'),
    'vegan': ('vegan',),
    'pescatarian': ('fish', 'vegetarian', 'vegan'),
}

# Apostrophes are orthographic noise here — "м'ясо", "м’ясо" and "мясо" are the
# same word — so they are removed before matching and every stem below is
# written without one.
_APOSTROPHES = str.maketrans({c: '' for c in "'’ʼ`´"})
_TOKEN_RE = re.compile(r"[^\W\d_]+", re.UNICODE)


def _normalize(value: str) -> str:
    return str(value).lower().translate(_APOSTROPHES)


def _tokens(value: str) -> List[str]:
    return _TOKEN_RE.findall(_normalize(value))


# Tokens that a stem below would otherwise catch. Consulted first and
# unconditionally, so adding a stem can never silently reclassify a plant.
NEVER_ANIMAL_TOKENS = frozenset({
    # куркума / курага vs курка
    'куркума', 'куркуми', 'куркумою', 'курага', 'кураги', 'курагу',
    # печиво / печенье vs печінка
    'печиво', 'печива', 'печенье', 'печенья', 'печений', 'печена', 'печені',
    'печене', 'печеная', 'печеные', 'печених',
    # сирий (raw) / сироп / сировина vs сир (cheese)
    'сирий', 'сира', 'сирі', 'сире', 'сирою', 'сирых', 'сырой', 'сырые',
    'сироп', 'сиропу', 'сиропом', 'сировина', 'сировини',
    # густий vs гуска
    'густий', 'густа', 'густе', 'густі', 'густой', 'густая',
    # chickpea vs chicken
    'chickpea', 'chickpeas',
    # butterhead lettuce vs butter
    'butterhead',
    # молочай (a plant) vs молоко
    'молочай',
})

# Land animals and everything rendered from them.
MEAT_STEMS = (
    'мяс',
    'свинин', 'свиняч', 'свинн', 'pork', 'бекон', 'bacon',
    'шинк', 'ham', 'прошут', 'prosciut', 'хамон', 'jamon',
    'панчет', 'pancet', 'чорізо', 'чоризо', 'choriz',
    'салямі', 'салями', 'salami', 'пепперон', 'pepperon',
    'яловичин', 'говядин', 'говяж', 'beef', 'стейк', 'steak',
    'телятин', 'теляч', 'veal',
    'баранин', 'баранч', 'ягнят', 'ягня', 'lamb', 'mutton',
    'курк', 'куряч', 'куриц', 'курин', 'chicken', 'poultry', 'птиц', 'птах',
    'індичк', 'індич', 'индейк', 'индюш', 'turkey',
    'качк', 'качин', 'утк', 'утин', 'duck',
    'гуск', 'гусин', 'гуся', 'goose',
    'кролик', 'кроляч', 'rabbit',
    'фарш', 'mince', 'ковбас', 'сосиск', 'сардельк', 'sausage',
    # Composed names that hide their meat: a lasagne listing "соус болоньєзе"
    # as one ingredient has no other animal word in its list.
    'болонь', 'bolognes',
    'сало', 'смалець', 'шпик', 'lard',
    'печінк', 'печень', 'ліверн', 'liver',
    'желатин', 'gelatin',
    'нагетс', 'nugget',
)

# Fish and seafood.
MEAT_TOKENS = frozenset()
FISH_STEMS = (
    'риб', 'рыб', 'fish', 'seafood', 'морепродукт',
    'лосос', 'salmon', 'сьомг', 'семг',
    'тунц', 'тунец', 'tuna', 'форел', 'trout',
    'оселедц', 'оселедець', 'оселедк', 'селедк', 'herring',
    'сардин', 'sardine', 'анчоус', 'anchov', 'тріск', 'треск', 'cod',
    'скумбр', 'mackerel', 'судак', 'карп', 'carp', 'щук',
    'креветк', 'shrimp', 'prawn', 'краб', 'crab',
    'кальмар', 'squid', 'calamar', 'мідії', 'мідій', 'мидии', 'mussel',
    'устриц', 'oyster', 'гребінц', 'scallop', 'омар', 'lobster',
    'ікр', 'икр', 'caviar',
)
FISH_TOKENS = frozenset({'хек', 'хека', 'хеку', 'хеком'})

# Dairy, eggs and honey: these separate vegetarian from vegan.
ANIMAL_PRODUCT_STEMS = (
    'молок', 'молоч', 'milk', 'вершк', 'сливк', 'cream',
    'сметан', 'йогурт', 'yogurt', 'yoghurt', 'кефір', 'кефир', 'ряжанк',
    'сир', 'сыр', 'cheese', 'творог', 'кисломолочн',
    'бринз', 'моцарел', 'mozzarel', 'пармезан', 'parmesan', 'parmigian',
    'маскарпоне', 'mascarpone', 'фета', 'feta', 'рікот', 'ricotta',
    'яйц', 'яєц', 'яєчн', 'яич', 'egg',
    'мед', 'мёд', 'honey', 'butter',
)
ANIMAL_PRODUCT_TOKENS = frozenset()

# Author-declared diet wins over inference: a chef who tagged a dish
# "вегетаріанське" knows something the ingredient list may not spell out.
# Keys are matched as prefixes of a normalized (apostrophe-free) tag.
TAG_OVERRIDES = (
    ('веганськ', 'vegan'), ('веганское', 'vegan'), ('веган', 'vegan'),
    ('vegan', 'vegan'), ('постн', 'vegan'), ('пісн', 'vegan'),
    ('vegetarian', 'vegetarian'), ('вегетаріан', 'vegetarian'),
    ('вегетариан', 'vegetarian'), ('вегетар', 'vegetarian'),
    ('безмясн', 'vegetarian'), ('без мяса', 'vegetarian'),
    ('pescatarian', 'fish'), ('пескетар', 'fish'),
    ('meat', 'meat'), ('мясо', 'meat'), ('мясн', 'meat'),
)


def _hits(tokens: Sequence[str], stems: Sequence[str],
          exact: frozenset = frozenset()) -> bool:
    for token in tokens:
        if token in NEVER_ANIMAL_TOKENS:
            continue
        if token in exact:
            return True
        if any(token.startswith(stem) for stem in stems):
            return True
    return False


def _tag_override(tags: Optional[Iterable[str]]) -> Optional[str]:
    for tag in tags or ():
        normalized = _normalize(tag).strip()
        if not normalized:
            continue
        for prefix, diet in TAG_OVERRIDES:
            if normalized.startswith(prefix):
                return diet
    return None


def classify_diet(
    tags: Optional[Iterable[str]] = None,
    ingredient_names: Optional[Iterable[str]] = None,
) -> Optional[str]:
    """Return one of `DIET_TYPES`, or None when the recipe cannot be judged.

    None is deliberate and load-bearing: a recipe with no ingredient rows — a
    technique, a video, a Studio item saved before its ingredients — tells us
    nothing, and guessing `vegan` there would put meat in front of somebody who
    asked not to see it.
    """
    override = _tag_override(tags)
    if override:
        return override

    names = [name for name in (ingredient_names or ()) if str(name).strip()]
    if not names:
        return None

    tokens: List[str] = []
    for name in names:
        tokens.extend(_tokens(name))
    # Tags are weaker evidence than ingredients but still informative for
    # dishes whose ingredient names are generic ("начинка", "соус").
    for tag in tags or ():
        tokens.extend(_tokens(tag))

    if _hits(tokens, MEAT_STEMS, MEAT_TOKENS):
        return 'meat'
    if _hits(tokens, FISH_STEMS, FISH_TOKENS):
        return 'fish'
    if _hits(tokens, ANIMAL_PRODUCT_STEMS, ANIMAL_PRODUCT_TOKENS):
        return 'vegetarian'
    return 'vegan'


def ingredient_names_from_row(row: Dict[str, Any]) -> List[str]:
    """Pull ingredient display names out of an embedded PostgREST row."""
    names = []
    for ingredient in row.get('recipe_ingredients') or ():
        if not isinstance(ingredient, dict):
            continue
        name = ingredient.get('display_name') or ingredient.get('name')
        if name:
            names.append(str(name))
    return names


def row_diet_type(row: Dict[str, Any]) -> Optional[str]:
    """The stored diet, falling back to classifying the row's ingredients.

    Rows written before the backfill — and Studio content saved without
    ingredients — have a NULL column. Resolving them here keeps the filter
    correct in every state of the rollout, and costs nothing once the column is
    populated because the stored value short-circuits it.
    """
    stored = row.get('diet_type')
    if stored in DIET_TYPES:
        return stored
    return classify_diet(row.get('tags') or (), ingredient_names_from_row(row))


def row_matches_diet(row: Dict[str, Any], diet: Optional[str]) -> bool:
    """Whether a row satisfies a client-requested diet filter.

    An unknown diet (None) never satisfies a filter: a dietary promise must
    fail closed.
    """
    if not diet:
        return True
    allowed = DIET_FILTERS.get(diet)
    if not allowed:
        return True
    return row_diet_type(row) in allowed


def allowed_diet_types(diet: Optional[str]) -> Optional[List[str]]:
    """Stored `diet_type` values that satisfy `diet`, or None for no filter."""
    if not diet:
        return None
    allowed = DIET_FILTERS.get(diet)
    return list(allowed) if allowed else None
