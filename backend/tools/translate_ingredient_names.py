#!/usr/bin/env python3
"""
Translate stored ingredient names and preparation notes to Ukrainian.

Background: the ingestion pipeline used to force every recipe into English
before storing it. `translate_existing_recipes.py` back-filled the narrative
(title / description / instructions) but deliberately skipped ingredients, so
recipes read in Ukrainian while their ingredient list stayed English.

That caution no longer applies. Ingredients are linked to the English
`base_ingredients` catalogue by `base_ingredient_id`, a foreign key — not by
matching `display_name` text — so renaming the display name leaves the linkage
intact. The English catalogue keeps serving the ingestion matcher, which works
on incoming text rather than on what is already stored.

The translations are a fixed table rather than an AI call: this is a closed set
of culinary terms where a wrong word ("кмин" vs "кориця") is worse than no
translation, and a table is reviewable and reproducible. Anything not in the
table is reported and left untouched rather than guessed at.

Safety model, matching translate_existing_recipes.py:
- Dry-run by default. Nothing is written unless you pass --apply.
- Rows already in Cyrillic are skipped, so re-running is safe.
- In --apply mode a full JSON backup of every original row it is about to
  change is written BEFORE any update.

Usage:
  # See what would change, and what has no translation yet (no writes):
  python backend/tools/translate_ingredient_names.py
  # Apply for real (writes to the database, after taking a backup):
  python backend/tools/translate_ingredient_names.py --apply

Credentials come from CLI flags or, if omitted, the environment / .env:
  SUPABASE_URL, SUPABASE_SERVICE_KEY
"""
import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:  # python-dotenv is optional; fall back to the real environment.
    def load_dotenv(*_args, **_kwargs):
        return False

from supabase import create_client

PAGE_SIZE = 500
CYRILLIC = re.compile(r'[Ѐ-ӿ]')

NAMES = {
    'apple cider vinegar': 'яблучний оцет',
    'apricots': 'абрикоси',
    'arugula': 'рукола',
    'avocado': 'авокадо',
    'bacon': 'бекон',
    'baking powder': 'розпушувач',
    'bananas': 'банани',
    'bay leaves': 'лаврове листя',
    'beef liver': 'яловича печінка',
    'beetroot': 'буряк',
    'bell pepper': 'солодкий перець',
    'berries': 'ягоди',
    'berry jam': 'ягідний джем',
    'black pepper': 'чорний перець',
    'bolognese sauce': 'соус болоньєзе',
    'brussels sprouts': 'брюссельська капуста',
    'buckwheat popcorn': 'гречаний попкорн',
    'butter': 'вершкове масло',
    'béchamel sauce': 'соус бешамель',
    'canned tomatoes': 'консервовані томати',
    'carrot': 'морква',
    'carrots': 'морква',
    'cauliflower': 'цвітна капуста',
    'celery stalk': 'стебло селери',
    'cherry wood chips': 'вишнева тріска',
    'chicken eggs': 'курячі яйця',
    'chives': 'шніт-цибуля',
    'cilantro': 'кінза',
    'cinnamon': 'кориця',
    'condensed milk': 'згущене молоко',
    'cooking oil': 'олія для смаження',
    'coriander': 'коріандр',
    'cornstarch': 'кукурудзяний крохмаль',
    'cream': 'вершки',
    'cucumber': 'огірок',
    'cumin': 'кмин',
    'dill': 'кріп',
    'dried thyme': 'сушений чебрець',
    'dry red wine': 'сухе червоне вино',
    'dry white wine': 'сухе біле вино',
    'egg': 'яйце',
    'eggs': 'яйця',
    'fermented beetroot': 'квашений буряк',
    'feta cheese': 'сир фета',
    'flour': 'борошно',
    'fresh cilantro': 'свіжа кінза',
    'fresh herbs (parsley, dill, basil)': 'свіжа зелень (петрушка, кріп, базилік)',
    'garlic': 'часник',
    'ginger': 'імбир',
    'green onion': 'зелена цибуля',
    'ground beef': 'яловичий фарш',
    'hazelnuts': 'фундук',
    'heavy cream': 'жирні вершки',
    'honey': 'мед',
    'kefir or unsweetened yogurt': 'кефір або несолодкий йогурт',
    'lasagna sheets': 'листи для лазаньї',
    'lavash': 'лаваш',
    'lemon juice': 'лимонний сік',
    'lemon juice or apple cider vinegar': 'лимонний сік або яблучний оцет',
    'lemon zest': 'цедра лимона',
    'lime juice': 'сік лайма',
    'mango': 'манго',
    'mayonnaise': 'майонез',
    'milk': 'молоко',
    'mozzarella cheese': 'сир моцарела',
    'oats': 'вівсяні пластівці',
    'oil': 'олія',
    'olive oil': 'оливкова олія',
    'onion': 'цибуля',
    'onions': 'цибуля',
    'orange': 'апельсин',
    'oregano': 'орегано',
    'oyster sauce': 'устричний соус',
    'paprika': 'паприка',
    'parmesan cheese': 'сир пармезан',
    'parsley': 'петрушка',
    'philadelphia cream cheese': 'вершковий сир Філадельфія',
    'pickled onions': 'маринована цибуля',
    'pickled radish': 'маринована редька',
    'pickles': 'солоні огірки',
    'pork neck': 'свиняча шия',
    'potatoes': 'картопля',
    'powdered sugar': 'цукрова пудра',
    'red onion': 'червона цибуля',
    'rice paper': 'рисовий папір',
    'roasted buckwheat groats': 'смажена гречка',
    'salad mix': 'мікс салатів',
    'salt': 'сіль',
    'salted water': 'підсолена вода',
    'sesame oil': 'кунжутна олія',
    'smoked salmon': 'копчений лосось',
    'sour cream': 'сметана',
    'soy sauce': 'соєвий соус',
    'sriracha': 'соус шрірача',
    'sugar': 'цукор',
    'sunflower seeds': 'насіння соняшнику',
    'toasted nuts': 'підсмажені горіхи',
    'tomato': 'помідор',
    'tomato paste': 'томатна паста',
    'tomatoes': 'помідори',
    'tuna': 'тунець',
    'vegetable oil': 'олія',
    'wasabi': 'васабі',
    'water': 'вода',
    'yogurt': 'йогурт',
}

NOTES = {
    '1.5% fat': '1,5% жирності',
    '1.5% fat, warmed': '1,5% жирності, підігріте',
    '10% fat': '10% жирності',
    '15-20% fat content': 'жирність 15–20%',
    'adjust to taste': 'за смаком',
    'all-purpose': 'універсальне',
    'average of 80-100g': 'у середньому 80–100 г',
    'baked or thawed': 'печений або розморожений',
    'chicken': 'куряче',
    'chopped': 'нарізаний',
    'chopped, for garnish': 'нарізаний, для подачі',
    'chopped, for garnish, fresh': 'свіжий, нарізаний, для подачі',
    'chopped, in juice': 'нарізані, у власному соку',
    'clove, minced': 'зубчик, подрібнений',
    'cloves, sliced': 'зубчики, нарізані',
    'cut into pieces of at least 50g': 'нарізати шматками щонайменше 50 г',
    'cut into squares or pieces': 'нарізати квадратами або шматками',
    'diced': 'кубиками',
    'diced, not overly ripe': 'кубиками, не перестиглий',
    'dried': 'сушений',
    'extra virgin': 'першого віджиму',
    'finely chopped': 'дрібно нарізаний',
    'finely ground': 'дрібно змелені',
    'for boiling': 'для варіння',
    'for béchamel sauce': 'для соусу бешамель',
    'for drizzling': 'для збризкування',
    'for frying': 'для смаження',
    'for frying, at 180°C': 'для смаження, за 180 °C',
    'for garnish': 'для подачі',
    'for garnish, fresh': 'свіжий, для подачі',
    'for garnish, optional': 'для подачі, за бажанням',
    'for greasing': 'для змащування',
    'for homemade chips': 'для домашніх чипсів',
    'for sauce': 'для соусу',
    'for sautéing': 'для пасерування',
    'for serving': 'для подачі',
    'for smoking': 'для копчення',
    'for soaking': 'для замочування',
    'for stuffing': 'для начинки',
    'for stuffing, large': 'для начинки, великий',
    'fresh': 'свіжий',
    'fresh or dried': 'свіжий або сушений',
    'fresh, chopped': 'свіжий, нарізаний',
    'fresh, chopped for garnish': 'свіжий, нарізаний для подачі',
    'fresh, diced': 'свіжий, кубиками',
    'fresh, for garnish': 'свіжий, для подачі',
    'freshly squeezed': 'свіжовичавлений',
    'from one lime': 'з одного лайма',
    'grated': 'натертий',
    'grated, optional': 'натертий, за бажанням',
    'ground': 'мелений',
    'halved': 'розрізані навпіл',
    'high starch content, peeled': 'крохмалистий сорт, очищена',
    'high-quality, cold, cubed': 'якісне, холодне, кубиками',
    'large': 'великий',
    'lean, from the hind leg, ground': 'пісний, із задньої ноги, мелений',
    'lightly salted': 'слабосолоний',
    'medium, diced': 'середній, кубиками',
    'minced': 'подрібнений',
    'optional': 'за бажанням',
    'or fresh beetroot juice with lemon juice or dry white wine':
        'або свіжий буряковий сік із лимонним соком чи сухим білим вином',
    'or lemon juice': 'або лимонний сік',
    'or potato starch': 'або картопляний крохмаль',
    'peeled': 'очищена',
    'peeled and cut into even pieces': 'очищена, нарізана рівними шматками',
    'peeled, starchy variety': 'очищена, крохмалистий сорт',
    'pinch': 'дрібка',
    'red, diced': 'червона, кубиками',
    'roasted': 'смажений',
    'roasted, diced': 'смажений, кубиками',
    'sliced': 'нарізаний',
    'sliced into half rings': 'нарізана півкільцями',
    'sliced into pieces 1-1.5 cm thick': 'нарізана шматками завтовшки 1–1,5 см',
    'sliced, for serving': 'нарізаний, для подачі',
    'small, finely chopped': 'дрібний, дрібно нарізаний',
    'smoked or sweet': 'копчена або солодка',
    'to balance acidity': 'щоб збалансувати кислотність',
    'to taste': 'за смаком',
    'toasted': 'підсмажений',
    'toasted, can substitute with almonds, cashews, or pistachios':
        "підсмажений, можна замінити мигдалем, кеш'ю або фісташками",
    'toasted, optional': 'підсмажений, за бажанням',
    'unsalted': 'незасолене',
    'warm': 'тепле',
    'warm, 15% fat': 'теплі, 15% жирності',
    'zest and juice (~80g)': 'цедра і сік (~80 г)',
}


# Lookups are case-insensitive, so fold the keys once rather than trusting every
# entry above to already be lower case ("180°C" is easy to get wrong by hand).
NAMES = {key.lower(): value for key, value in NAMES.items()}
NOTES = {key.lower(): value for key, value in NOTES.items()}


def get_arg_or_env(value, env_name):
    return value or os.getenv(env_name)


def translate(value, table):
    """Return the Ukrainian form, or None when the value needs no change."""
    text = (value or '').strip()
    if not text or CYRILLIC.search(text):
        return None
    return table.get(text.lower())


def fetch_all(client):
    rows, offset = [], 0
    while True:
        page = (client.table('recipe_ingredients')
                .select('id,recipe_id,display_name,preparation_notes')
                .order('id')
                .range(offset, offset + PAGE_SIZE - 1)
                .execute()).data or []
        rows.extend(page)
        if len(page) < PAGE_SIZE:
            return rows
        offset += PAGE_SIZE


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--apply', action='store_true',
                        help='write the translations (default: dry run)')
    parser.add_argument('--supabase-url')
    parser.add_argument('--supabase-key')
    parser.add_argument('--backup-dir', default='backend/tools/backups')
    args = parser.parse_args()

    load_dotenv(Path(__file__).resolve().parents[1] / '.env')
    url = get_arg_or_env(args.supabase_url, 'SUPABASE_URL')
    key = get_arg_or_env(args.supabase_key, 'SUPABASE_SERVICE_KEY')
    if not url or not key:
        sys.exit('SUPABASE_URL and SUPABASE_SERVICE_KEY are required.')

    client = create_client(url, key)
    rows = fetch_all(client)

    planned, untranslated = [], set()
    for row in rows:
        update = {}
        for column, table in (('display_name', NAMES), ('preparation_notes', NOTES)):
            original = (row.get(column) or '').strip()
            translated = translate(original, table)
            if translated:
                update[column] = translated
            elif original and not CYRILLIC.search(original):
                untranslated.add(f'{column}: {original}')
        if update:
            planned.append((row, update))

    print(f'ingredient rows: {len(rows)}')
    print(f'rows to update:  {len(planned)}')
    for row, update in planned:
        before = ' / '.join(filter(None, [row.get('display_name'), row.get('preparation_notes')]))
        after = ' / '.join(filter(None, [update.get('display_name', row.get('display_name')),
                                         update.get('preparation_notes', row.get('preparation_notes'))]))
        print(f'  {before}  ->  {after}')

    if untranslated:
        print(f'\nno translation in the table ({len(untranslated)}) — left unchanged:')
        for item in sorted(untranslated):
            print(f'  {item}')

    if not args.apply:
        print('\nDry run. Re-run with --apply to write these changes.')
        return

    if not planned:
        print('\nNothing to write.')
        return

    backup_dir = Path(args.backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = backup_dir / f'recipe_ingredients_{stamp}.json'
    backup.write_text(json.dumps([row for row, _ in planned], ensure_ascii=False, indent=2),
                      encoding='utf-8')
    print(f'\nbackup written: {backup}')

    for index, (row, update) in enumerate(planned, start=1):
        client.table('recipe_ingredients').update(update).eq('id', row['id']).execute()
        if index % 25 == 0 or index == len(planned):
            print(f'  updated {index}/{len(planned)}')

    print('\nDone.')


if __name__ == '__main__':
    main()
