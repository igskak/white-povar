#!/usr/bin/env python3
"""
Translate existing recipe narrative (title / description / instructions) to Ukrainian.

Background: the ingestion pipeline used to force every recipe into English before
storing it, so rows already in the database keep English narrative even though the
app default locale is Ukrainian. This one-off maintenance script back-fills those
rows by translating title, description and instructions into Ukrainian via OpenAI.

What it does NOT touch:
- ingredient display names (they are matched against the English `base_ingredients`
  catalogue elsewhere; translating them here would break that linkage),
- `cuisine` / `category` (enum-like labels used for filtering/grouping),
- `tags`.

Safety model:
- Dry-run by default. Nothing is written unless you pass --apply.
- Only rows whose narrative is detected as NOT Ukrainian are translated
  (pass --all to translate every row regardless of detected language).
- In --apply mode a full JSON backup of every original row it is about to change
  is written BEFORE any update, so the change is auditable and reversible.
- Re-running is safe: once a row is Ukrainian it is skipped.

Two ways to translate:

A) AI translation in-place (needs OPENAI_API_KEY):
  # See what would change (no writes):
  python backend/tools/translate_existing_recipes.py
  # Try a single recipe first:
  python backend/tools/translate_existing_recipes.py --id <recipe_uuid>
  # Apply for real (writes to the database, after taking a backup):
  python backend/tools/translate_existing_recipes.py --apply
  # For livelier, less machine-like output, use a stronger model:
  python backend/tools/translate_existing_recipes.py --model gpt-4o --apply

B) Human translation via export/import (no OpenAI needed) — best quality:
  # 1) export English rows to a file (read-only):
  python backend/tools/translate_existing_recipes.py --export recipes_en.json
  # 2) hand-translate title/description/instructions in that file (keep `id`)
  # 3) apply the translated file (takes a backup, then writes):
  python backend/tools/translate_existing_recipes.py --import recipes_en.json --apply

Credentials are read from CLI flags or, if omitted, from the environment /.env:
  SUPABASE_URL, SUPABASE_SERVICE_KEY  (always), OPENAI_API_KEY (AI mode only)
"""
import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:  # python-dotenv is optional; fall back to the real environment.
    def load_dotenv(*_args, **_kwargs):
        return False

from supabase import create_client

# Fields we translate. Ingredient names / cuisine / category / tags are intentionally left alone.
SELECT_COLUMNS = "id,title,description,instructions,instructions_structured"
TARGET_LOCALE = "uk"
PAGE_SIZE = 500


def get_arg_or_env(value, env_name):
    return value or os.getenv(env_name)


def build_steps(row):
    """Return the list of instruction steps for a recipe row.

    Mirrors the API read order (instructions_structured first, then the newline
    joined text column) so we translate exactly what the app renders.
    """
    structured = row.get("instructions_structured")
    if isinstance(structured, list) and structured:
        return [str(s) for s in structured if str(s).strip()]

    text = row.get("instructions")
    if isinstance(text, str) and text.strip():
        return [line.strip() for line in text.split("\n") if line.strip()]

    return []


def detect_language(text):
    """Best-effort language detection. Returns an ISO-639-1 code or None."""
    if not text or len(text.strip()) < 20:
        return None
    try:
        from langdetect import detect

        return detect(text)
    except Exception:
        return None


def needs_translation(row, translate_all):
    """Decide whether a row should be translated, plus the detected language."""
    sample = row.get("description") or row.get("title") or " ".join(build_steps(row))
    detected = detect_language(sample)
    if translate_all:
        return True, detected
    # Unknown / too-short -> skip (don't risk mangling; --all can force it).
    if detected is None:
        return False, detected
    return detected != TARGET_LOCALE, detected


def translate_recipe(client, model, title, description, steps):
    """Translate the narrative fields to Ukrainian. Returns (title, description, steps)."""
    payload = {"title": title or "", "description": description or "", "instructions": steps}

    system_prompt = (
        "You are a native Ukrainian food writer localising recipes for a Ukrainian cooking app. "
        "Rewrite the given fields in warm, natural, appetising Ukrainian — the way a real Ukrainian "
        "cook or food blogger speaks, NOT a literal word-for-word translation. Avoid calques and "
        "stiff machine phrasing; use idiomatic culinary vocabulary and a lively, human tone. "
        "Hard constraints: keep every fact intact — measurements, quantities, temperatures, times and "
        "numbers must stay exactly the same; do not add, remove, merge or reorder instruction steps; "
        "keep proper names and brand names as-is; if a field is already Ukrainian, return it unchanged. "
        "Return ONLY valid JSON with exactly this shape: "
        '{"title": "string", "description": "string", "instructions": ["step 1", "step 2"]}. '
        "The instructions array MUST have the same number of items, in the same order, as the input."
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
        ],
        response_format={"type": "json_object"},
        temperature=0.2,
    )
    data = json.loads(response.choices[0].message.content)

    new_title = (data.get("title") or title or "").strip()
    new_description = (data.get("description") or description or "").strip()
    new_steps = data.get("instructions")
    if not isinstance(new_steps, list) or not new_steps:
        new_steps = steps
    else:
        new_steps = [str(s).strip() for s in new_steps if str(s).strip()]
        if len(new_steps) != len(steps):
            print(
                f"    ! step count changed ({len(steps)} -> {len(new_steps)}); keeping translated version"
            )
    return new_title, new_description, new_steps


def fetch_all_recipes(client, single_id, limit):
    if single_id:
        res = client.table("recipes").select(SELECT_COLUMNS).eq("id", single_id).execute()
        return res.data or []

    rows = []
    offset = 0
    while True:
        res = (
            client.table("recipes")
            .select(SELECT_COLUMNS)
            .range(offset, offset + PAGE_SIZE - 1)
            .execute()
        )
        batch = res.data or []
        rows.extend(batch)
        if len(batch) < PAGE_SIZE:
            break
        offset += PAGE_SIZE
        if limit and len(rows) >= limit:
            break
    return rows[:limit] if limit else rows


def truncate(text, length=70):
    text = (text or "").replace("\n", " ")
    return text if len(text) <= length else text[: length - 1] + "…"


def write_backup(rows, backup_dir):
    """Write a JSON backup of original rows and return its path."""
    backup_dir = Path(backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_path = backup_dir / f"recipe_translation_backup_{stamp}.json"
    backup_data = [
        {
            "id": r.get("id"),
            "title": r.get("title"),
            "description": r.get("description"),
            "instructions": r.get("instructions"),
            "instructions_structured": r.get("instructions_structured"),
        }
        for r in rows
    ]
    backup_path.write_text(json.dumps(backup_data, ensure_ascii=False, indent=2), encoding="utf-8")
    return backup_path


def apply_translation(db, rid, new_title, new_desc, new_steps):
    """Write translated narrative back to a recipe row (both text and structured)."""
    update = {
        "title": new_title,
        "description": new_desc,
        "instructions": "\n".join(new_steps),
        "instructions_structured": new_steps,
    }
    db.table("recipes").update(update).eq("id", rid).execute()


def do_export(recipes, translate_all, out_path):
    """Dump recipes that need translation to a JSON file for manual (human) translation.

    The resulting file is meant to be hand-translated into Ukrainian and fed back
    via --import. Only title/description/instructions should be changed; keep `id`.
    """
    records = []
    skipped = 0
    for row in recipes:
        should, detected = needs_translation(row, translate_all)
        if not should:
            skipped += 1
            continue
        records.append(
            {
                "id": row.get("id"),
                "detected_language": detected,
                "title": row.get("title") or "",
                "description": row.get("description") or "",
                "instructions": build_steps(row),
            }
        )
    Path(out_path).write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Exported {len(records)} recipe(s) needing translation to: {out_path}")
    print(f"Skipped (already uk / undetected): {skipped}")
    print("Translate title/description/instructions in that file, then run --import <file> --apply.")


def do_import(db, in_path, apply_changes, backup_dir):
    """Apply human translations from a JSON file produced by --export."""
    items = json.loads(Path(in_path).read_text(encoding="utf-8"))
    if not isinstance(items, list):
        print("Error: import file must be a JSON array of recipe objects.")
        sys.exit(1)

    # Validate + collect ids.
    valid = []
    for item in items:
        rid = item.get("id")
        if not rid:
            print(f"  ! skipping item without id: {truncate(item.get('title'))}")
            continue
        steps = item.get("instructions") or []
        steps = [str(s).strip() for s in steps if str(s).strip()]
        valid.append((rid, (item.get("title") or "").strip(), (item.get("description") or "").strip(), steps))

    print(f"Import file has {len(valid)} valid recipe(s).")
    for rid, title, desc, steps in valid:
        print(f"  {rid}")
        print(f"    -> title:       {truncate(title)}")
        print(f"    -> description: {truncate(desc)}")

    if not apply_changes:
        print("\nDry-run only. Re-run with --apply to write these changes.")
        return
    if not valid:
        print("Nothing to write.")
        return

    # Backup current DB state for the affected ids before overwriting.
    ids = [rid for rid, *_ in valid]
    current = db.table("recipes").select(SELECT_COLUMNS).in_("id", ids).execute().data or []
    backup_path = write_backup(current, backup_dir)
    print(f"\nBackup of {len(current)} original row(s) written to: {backup_path}\n")

    updated = 0
    for rid, title, desc, steps in valid:
        try:
            apply_translation(db, rid, title, desc, steps)
            updated += 1
            print(f"  updated {rid}")
        except Exception as e:
            print(f"  ! failed to update {rid}: {e}")
    print(f"\nDone. Updated {updated}/{len(valid)} recipe(s).")
    print(f"Backup (for rollback) is at: {backup_path}")


def run_ai_translation(db, ai, args):
    """Translate rows in-place via the AI model (default mode)."""
    mode = "APPLY (writing to database)" if args.apply else "DRY-RUN (no writes)"
    print(f"Mode: {mode}")
    print(f"Model: {args.model}")
    print(f"Target locale: {TARGET_LOCALE}\n")

    recipes = fetch_all_recipes(db, args.id, args.limit)
    print(f"Fetched {len(recipes)} recipe(s).\n")

    # First pass: decide targets (and translate) so we can back everything up before writing.
    planned = []  # list of (row, new_title, new_description, new_steps)
    skipped = 0
    for row in recipes:
        rid = row.get("id")
        should, detected = needs_translation(row, args.all)
        if not should:
            skipped += 1
            continue

        steps = build_steps(row)
        print(f"[{detected or '??'}] {rid}")
        print(f"    title:       {truncate(row.get('title'))}")
        print(f"    description: {truncate(row.get('description'))}")
        try:
            new_title, new_desc, new_steps = translate_recipe(
                ai, args.model, row.get("title"), row.get("description"), steps
            )
        except Exception as e:
            print(f"    ! translation failed, skipping: {e}\n")
            continue

        print(f"    -> title:       {truncate(new_title)}")
        print(f"    -> description: {truncate(new_desc)}\n")
        planned.append((row, new_title, new_desc, new_steps))
        time.sleep(0.2)  # gentle pacing

    print(f"\nPlanned translations: {len(planned)} | skipped (already uk / undetected): {skipped}")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to write these changes.")
        return
    if not planned:
        print("Nothing to write.")
        return

    backup_path = write_backup([row for row, *_ in planned], args.backup_dir)
    print(f"Backup of {len(planned)} original row(s) written to: {backup_path}\n")

    updated = 0
    for row, new_title, new_desc, new_steps in planned:
        rid = row.get("id")
        try:
            apply_translation(db, rid, new_title, new_desc, new_steps)
            updated += 1
            print(f"  updated {rid}")
        except Exception as e:
            print(f"  ! failed to update {rid}: {e}")

    print(f"\nDone. Updated {updated}/{len(planned)} recipe(s).")
    print(f"Backup (for rollback) is at: {backup_path}")


def main():
    load_dotenv()

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--supabase-url", default=None, help="defaults to $SUPABASE_URL")
    parser.add_argument("--service-key", default=None, help="defaults to $SUPABASE_SERVICE_KEY")
    parser.add_argument("--openai-key", default=None, help="defaults to $OPENAI_API_KEY")
    parser.add_argument("--model", default="gpt-4o-mini", help="OpenAI model for AI mode (try gpt-4o for livelier output)")
    parser.add_argument("--apply", action="store_true", help="actually write changes (default: dry-run)")
    parser.add_argument("--all", action="store_true", help="translate every row, ignore language detection")
    parser.add_argument("--id", default=None, help="operate on a single recipe id (good for a first test)")
    parser.add_argument("--limit", type=int, default=None, help="max recipes to process")
    parser.add_argument("--export", default=None, metavar="FILE", help="dump rows needing translation to FILE for hand-translation (read-only)")
    parser.add_argument("--import", dest="import_path", default=None, metavar="FILE", help="apply hand-translated FILE produced by --export")
    parser.add_argument(
        "--backup-dir",
        default=str(Path(__file__).parent / "backups"),
        help="where to write the pre-change backup JSON (apply mode)",
    )
    args = parser.parse_args()

    supabase_url = get_arg_or_env(args.supabase_url, "SUPABASE_URL")
    service_key = get_arg_or_env(args.service_key, "SUPABASE_SERVICE_KEY")

    # OpenAI is only needed for the default (AI translation) mode.
    needs_openai = not args.export and not args.import_path
    required = [("SUPABASE_URL", supabase_url), ("SUPABASE_SERVICE_KEY", service_key)]
    openai_key = None
    if needs_openai:
        openai_key = get_arg_or_env(args.openai_key, "OPENAI_API_KEY")
        required.append(("OPENAI_API_KEY", openai_key))

    missing = [n for n, v in required if not v]
    if missing:
        print(f"Error: missing required credentials: {', '.join(missing)}")
        print("Provide them via CLI flags or environment / .env file.")
        sys.exit(1)

    db = create_client(supabase_url, service_key)

    if args.export:
        recipes = fetch_all_recipes(db, args.id, args.limit)
        print(f"Fetched {len(recipes)} recipe(s).")
        do_export(recipes, args.all, args.export)
        return

    if args.import_path:
        do_import(db, args.import_path, args.apply, args.backup_dir)
        return

    from openai import OpenAI

    ai = OpenAI(api_key=openai_key)
    run_ai_translation(db, ai, args)


if __name__ == "__main__":
    main()
