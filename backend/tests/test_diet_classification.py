"""The diet lexicon is the whole filter, so its traps are tested explicitly."""

import pytest

from app.services.diet import (
    allowed_diet_types,
    classify_diet,
    row_diet_type,
    row_matches_diet,
)


def _row(**kwargs):
    row = {'tags': [], 'recipe_ingredients': []}
    row.update(kwargs)
    return row


def _ingredients(*names):
    return [{'display_name': name} for name in names]


@pytest.mark.parametrize('names,expected', [
    (['Куряче філе', 'Сіль'], 'meat'),
    (['курка', 'цибуля'], 'meat'),
    (['Свинина', 'часник'], 'meat'),
    (['Яловичина'], 'meat'),
    (['фарш свинячий'], 'meat'),
    (['Ковбаса', 'хліб'], 'meat'),
    (['Сало'], 'meat'),
    (['Куриное филе'], 'meat'),
    (['Bacon', 'eggs'], 'meat'),
    (['желатин', 'сік'], 'meat'),
])
def test_meat_is_detected(names, expected):
    assert classify_diet([], names) == expected


@pytest.mark.parametrize('names', [
    ['Лосось', 'лимон'],
    ['креветки', 'часник'],
    ['Оселедець'],
    ['філе хека'],
    ['морепродукти'],
])
def test_fish_is_detected_but_not_reported_as_meat(names):
    assert classify_diet([], names) == 'fish'


@pytest.mark.parametrize('names', [
    ['Сир', 'помідор'],
    ['молоко', 'борошно'],
    ['Яйця', 'цукор'],
    ['сметана', 'кріп'],
    ['мед', 'горіхи'],
])
def test_dairy_and_eggs_are_vegetarian(names):
    assert classify_diet([], names) == 'vegetarian'


@pytest.mark.parametrize('names', [
    ['Картопля', 'цибуля', 'олія'],
    ['нут', 'куркума', 'кориця'],
    ['помідори', 'базилік'],
])
def test_plants_only_is_vegan(names):
    assert classify_diet([], names) == 'vegan'


@pytest.mark.parametrize('names', [
    ['Куркума', 'рис'],          # not курка
    ['Курага', 'вівсянка'],      # not курка
    ['Печиво', 'молоко'],        # not печінка (but dairy)
    ['Сирий буряк', 'олія'],     # not сир
    ['Сироп агави', 'вода'],     # not сир
    ['Густа паста', 'вода'],     # not гуска
    ['Chickpeas', 'olive oil'],  # not chicken
    ['Морська сіль', 'вода'],    # not seafood
])
def test_innocent_lookalikes_are_not_animal(names):
    """The traps that make a naive substring match unusable."""
    assert classify_diet([], names) in ('vegan', 'vegetarian')


def test_turmeric_and_dried_apricot_stay_vegan():
    assert classify_diet([], ['Куркума', 'Курага', 'рис']) == 'vegan'


def test_biscuit_with_milk_is_vegetarian_not_meat():
    assert classify_diet([], ['Печиво', 'Молоко']) == 'vegetarian'


def test_apostrophe_spellings_all_match():
    for spelling in ("м'ясо", 'м’ясо', 'мясо', 'мʼясо'):
        assert classify_diet([], [spelling]) == 'meat', spelling


def test_meat_wins_over_dairy_in_the_same_recipe():
    assert classify_diet([], ['Сир', 'Шинка', 'Молоко']) == 'meat'


def test_fish_wins_over_dairy_but_loses_to_meat():
    assert classify_diet([], ['Вершки', 'Лосось']) == 'fish'
    assert classify_diet([], ['Вершки', 'Лосось', 'Бекон']) == 'meat'


def test_no_ingredients_is_unknown_never_vegan():
    """Guessing vegan here would show meat to somebody who excluded it."""
    assert classify_diet([], []) is None
    assert classify_diet(None, None) is None


def test_author_tag_overrides_inference():
    # A chef who declares the dish vegan is trusted over a generic ingredient.
    assert classify_diet(['веганське'], ['начинка']) == 'vegan'
    assert classify_diet(['vegetarian'], ['соус']) == 'vegetarian'


def test_tag_override_applies_without_ingredients():
    assert classify_diet(['вегетаріанське'], []) == 'vegetarian'


def test_tags_add_evidence_when_ingredients_are_generic():
    assert classify_diet(['курка'], ['начинка', 'спеції']) == 'meat'


def test_row_diet_type_prefers_the_stored_column():
    row = _row(diet_type='vegan', recipe_ingredients=_ingredients('Шинка'))
    assert row_diet_type(row) == 'vegan'


def test_row_diet_type_falls_back_to_ingredients_when_column_is_null():
    row = _row(recipe_ingredients=_ingredients('Куряче філе'))
    assert row_diet_type(row) == 'meat'


def test_row_diet_type_ignores_a_junk_column_value():
    row = _row(diet_type='banana', recipe_ingredients=_ingredients('Картопля'))
    assert row_diet_type(row) == 'vegan'


@pytest.mark.parametrize('diet,names,expected', [
    ('no_meat', ['Картопля'], True),
    ('no_meat', ['Сир'], True),
    ('no_meat', ['Курка'], False),
    ('no_meat', ['Лосось'], False),
    ('vegan', ['Сир'], False),
    ('vegan', ['Картопля'], True),
    ('pescatarian', ['Лосось'], True),
    ('pescatarian', ['Курка'], False),
    ('no_fish', ['Курка'], True),
    ('no_fish', ['Лосось'], False),
])
def test_row_matches_diet(diet, names, expected):
    assert row_matches_diet(_row(recipe_ingredients=_ingredients(*names)),
                            diet) is expected


def test_unknown_diet_fails_closed():
    """A row we cannot classify must not satisfy a dietary promise."""
    assert row_matches_diet(_row(), 'no_meat') is False


def test_no_diet_requested_matches_everything():
    assert row_matches_diet(_row(recipe_ingredients=_ingredients('Курка')),
                            None) is True


def test_allowed_diet_types():
    assert allowed_diet_types('no_meat') == ['vegetarian', 'vegan']
    assert allowed_diet_types('vegan') == ['vegan']
    assert allowed_diet_types(None) is None
    assert allowed_diet_types('nonsense') is None


def test_composed_sauce_names_do_not_hide_their_meat():
    """Found in production: a lasagne whose only meat is inside its sauce.

    "Соус болоньєзе" carries no other animal word, so a lasagne built on it
    read as vegetarian and would have appeared under "Без м'яса".
    """
    assert classify_diet([], ['листи для лазаньї', 'соус болоньєзе',
                              'сир пармезан']) == 'meat'
    assert classify_diet([], ['bolognese sauce', 'pasta']) == 'meat'


def test_bolognese_stem_does_not_swallow_unrelated_words():
    assert classify_diet([], ['болгарський перець', 'олія']) == 'vegan'
