#!/usr/bin/env python3
"""
Populate `recipes.diet_type` from each recipe's ingredient list.

Run once after `migrations/2026_09_06_recipe_diet_type.sql`. The column starts
NULL and the API resolves NULL rows by classifying their ingredients at read
time, so discovery is already correct before this runs — the backfill is what
turns that per-row work into an indexed predicate.

The classification comes from `app/services/diet.py`, the same module ingestion
uses, so a recipe backfilled today and a recipe ingested tomorrow are judged by
one lexicon.

Safety model, matching the other tools in this directory:
- Dry-run by default. Nothing is written unless you pass --apply.
- Idempotent: a row whose stored value already equals the computed one is
  skipped, so re-running after adding lexicon terms only writes what changed.
- --recheck also revisits rows that already have a value (use it after editing
  the lexicon); by default only NULL rows are considered.
- In --apply mode a JSON backup of every row about to change is written BEFORE
  any update.

Usage:
  # See what would be written (no writes):
  python backend/tools/backfill_diet_type.py
  # Apply for real:
  python backend/tools/backfill_diet_type.py --apply
  # Re-classify everything after changing the lexicon:
  python backend/tools/backfill_diet_type.py --recheck --apply

Credentials come from CLI flags or, if omitted, the environment / .env:
  SUPABASE_URL, SUPABASE_SERVICE_KEY
"""
import argparse
import json
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

try:
    from dotenv import load_dotenv
except ImportError:  # python-dotenv is optional.
    def load_dotenv(*_args, **_kwargs):
        return False

from supabase import create_client

from app.services.diet import classify_diet, ingredient_names_from_row

PAGE_SIZE = 500


def _fetch_all(client, chef_id=None):
    """Page through recipes with their ingredients embedded."""
    rows = []
    offset = 0
    while True:
        request = (
            client.table('recipes')
            .select('id,chef_id,title,tags,diet_type,recipe_ingredients(display_name)')
            .order('id')
            .range(offset, offset + PAGE_SIZE - 1)
        )
        if chef_id:
            request = request.eq('chef_id', chef_id)
        page = request.execute().data or []
        rows.extend(page)
        if len(page) < PAGE_SIZE:
            return rows
        offset += PAGE_SIZE


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--apply', action='store_true',
                        help='write the changes (default: dry run)')
    parser.add_argument('--recheck', action='store_true',
                        help='also re-classify rows that already have a value')
    parser.add_argument('--chef-id', help='limit to one tenant')
    parser.add_argument('--supabase-url', default=None)
    parser.add_argument('--service-key', default=None)
    parser.add_argument('--backup-dir', default='backend/tools/backups')
    args = parser.parse_args()

    load_dotenv()
    url = args.supabase_url or os.getenv('SUPABASE_URL')
    key = args.service_key or os.getenv('SUPABASE_SERVICE_KEY')
    if not url or not key:
        print('SUPABASE_URL and SUPABASE_SERVICE_KEY must be set '
              '(or passed as --supabase-url / --service-key)', file=sys.stderr)
        return 1

    client = create_client(url, key)
    rows = _fetch_all(client, args.chef_id)

    planned = []
    unknown = []
    counts = Counter()
    for row in rows:
        if row.get('diet_type') and not args.recheck:
            counts['already set'] += 1
            continue
        computed = classify_diet(row.get('tags') or [],
                                 ingredient_names_from_row(row))
        if computed is None:
            unknown.append(row)
            counts['unclassifiable'] += 1
            continue
        if computed == row.get('diet_type'):
            counts['unchanged'] += 1
            continue
        counts[computed] += 1
        planned.append((row, computed))

    print(f'recipes scanned: {len(rows)}')
    for label, count in sorted(counts.items()):
        print(f'  {label}: {count}')
    print(f'rows to write:   {len(planned)}')
    for row, computed in planned:
        print(f'  {computed:<11} {row.get("title", row["id"])}')

    if unknown:
        print(f'\nno ingredients to judge ({len(unknown)}) — left NULL, resolved '
              f'at read time:')
        for row in unknown:
            print(f'  {row.get("title", row["id"])}')

    if not args.apply:
        print('\nDry run. Re-run with --apply to write these changes.')
        return 0

    if not planned:
        print('\nNothing to write.')
        return 0

    backup_dir = Path(args.backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = backup_dir / f'recipes_diet_type_{stamp}.json'
    backup.write_text(
        json.dumps([{'id': row['id'], 'title': row.get('title'),
                     'diet_type': row.get('diet_type')} for row, _ in planned],
                   ensure_ascii=False, indent=2),
        encoding='utf-8')
    print(f'\nbackup written: {backup}')

    for index, (row, computed) in enumerate(planned, start=1):
        client.table('recipes').update({'diet_type': computed}).eq('id', row['id']).execute()
        if index % 25 == 0 or index == len(planned):
            print(f'  updated {index}/{len(planned)}')

    print('\nDone.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
