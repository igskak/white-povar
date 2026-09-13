"""Unit ids to the Ukrainian abbreviations the app shows.

The units table only carries name_en/name_it, so there is no Ukrainian column
to read from; the app ships a single Ukrainian locale, so the abbreviations
are spelled out here rather than served in English. Recipe reads and the
shopping list both render units through this one map.
"""
from typing import Optional

UNIT_NAMES = {
    '00000000-0000-0000-0000-000000000001': 'г',
    '00000000-0000-0000-0000-000000000010': 'мл',
    '00000000-0000-0000-0000-000000000020': 'шт',
    '00000000-0000-0000-0000-000000000031': 'ст. л.',
    '00000000-0000-0000-0000-000000000032': 'ч. л.',
    '00000000-0000-0000-0000-000000000002': 'кг',
    '00000000-0000-0000-0000-000000000011': 'л',
    '00000000-0000-0000-0000-000000000021': 'скл.',
    '00000000-0000-0000-0000-000000000041': 'унц.',
    '00000000-0000-0000-0000-000000000051': 'фунт'
}


def unit_name_from_id(unit_id: Optional[str]) -> str:
    return UNIT_NAMES.get(unit_id, 'од.') if unit_id else 'од.'
